import AppKit
import ApplicationServices

/// Insere texto onde estiver o cursor do teclado, em qualquer app,
/// colando (Cmd+V) e depois restaurando a área de transferência original.
enum TextInserter {
    /// Precisa da permissão de Acessibilidade para simular o Cmd+V.
    static func hasAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Retorna `false` se não pôde colar (o texto fica copiado na área de transferência).
    @discardableResult
    static func insert(_ text: String) -> Bool {
        let pb = NSPasteboard.general
        let saved = snapshot(pb)

        pb.clearContents()
        pb.setString(text, forType: .string)

        guard hasAccessibility(prompt: false) else { return false }

        // Marca como transitório para gerenciadores de clipboard ignorarem.
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let changeCount = pb.changeCount

        // Pequena pausa para a tecla de atalho já estar solta e o app de destino pronto.
        usleep(60_000)
        pressCmdV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Só restaura se ninguém mais mexeu no clipboard nesse meio tempo.
            guard pb.changeCount == changeCount else { return }
            restore(saved, to: pb)
        }
        return true
    }

    /// Simula ⌘V com a tecla Command apertada e solta de verdade
    /// (alguns apps, como Chrome e Electron, ignoram só a flag).
    private static func pressCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdKey: CGKeyCode = 55 // kVK_Command
        let vKey: CGKeyCode = 9    // kVK_ANSI_V
        let events: [(CGKeyCode, Bool)] = [(cmdKey, true), (vKey, true), (vKey, false), (cmdKey, false)]
        for (key, down) in events {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            e.flags = (key == vKey || down) ? .maskCommand : []
            e.post(tap: .cghidEventTap)
            usleep(8_000)
        }
    }

    private static func snapshot(_ pb: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }

    private static func restore(_ saved: [[(NSPasteboard.PasteboardType, Data)]], to pb: NSPasteboard) {
        pb.clearContents()
        let items = saved.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }
}
