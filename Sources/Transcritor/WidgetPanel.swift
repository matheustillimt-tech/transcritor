import AppKit
import SwiftUI

final class WidgetModel: ObservableObject {
    enum Phase: Equatable {
        case loading       // modelo carregando (já dá pra gravar)
        case idle
        case recording
        case transcribing
        case error
    }

    @Published var phase: Phase = .loading
    @Published var level: CGFloat = 0
    @Published var hovering = false
    @Published var hoveringClose = false
}

struct WidgetView: View {
    @ObservedObject var model: WidgetModel

    var body: some View {
        ZStack {
            if model.phase == .recording {
                Circle()
                    .fill(Color.red.opacity(0.28))
                    .frame(width: 52, height: 52)
                    .scaleEffect(1 + model.level * 0.42)
                    .animation(.easeOut(duration: 0.08), value: model.level)
            }
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: 52, height: 52)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
            icon
            closeButton
                .offset(x: WidgetPanel.closeOffset, y: -WidgetPanel.closeOffset)
                .opacity(model.hovering ? 1 : 0)
                .scaleEffect(model.hovering ? 1 : 0.6)
                .animation(.easeOut(duration: 0.15), value: model.hovering)
        }
        .frame(width: WidgetPanel.size, height: WidgetPanel.size)
    }

    private var closeButton: some View {
        ZStack {
            Circle()
                .fill(model.hoveringClose ? Color(red: 0.9, green: 0.2, blue: 0.2) : Color(white: 0.2))
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white)
        }
        .frame(width: WidgetPanel.closeDiameter, height: WidgetPanel.closeDiameter)
    }

    private var fill: LinearGradient {
        let colors: [Color]
        switch model.phase {
        case .recording: colors = [Color(red: 1, green: 0.33, blue: 0.3), Color(red: 0.8, green: 0.1, blue: 0.12)]
        case .transcribing: colors = [Color(red: 0.35, green: 0.45, blue: 1), Color(red: 0.2, green: 0.25, blue: 0.8)]
        case .error: colors = [Color(red: 1, green: 0.65, blue: 0.2), Color(red: 0.85, green: 0.45, blue: 0.05)]
        case .loading, .idle: colors = [Color(white: 0.26), Color(white: 0.12)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder private var icon: some View {
        switch model.phase {
        case .transcribing:
            ProgressView().controlSize(.small).tint(.white)
        case .recording:
            Image(systemName: "stop.fill").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 19)).foregroundColor(.white)
        case .loading:
            Image(systemName: "mic.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.45))
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 20)).foregroundColor(.white)
        }
    }
}

/// Janela flutuante que nunca ganha foco: clicar nela não tira o cursor do app onde você está digitando.
final class WidgetPanel: NSPanel {
    static let size: CGFloat = 76
    static let closeDiameter: CGFloat = 18
    /// Deslocamento do centro do "x" em relação ao centro do botão (borda superior direita do círculo).
    static let closeOffset: CGFloat = 19

    init(model: WidgetModel, onClick: @escaping () -> Void, onClose: @escaping () -> Void,
         menu: @escaping () -> NSMenu) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let container = DragClickView(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))
        container.model = model
        container.onClick = onClick
        container.onClose = onClose
        container.menuProvider = menu
        container.onDragEnd = { [weak self] in self?.saveOrigin() }
        let host = NSHostingView(rootView: WidgetView(model: model))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        contentView = container

        setFrameOrigin(restoredOrigin())
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func saveOrigin() {
        UserDefaults.standard.set(NSStringFromPoint(frame.origin), forKey: "widgetOrigin")
    }

    private func restoredOrigin() -> NSPoint {
        if let s = UserDefaults.standard.string(forKey: "widgetOrigin") {
            let p = NSPointFromString(s)
            let rect = NSRect(origin: p, size: frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) { return p }
        }
        let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSPoint(x: vf.maxX - Self.size - 24, y: vf.minY + 120)
    }
}

/// Distingue clique (grava/para) de arrasto (move o widget entre telas),
/// e mostra o "x" de fechar quando o mouse passa por cima.
final class DragClickView: NSView {
    weak var model: WidgetModel?
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    private var mouseDownScreen: NSPoint = .zero
    private var windowOriginAtDown: NSPoint = .zero
    private var dragging = false
    private var pressedClose = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // .activeAlways: o app nunca fica ativo, então o hover precisa funcionar mesmo assim.
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    private func isOnClose(_ event: NSEvent) -> Bool {
        let p = convert(event.locationInWindow, from: nil)
        let c = NSPoint(x: bounds.midX + WidgetPanel.closeOffset, y: bounds.midY + WidgetPanel.closeOffset)
        return hypot(p.x - c.x, p.y - c.y) <= WidgetPanel.closeDiameter / 2 + 2
    }

    override func mouseEntered(with event: NSEvent) {
        model?.hovering = true
        model?.hoveringClose = isOnClose(event)
    }

    override func mouseMoved(with event: NSEvent) {
        model?.hovering = true
        model?.hoveringClose = isOnClose(event)
    }

    override func mouseExited(with event: NSEvent) {
        guard !dragging else { return }
        model?.hovering = false
        model?.hoveringClose = false
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownScreen = NSEvent.mouseLocation
        windowOriginAtDown = window?.frame.origin ?? .zero
        dragging = false
        pressedClose = model?.hovering == true && isOnClose(event)
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseDownScreen.x
        let dy = now.y - mouseDownScreen.y
        if !dragging && hypot(dx, dy) < 4 { return }
        dragging = true
        window?.setFrameOrigin(NSPoint(x: windowOriginAtDown.x + dx, y: windowOriginAtDown.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if dragging {
            onDragEnd?()
        } else if pressedClose && isOnClose(event) {
            onClose?()
        } else if !pressedClose {
            onClick?()
        }
        dragging = false
        pressedClose = false
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
