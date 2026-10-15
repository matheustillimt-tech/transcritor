import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = AppController()
    app.delegate = controller
    app.setActivationPolicy(.accessory) // sem ícone no Dock, não rouba o foco
    withExtendedLifetime(controller) {
        app.run()
    }
}
