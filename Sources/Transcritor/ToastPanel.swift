import AppKit
import SwiftUI

/// Balãozinho de aviso que aparece perto do widget e some sozinho.
final class ToastPanel: NSPanel {
    private let host = NSHostingView(rootView: ToastView(text: ""))
    private var hideWork: DispatchWorkItem?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = host
    }

    override var canBecomeKey: Bool { false }

    func show(_ text: String, near anchor: NSRect, duration: TimeInterval = 3) {
        host.rootView = ToastView(text: text)
        let size = host.fittingSize
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main!
        let vf = screen.visibleFrame

        var x = anchor.midX - size.width / 2
        x = min(max(x, vf.minX + 8), vf.maxX - size.width - 8)
        var y = anchor.maxY + 4
        if y + size.height > vf.maxY { y = anchor.minY - size.height - 4 }

        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        alphaValue = 1
        orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 280)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.82)))
            .padding(4)
    }
}
