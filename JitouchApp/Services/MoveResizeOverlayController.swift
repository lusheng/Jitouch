import AppKit

@MainActor
final class MoveResizeOverlayController {
    private let panel: NSPanel
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 124, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let effectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .white
        iconView.symbolConfiguration = .init(pointSize: 18, weight: .semibold)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white

        effectView.addSubview(iconView)
        effectView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
        ])

        panel.contentView = effectView
    }

    func show(mode: MoveResizeMode, at point: CGPoint) {
        apply(mode: mode)
        position(near: point)
        panel.orderFrontRegardless()
    }

    func update(mode: MoveResizeMode, at point: CGPoint) {
        apply(mode: mode)
        position(near: point)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func apply(mode: MoveResizeMode) {
        switch mode {
        case .move:
            iconView.image = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: "Move")
            label.stringValue = "Move Window"
        case .resize:
            iconView.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Resize")
            label.stringValue = "Resize Window"
        }
    }

    private func position(near point: CGPoint) {
        panel.setFrameOrigin(NSPoint(x: point.x + 20, y: point.y + 20))
    }
}
