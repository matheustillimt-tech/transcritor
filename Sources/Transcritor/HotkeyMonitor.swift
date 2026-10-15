import AppKit

/// Atalho de teclado global, no estilo "segure para falar":
/// - Segurar a tecla: grava enquanto estiver pressionada; soltar transcreve e cola.
/// - Dois toques rápidos: modo mãos livres (grava até tocar na tecla de novo).
/// - Esc: cancela a gravação.
@MainActor
final class HotkeyMonitor {
    enum Key: String, CaseIterable {
        case fn
        case rightOption
        case rightCommand

        var title: String {
            switch self {
            case .fn: return "fn (🌐)"
            case .rightOption: return "Option direita (⌥)"
            case .rightCommand: return "Command direita (⌘)"
            }
        }

        var keyCode: UInt16 {
            switch self {
            case .fn: return 63
            case .rightOption: return 61
            case .rightCommand: return 54
            }
        }

        var flag: NSEvent.ModifierFlags {
            switch self {
            case .fn: return .function
            case .rightOption: return .option
            case .rightCommand: return .command
            }
        }
    }

    /// Começar a gravar (a tecla foi pressionada).
    var onStart: (() -> Void)?
    /// Terminar e transcrever.
    var onStop: (() -> Void)?
    /// Cancelar sem transcrever.
    var onCancel: (() -> Void)?
    /// Entrou no modo mãos livres.
    var onHandsFree: (() -> Void)?

    var key: Key = .fn

    /// Toque mais curto que isso não conta como "segurar".
    private let tapThreshold: TimeInterval = 0.3
    /// Janela para o segundo toque do duplo toque.
    private let doubleTapWindow: TimeInterval = 0.45

    private var monitors: [Any] = []
    private var isDown = false
    private var downAt = Date.distantPast
    private var lastTapAt = Date.distantPast
    /// Uma outra tecla foi usada junto (ex.: fn+seta), então não é ditado.
    private var usedAsModifier = false
    private(set) var handsFree = false
    private var active = false

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { self.handle(event) }
        }) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { self.handle(event) }
            return event
        }) { monitors.append(l) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// Avisa que a gravação terminou por outro caminho (clique no widget, erro…).
    func reset() {
        active = false
        handsFree = false
    }

    /// Gravação iniciada pelo clique no widget: um toque na tecla termina, Esc cancela.
    func beginHandsFree() {
        active = true
        handsFree = true
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            if event.keyCode == 53, active { // Esc
                reset()
                onCancel?()
            } else if isDown, !handsFree {
                // Ex.: fn+seta ou ⌥+letra: é um atalho normal, não ditado.
                usedAsModifier = true
                if active {
                    reset()
                    onCancel?()
                }
            }
            return
        }

        guard event.keyCode == key.keyCode else { return }
        let pressed = event.modifierFlags.contains(key.flag)
        if pressed == isDown { return }
        isDown = pressed

        if pressed {
            downAt = Date()
            usedAsModifier = false
            if handsFree {
                // Toque que encerra o modo mãos livres.
                reset()
                onStop?()
                usedAsModifier = true // ignora o "soltar" desse toque
                return
            }
            if !active {
                active = true
                onStart?()
            }
        } else {
            guard active, !usedAsModifier else { return }
            let held = Date().timeIntervalSince(downAt)
            if held >= tapThreshold {
                reset()
                onStop?()
            } else if downAt.timeIntervalSince(lastTapAt) < doubleTapWindow {
                // Segundo toque rápido: continua gravando sem precisar segurar.
                handsFree = true
                lastTapAt = .distantPast
                onHandsFree?()
            } else {
                // Toque único e curto: descarta e espera um possível segundo toque.
                lastTapAt = Date()
                reset()
                onCancel?()
            }
        }
    }
}
