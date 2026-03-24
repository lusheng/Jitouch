import Foundation

@MainActor
final class TrackpadSwipeRecognizer: GestureRecognizer {
    var isEnabled = true

    private let verticalConsistencyThreshold: CGFloat = 0.08
    private let horizontalConsistencyThreshold: CGFloat = 0.06

    private var verticalTrigger: CGFloat = 0.12
    private var horizontalTrigger: CGFloat = 0.10

    private var threeFingerSession: SwipeSession?
    private var fourFingerSession: SwipeSession?

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        switch frame.fingerCount {
        case 3:
            fourFingerSession = nil
            return process(frame, session: &threeFingerSession)
        case 4:
            threeFingerSession = nil
            return process(frame, session: &fourFingerSession)
        default:
            threeFingerSession = nil
            fourFingerSession = nil
            return []
        }
    }

    func reset() {
        threeFingerSession = nil
        fourFingerSession = nil
    }

    func updateSettings(_ settings: JitouchSettings) {
        let scale = max(0.65, min(1.35, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        verticalTrigger = 0.12 * scale
        horizontalTrigger = 0.10 * scale
    }

    private func process(_ frame: TouchFrame, session: inout SwipeSession?) -> [GestureEvent] {
        let touches = frame.activeTouches
        guard !touches.isEmpty else {
            session = nil
            return []
        }

        if session == nil || session?.fingerCount != touches.count {
            session = SwipeSession(fingerCount: touches.count, origins: originMap(for: touches))
            return []
        }

        guard var currentSession = session else { return [] }

        let deltas = touches.compactMap { touch -> CGPoint? in
            guard let origin = currentSession.origins[touch.id] else { return nil }
            return CGPoint(x: touch.position.x - origin.x, y: touch.position.y - origin.y)
        }

        guard deltas.count == touches.count else {
            session = SwipeSession(fingerCount: touches.count, origins: originMap(for: touches))
            return []
        }

        let averageX = deltas.map(\.x).reduce(0, +) / CGFloat(deltas.count)
        let averageY = deltas.map(\.y).reduce(0, +) / CGFloat(deltas.count)

        let direction = dominantDirection(
            deltas: deltas,
            averageX: averageX,
            averageY: averageY
        )

        guard let direction else {
            session = currentSession
            return []
        }

        if currentSession.lastDirection == direction {
            return []
        }

        currentSession.lastDirection = direction
        currentSession.origins = originMap(for: touches)
        session = currentSession

        if currentSession.fingerCount == 3 {
            return [.threeFingerSwipe(direction)]
        }
        return [.fourFingerSwipe(direction)]
    }

    private func dominantDirection(
        deltas: [CGPoint],
        averageX: CGFloat,
        averageY: CGFloat
    ) -> Direction? {
        let movingUp = deltas.filter { $0.y > verticalConsistencyThreshold }.count == deltas.count
        let movingDown = deltas.filter { $0.y < -verticalConsistencyThreshold }.count == deltas.count
        let movingLeft = deltas.filter { $0.x < -horizontalConsistencyThreshold }.count == deltas.count
        let movingRight = deltas.filter { $0.x > horizontalConsistencyThreshold }.count == deltas.count

        if movingUp, averageY > verticalTrigger {
            return .up
        }
        if movingDown, averageY < -verticalTrigger {
            return .down
        }
        if movingLeft, averageX < -horizontalTrigger {
            return .left
        }
        if movingRight, averageX > horizontalTrigger {
            return .right
        }
        return nil
    }

    private func originMap(for touches: [TouchPoint]) -> [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
    }
}

private struct SwipeSession {
    let fingerCount: Int
    var origins: [Int: CGPoint]
    var lastDirection: Direction?
}
