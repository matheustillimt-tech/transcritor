import AppKit
import AVFoundation
import ServiceManagement

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let model = WidgetModel()
    private let recorder = AudioRecorder()
    private let engine = WhisperEngine()
    private let toast = ToastPanel()
    private let hotkey = HotkeyMonitor()
    private var panel: WidgetPanel!
    private var meterTimer: Timer?
    private var lastTranscription: String?

    private let defaults = UserDefaults.standard
    private var vocabulary: String {
        get { defaults.string(forKey: "vocabulary") ?? "" }
        set { defaults.set(newValue, forKey: "vocabulary") }
    }
    private var hotkeyKey: HotkeyMonitor.Key {
        get { HotkeyMonitor.Key(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .fn }
        set { defaults.set(newValue.rawValue, forKey: "hotkey"); hotkey.key = newValue }
    }
    private var addTrailingSpace: Bool {
        get { defaults.object(forKey: "addTrailingSpace") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "addTrailingSpace") }
    }

    /// Contexto inicial para o Whisper: puxa para português do Brasil com pontuação,
    /// e ensina nomes/termos que você cadastrar.
    private var prompt: String {
        var p = "Olá! Esta é uma transcrição em português do Brasil, com pontuação e acentuação corretas."
        let vocab = vocabulary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vocab.isEmpty { p += " Termos usados: \(vocab)." }
        return p
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = WidgetPanel(model: model,
                            onClick: { [weak self] in self?.handleClick() },
                            onClose: { NSApp.terminate(nil) },
                            menu: { [weak self] in self?.makeMenu() ?? NSMenu() })
        panel.orderFrontRegardless()

        engine.onStateChange = { [weak self] state in self?.engineChanged(state) }
        engine.start()

        hotkey.key = hotkeyKey
        hotkey.onStart = { [weak self] in self?.startRecording() }
        hotkey.onStop = { [weak self] in self?.stopAndTranscribe() }
        hotkey.onCancel = { [weak self] in self?.cancelRecording() }
        hotkey.onHandsFree = { [weak self] in
            guard let self else { return }
            self.say("Mãos livres 🎙️ toque \(self.hotkeyKey.title) para terminar · Esc cancela", 3)
        }
        hotkey.start()

        if !UserDefaults.standard.bool(forKey: "loginItemAsked") {
            UserDefaults.standard.set(true, forKey: "loginItemAsked")
            try? SMAppService.mainApp.register()
        }

        if !TextInserter.hasAccessibility(prompt: true) {
            say("Ative o Transcritor em Ajustes > Privacidade > Acessibilidade. É o que permite usar a tecla de atalho e colar o texto.", 8)
        } else if hotkeyKey == .fn && Self.fnKeyDoesSomething {
            say("Dica: em Ajustes > Teclado, deixe “Pressionar a tecla 🌐” como “Não fazer nada”, para o fn servir só pro ditado.", 8)
        } else {
            say("Segure \(hotkeyKey.title) e fale. Solte para colar o texto.", 4)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.stop()
        recorder.cancel()
        engine.stop()
    }

    // MARK: - Fluxo principal

    private func handleClick() {
        switch model.phase {
        case .recording:
            hotkey.reset()
            stopAndTranscribe()
        case .transcribing: say("Transcrevendo…", 1.5)
        case .idle, .loading, .error:
            startRecording()
            if model.phase == .recording { hotkey.beginHandsFree() }
        }
    }

    private func startRecording() {
        guard model.phase != .recording, model.phase != .transcribing else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            hotkey.reset()
            Task {
                if await AudioRecorder.requestPermission() {
                    say("Microfone liberado! Agora é só gravar.", 2.5)
                } else {
                    showError("Sem acesso ao microfone. Libere em Ajustes > Privacidade > Microfone.")
                }
            }
            return
        default:
            hotkey.reset()
            showError("Sem acesso ao microfone. Libere em Ajustes > Privacidade > Microfone.")
            return
        }
        do {
            try recorder.start()
        } catch {
            hotkey.reset()
            showError(error.localizedDescription)
            return
        }
        model.phase = .recording
        if engine.state == .loading { say("Gravando… (o modelo ainda está carregando)", 2) }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.level = CGFloat(self.recorder.level())
            }
        }
    }

    private func stopAndTranscribe() {
        guard model.phase == .recording else { return }
        meterTimer?.invalidate()
        meterTimer = nil
        model.level = 0
        guard let rec = recorder.stop() else { model.phase = restingPhase; return }

        if rec.duration < 0.4 || rec.peakDb < -45 {
            try? FileManager.default.removeItem(at: rec.url)
            model.phase = restingPhase
            say("Não ouvi nada 🤫", 1.8)
            return
        }

        model.phase = .transcribing
        Task {
            defer { try? FileManager.default.removeItem(at: rec.url) }
            do {
                let text = try await engine.transcribe(fileURL: rec.url, prompt: prompt)
                model.phase = restingPhase
                guard !text.isEmpty else {
                    say("Não entendi, tenta de novo 🙂", 2)
                    return
                }
                lastTranscription = text
                let output = addTrailingSpace ? text + " " : text
                if !TextInserter.insert(output) {
                    say("Texto copiado! Ative Acessibilidade para colar automaticamente (ou cole com ⌘V).", 5)
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private var restingPhase: WidgetModel.Phase {
        switch engine.state {
        case .ready: return .idle
        case .loading: return .loading
        case .failed: return .error
        }
    }

    private func engineChanged(_ state: WhisperEngine.State) {
        if model.phase == .recording || model.phase == .transcribing { return }
        model.phase = restingPhase
        if case .failed(let message) = state { say(message, 6) }
    }

    private func showError(_ message: String) {
        model.phase = .error
        say(message, 4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.model.phase == .error else { return }
            self.model.phase = self.restingPhase
        }
    }

    private func say(_ text: String, _ duration: TimeInterval) {
        toast.show(text, near: panel.frame, duration: duration)
    }

    // MARK: - Menu (botão direito)

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let status: String
        switch engine.state {
        case .loading: status = "⏳ Carregando modelo…"
        case .ready: status = "🟢 Pronto (Whisper large-v3-turbo, local)"
        case .failed(let m): status = "🔴 \(m)"
        }
        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        if model.phase == .recording {
            menu.addItem(item("Cancelar gravação", #selector(cancelRecording)))
        }
        let copy = item("Copiar última transcrição", #selector(copyLast))
        copy.isEnabled = lastTranscription != nil
        menu.addItem(copy)
        menu.addItem(item("Vocabulário e nomes próprios…", #selector(editVocabulary)))
        let keyMenu = NSMenu()
        for key in HotkeyMonitor.Key.allCases {
            let k = item(key.title, #selector(chooseHotkey(_:)))
            k.representedObject = key.rawValue
            k.state = key == hotkeyKey ? .on : .off
            keyMenu.addItem(k)
        }
        let keyItem = NSMenuItem(title: "Tecla de atalho: \(hotkeyKey.title)", action: nil, keyEquivalent: "")
        keyItem.submenu = keyMenu
        menu.addItem(keyItem)
        if hotkeyKey == .fn {
            menu.addItem(item("Ajustar tecla 🌐 no Teclado…", #selector(openKeyboardSettings)))
        }
        let login = item("Abrir ao iniciar o Mac", #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let space = item("Adicionar espaço após o texto", #selector(toggleSpace))
        space.state = addTrailingSpace ? .on : .off
        menu.addItem(space)
        if !TextInserter.hasAccessibility(prompt: false) {
            menu.addItem(item("Abrir ajustes de Acessibilidade…", #selector(openAccessibility)))
        }
        menu.addItem(item("Reiniciar motor de transcrição", #selector(restartEngine)))
        menu.addItem(.separator())
        menu.addItem(item("Sair do Transcritor", #selector(quit)))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func chooseHotkey(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let key = HotkeyMonitor.Key(rawValue: raw) else { return }
        hotkeyKey = key
        say("Agora é só segurar \(key.title) e falar.", 3)
    }

    @objc private func openKeyboardSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
        say("Em “Pressionar a tecla 🌐”, escolha “Não fazer nada”.", 6)
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            say("Não consegui mudar: \(error.localizedDescription)", 4)
        }
    }

    /// `true` se a tecla 🌐 ainda abre emojis/troca idioma (o que atrapalharia o ditado).
    private static var fnKeyDoesSomething: Bool {
        let value = CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString)
        return (value as? Int) != 0
    }

    @objc private func cancelRecording() {
        hotkey.reset()
        guard model.phase == .recording else { return }
        meterTimer?.invalidate()
        meterTimer = nil
        model.level = 0
        recorder.cancel()
        model.phase = restingPhase
    }

    @objc private func copyLast() {
        guard let text = lastTranscription else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        say("Copiado!", 1.5)
    }

    @objc private func toggleSpace() {
        addTrailingSpace.toggle()
    }

    @objc private func editVocabulary() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Vocabulário e nomes próprios"
        alert.informativeText = "Liste nomes, marcas, termos técnicos e gírias que você fala com frequência, separados por vírgula. Isso ajuda o Whisper a escrever essas palavras certinho."
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 380, height: 110)
        scroll.borderType = .bezelBorder
        let textView = scroll.documentView as! NSTextView
        textView.font = .systemFont(ofSize: 13)
        textView.string = vocabulary
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Salvar")
        alert.addButton(withTitle: "Cancelar")
        alert.window.initialFirstResponder = textView
        if alert.runModal() == .alertFirstButtonReturn {
            vocabulary = textView.string
        }
    }

    @objc private func openAccessibility() {
        _ = TextInserter.hasAccessibility(prompt: true)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func restartEngine() {
        engine.stop()
        engine.start()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
