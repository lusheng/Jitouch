import AppKit

@MainActor
final class CommandFeedbackOverlayController {
    private let panel: NSPanel
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private var hideTask: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
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
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = .init(pointSize: 20, weight: .semibold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 12, weight: .medium)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byTruncatingTail

        effectView.addSubview(iconView)
        effectView.addSubview(titleLabel)
        effectView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 16),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
        ])

        panel.contentView = effectView
    }

    func showSuccess(title: String) {
        show(
            title: title,
            detail: "Command executed",
            symbolName: "checkmark.circle.fill",
            tintColor: NSColor.systemGreen
        )
    }

    func showFailure(title: String, detail: String) {
        show(
            title: title,
            detail: detail,
            symbolName: "xmark.octagon.fill",
            tintColor: NSColor.systemOrange
        )
    }

    private func show(
        title: String,
        detail: String,
        symbolName: String,
        tintColor: NSColor
    ) {
        hideTask?.cancel()

        iconView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: title
        )
        iconView.contentTintColor = tintColor
        titleLabel.stringValue = title
        detailLabel.stringValue = detail
        positionPanel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let hideTask = DispatchWorkItem { [weak self] in
            self?.panel.animator().alphaValue = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.panel.orderOut(nil)
            }
        }
        self.hideTask = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35, execute: hideTask)
    }

    private func positionPanel() {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(currentMouseLocation()) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let origin = CGPoint(
            x: visibleFrame.midX - (panel.frame.width / 2),
            y: visibleFrame.maxY - panel.frame.height - 36
        )
        panel.setFrameOrigin(origin)
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}
