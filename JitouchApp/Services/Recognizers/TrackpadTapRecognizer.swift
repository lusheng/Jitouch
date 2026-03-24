import Foundation

@MainActor
final class TrackpadTapRecognizer: GestureRecognizer {
    var isEnabled = true

    private let context: TrackpadGestureContext
    private var clickSpeed = 0.25
    private let maxMovementSquared = 0.0015

    private var activeGesture: GestureSession?

    init(context: TrackpadGestureContext) {
        self.context = context
    }

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        let touches = frame.activeTouches
        let fingerCount = touches.count

        switch fingerCount {
        case 3, 4:
            if activeGesture?.fingerCount != fingerCount {
                activeGesture = GestureSession(fingerCount: fingerCount, startTimestamp: frame.timestamp, origins: originMap(for: touches))
            } else if let session = activeGesture, movedTooFar(session: session, touches: touches) {
                activeGesture?.isCancelled = true
            }
        case 0, 1:
            if let session = activeGesture {
                defer { activeGesture = nil }

                let duration = frame.timestamp - session.startTimestamp
                guard !session.isCancelled, duration <= clickSpeed else { return [] }

                if session.fingerCount == 3 {
                    return [.threeFingerTap]
                }
                if context.consumeFourFingerTapSuppression() {
                    return []
                }
                return [.fourFingerTap]
            }
        default:
            activeGesture?.isCancelled = true
        }

        return []
    }

    func reset() {
        activeGesture = nil
    }

    func updateSettings(_ settings: JitouchSettings) {
        clickSpeed = settings.clickSpeed
    }

    private func originMap(for touches: [TouchPoint]) -> [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
    }

    private func movedTooFar(session: GestureSession, touches: [TouchPoint]) -> Bool {
        for touch in touches {
            guard let origin = session.origins[touch.id] else {
                return true
            }

            let dx = touch.position.x - origin.x
            let dy = touch.position.y - origin.y
            if (dx * dx) + (dy * dy) > maxMovementSquared {
                return true
            }
        }
        return false
    }
}

private struct GestureSession {
    let fingerCount: Int
    let startTimestamp: Double
    let origins: [Int: CGPoint]
    var isCancelled = false
}
