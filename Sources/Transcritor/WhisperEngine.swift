import Foundation

/// Mantém um `whisper-server` local rodando com o modelo já carregado na memória,
/// para que cada transcrição comece na hora.
@MainActor
final class WhisperEngine {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    static let port = 8178
    static let defaultModelPath = NSString(
        string: "~/.cache/whisper-models/ggml-large-v3-turbo.bin").expandingTildeInPath

    private(set) var state: State = .loading {
        didSet { if state != oldValue { onStateChange?(state) } }
    }
    var onStateChange: ((State) -> Void)?

    private var process: Process?
    private var baseURL: URL { URL(string: "http://127.0.0.1:\(Self.port)")! }

    var modelPath: String {
        UserDefaults.standard.string(forKey: "modelPath") ?? Self.defaultModelPath
    }

    private static func findServerBinary() -> String? {
        ["/opt/homebrew/bin/whisper-server", "/usr/local/bin/whisper-server"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func start() {
        state = .loading
        guard let binary = Self.findServerBinary() else {
            state = .failed("whisper-server não encontrado. Rode: brew install whisper-cpp")
            return
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            state = .failed("Modelo não encontrado em \(modelPath)")
            return
        }

        // Encerra algum servidor antigo que tenha ficado órfão nesta porta.
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-f", "whisper-server.*--port \(Self.port)"]
        try? pkill.run()
        pkill.waitUntilExit()

        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = [
            "-m", modelPath,
            "--host", "127.0.0.1",
            "--port", String(Self.port),
            "-l", "pt",
            "-t", "4",
            "-bs", "5",   // beam search: mais preciso com fala rápida
            "-bo", "5",
            "-sns",       // suprime tokens de não-fala ([música], etc.)
        ]
        p.standardOutput = Self.logHandle()
        p.standardError = p.standardOutput
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self, self.process === proc else { return }
                self.process = nil
                self.state = .failed("O motor de transcrição parou (código \(proc.terminationStatus)).")
            }
        }
        do {
            try p.run()
            process = p
        } catch {
            state = .failed("Falha ao iniciar whisper-server: \(error.localizedDescription)")
            return
        }

        Task { await waitUntilReady() }
    }

    func stop() {
        let p = process
        process = nil
        p?.terminate()
    }

    private static func logHandle() -> FileHandle {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Transcritor")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("whisper-server.log")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        return (try? FileHandle(forWritingTo: file)) ?? .nullDevice
    }

    private func waitUntilReady() async {
        for _ in 0..<240 { // até ~2 minutos
            guard process != nil else { return }
            if await isHealthy() {
                state = .ready
                return
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        state = .failed("O modelo demorou demais para carregar.")
    }

    private func isHealthy() async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("health"))
        req.timeoutInterval = 1
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    func transcribe(fileURL: URL, prompt: String) async throws -> String {
        // Se o usuário gravou enquanto o modelo ainda carregava, espera ficar pronto.
        while state == .loading {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if case .failed(let message) = state {
            throw NSError(domain: "Transcritor", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("language", "pt")
        field("temperature", "0.0")
        field("response_format", "json")
        field("prompt", prompt)
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: baseURL.appendingPathComponent("inference"))
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String
        else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "Transcritor", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Erro na transcrição. \(detail.prefix(120))"])
        }
        return Self.clean(text)
    }

    /// Remove marcações e "alucinações" típicas do Whisper em trechos de silêncio.
    static func clean(_ raw: String) -> String {
        // O servidor separa segmentos com "\n", às vezes no meio de uma palavra ("Pre\nciso");
        // cada segmento já traz o próprio espaço inicial, então basta juntar.
        var t = raw.replacingOccurrences(of: "\n", with: "")
        t = t.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let hallucinations = [
            "legendas pela comunidade amara.org",
            "legenda adriana zanotto",
            "obrigado por assistir",
            "inscreva-se no canal",
        ]
        for h in hallucinations {
            t = t.replacingOccurrences(of: h, with: "", options: [.caseInsensitive, .diacriticInsensitive])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–")))
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(string.data(using: .utf8)!)
    }
}
