import AVFoundation

/// Grava o microfone direto em WAV 16 kHz mono (formato nativo do Whisper).
final class AudioRecorder {
    struct Recording {
        let url: URL
        let duration: TimeInterval
        let peakDb: Float
    }

    private var recorder: AVAudioRecorder?
    private var peakDb: Float = -160

    var isRecording: Bool { recorder?.isRecording ?? false }

    static func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transcritor-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        guard r.record() else {
            throw NSError(domain: "Transcritor", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Não consegui acessar o microfone."])
        }
        peakDb = -160
        recorder = r
    }

    /// Nível atual de 0 a 1, para a animação. Também registra o pico para detectar silêncio.
    func level() -> Float {
        guard let r = recorder, r.isRecording else { return 0 }
        r.updateMeters()
        peakDb = max(peakDb, r.peakPower(forChannel: 0))
        let minDb: Float = -50
        return max(0, min(1, (r.averagePower(forChannel: 0) - minDb) / -minDb))
    }

    func stop() -> Recording? {
        guard let r = recorder else { return nil }
        let duration = r.currentTime
        r.stop()
        recorder = nil
        return Recording(url: r.url, duration: duration, peakDb: peakDb)
    }

    func cancel() {
        if let rec = stop() {
            try? FileManager.default.removeItem(at: rec.url)
        }
    }
}
