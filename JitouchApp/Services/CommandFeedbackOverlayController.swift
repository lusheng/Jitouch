import AppKit

@MainActor
final class CommandFeedbackOverlayController {
    private let panel: NSPanel
    private let cardContainer = NSView()
    private let effectView = NSVisualEffectView()
    private let badgeView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private var hideTask: DispatchWorkItem?
    private var anchoredOrigin: CGPoint = .zero

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 332, height: 90),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow

        let rootView = NSView(frame: panel.contentView?.bounds ?? .zero)
        rootView.autoresizingMask = [.width, .height]

        cardContainer.frame = rootView.bounds.insetBy(dx: 10, dy: 10)
        cardContainer.autoresizingMask = [.width, .height]
        cardContainer.wantsLayer = true
        cardContainer.layer?.cornerRadius = 20
        cardContainer.layer?.shadowColor = NSColor.black.withAlphaComponent(0.16).cgColor
        cardContainer.layer?.shadowOpacity = 1
        cardContainer.layer?.shadowRadius = 18
        cardContainer.layer?.shadowOffset = CGSize(width: 0, height: -4)

        effectView.frame = cardContainer.bounds
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 20
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.black.withAlphaComponent(0.05).cgColor
        effectView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.84).cgColor

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 15
        badgeView.layer?.masksToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = .init(pointSize: 16, weight: .semibold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.maximumNumberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 13, weight: .medium)
        detailLabel.textColor = NSColor.secondaryLabelColor.withAlphaComponent(0.92)
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail

        effectView.addSubview(badgeView)
        badgeView.addSubview(iconView)
        effectView.addSubview(titleLabel)
        effectView.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            badgeView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 14),
            badgeView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            badgeView.widthAnchor.constraint(equalToConstant: 30),
            badgeView.heightAnchor.constraint(equalToConstant: 30),

            iconView.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 14),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
        ])

        cardContainer.addSubview(effectView)
        rootView.addSubview(cardContainer)
        panel.contentView = rootView
        panel.alphaValue = 0
    }

    func showSuccess(title: String) {
        show(
            title: title,
            detail: "Completed",
            symbolName: "checkmark",
            tintColor: NSColor.systemGreen
        )
    }

    func showFailure(title: String, detail: String) {
        show(
            title: title,
            detail: detail,
            symbolName: "exclamationmark",
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
        panel.animations = [:]

        iconView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: title
        )
        iconView.contentTintColor = tintColor
        badgeView.layer?.backgroundColor = tintColor.withAlphaComponent(0.14).cgColor
        titleLabel.stringValue = title
        detailLabel.stringValue = detail

        let targetOrigin = panelOrigin()
        let startOrigin = CGPoint(x: targetOrigin.x, y: targetOrigin.y - 10)
        anchoredOrigin = targetOrigin

        panel.setFrameOrigin(startOrigin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(targetOrigin)
            panel.animator().alphaValue = 1
        }

        let hideTask = DispatchWorkItem { [weak self] in
            self?.hideAnimated()
        }
        self.hideTask = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: hideTask)
    }

    private func hideAnimated() {
        let finalOrigin = CGPoint(x: anchoredOrigin.x, y: anchoredOrigin.y - 8)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(finalOrigin)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.panel.orderOut(nil)
            }
        }
    }

    private func panelOrigin() -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(currentMouseLocation()) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        return CGPoint(
            x: visibleFrame.midX - (panel.frame.width / 2),
            y: visibleFrame.minY + 64
        )
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}
