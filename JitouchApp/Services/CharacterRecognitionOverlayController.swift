import AppKit

@MainActor
final class CharacterRecognitionOverlayController {
    private let panel: NSPanel
    private let overlayView = CharacterRecognitionOverlayView()

    private let trackpadPanelSize = CGSize(width: 550, height: 400)
    private let magicMousePanelSize = CGSize(width: 800, height: 800)

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: trackpadPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = overlayView
    }

    func prepareTrackpadPath(at normalizedPoint: CGPoint) {
        configurePanel(size: trackpadPanelSize)
        overlayView.reset()
        overlayView.addTrackpadPoint(normalizedPoint)
        positionTrackpadPanelOnActiveScreen()
    }

    func beginTrackpadPath(at normalizedPoint: CGPoint) {
        prepareTrackpadPath(at: normalizedPoint)
        reveal()
    }

    func updateTrackpadPath(_ normalizedPoint: CGPoint, hint: String?) {
        overlayView.addTrackpadPoint(normalizedPoint)
        overlayView.hintText = hint ?? ""
    }

    func beginMagicMousePath(at screenPoint: CGPoint) {
        configurePanel(size: magicMousePanelSize)
        overlayView.reset()
        overlayView.addRelativePoint(.zero)
        positionMagicMousePanel(around: screenPoint)
    }

    func updateMagicMousePath(relativePoint: CGPoint, screenPoint: CGPoint, hint: String?, activated: Bool) {
        overlayView.addRelativePoint(relativePoint)
        overlayView.hintText = hint ?? ""
        positionMagicMousePanel(around: screenPoint)
        if activated, !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        overlayView.reset()
        panel.orderOut(nil)
    }

    func reveal() {
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func configurePanel(size: CGSize) {
        panel.setContentSize(size)
        overlayView.frame = NSRect(origin: .zero, size: size)
        overlayView.needsDisplay = true
    }

    private func positionTrackpadPanelOnActiveScreen() {
        let location = currentMouseLocation()
        let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
        let frame = screen?.frame ?? NSRect(origin: .zero, size: trackpadPanelSize)
        let origin = CGPoint(
            x: frame.midX - (trackpadPanelSize.width / 2),
            y: frame.midY - (trackpadPanelSize.height / 2)
        )
        panel.setFrameOrigin(origin)
    }

    private func positionMagicMousePanel(around screenPoint: CGPoint) {
        let origin = CGPoint(
            x: screenPoint.x - (magicMousePanelSize.width / 2),
            y: screenPoint.y - (magicMousePanelSize.height / 2)
        )
        panel.setFrameOrigin(origin)
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}

private final class CharacterRecognitionOverlayView: NSView {
    private var points: [CGPoint] = []
    var hintText = "" {
        didSet {
            if hintText != oldValue {
                needsDisplay = true
            }
        }
    }

    override var isFlipped: Bool {
        false
    }

    func reset() {
        points.removeAll()
        hintText = ""
        needsDisplay = true
    }

    func addTrackpadPoint(_ normalizedPoint: CGPoint) {
        let width = bounds.width - 180
        let height = bounds.height - 130
        let point = CGPoint(
            x: (normalizedPoint.x * width) + 15,
            y: (normalizedPoint.y * height) + 115
        )
        points.append(point)
        needsDisplay = true
    }

    func addRelativePoint(_ relativePoint: CGPoint) {
        let point = CGPoint(
            x: bounds.midX + relativePoint.x,
            y: bounds.midY + relativePoint.y
        )
        points.append(point)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard let firstPoint = points.first else {
            return
        }

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: firstPoint)

        var minimumX = firstPoint.x
        var minimumY = firstPoint.y
        for point in points.dropFirst() {
            path.line(to: point)
            minimumX = min(minimumX, point.x)
            minimumY = min(minimumY, point.y)
        }

        let startMarkerRect = CGRect(x: firstPoint.x - 15, y: firstPoint.y - 15, width: 30, height: 30)
        NSColor(calibratedRed: 0.7, green: 0.0, blue: 0.0, alpha: 0.6).setStroke()
        let startMarker = NSBezierPath(ovalIn: startMarkerRect)
        startMarker.lineWidth = 3
        startMarker.stroke()

        NSGraphicsContext.saveGraphicsState()
        path.lineWidth = 12
        NSColor(calibratedWhite: 1.0, alpha: 0.3).setStroke()
        path.stroke()

        path.lineWidth = 10
        NSColor(calibratedWhite: 0.0, alpha: 0.6).setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()

        guard !hintText.isEmpty else {
            return
        }

        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 40, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.7, green: 0.0, blue: 0.0, alpha: 0.55),
        ]
        let hintOrigin = CGPoint(x: minimumX, y: minimumY - 70)
        hintText.draw(at: hintOrigin, withAttributes: hintAttributes)
    }
}
