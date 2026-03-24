import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class TrackpadCharacterRecognizer: GestureRecognizer {
    var isEnabled = false

    private var minimumPointTravelSquared: CGFloat = 0.0002
    private var startingFingerDistance: CGFloat = 0.33
    private let maximumFingerDistance: CGFloat = 0.65
    private let maximumVerticalOffset: CGFloat = 0.6
    private let minimumTouchHeight: CGFloat = 0.14
    private let minimumFingerTravelSquared: CGFloat = 0.003
    private let distanceStabilityThreshold: CGFloat = 0.13
    private let minimumValidatedSegments = 5

    private var session: TrackpadCharacterSession?

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        if !isEnabled {
            session = nil
            return []
        }

        let touches = frame.activeTouches
        if var currentSession = session {
            let events = update(session: &currentSession, with: touches)
            session = currentSession.isActive ? currentSession : nil
            return events
        }

        guard shouldStartRecognition(with: touches) else {
            return []
        }

        session = TrackpadCharacterSession(touches: touches)
        return []
    }

    func reset() {
        session = nil
    }

    func updateSettings(_ settings: JitouchSettings) {
        isEnabled = settings.trackpadEnabled && settings.trackpadCharacterRecognitionEnabled && settings.twoFingerDrawingEnabled
        startingFingerDistance = CGFloat(settings.characterRecognitionIndexRingDistance)

        let scale = max(0.7, min(1.3, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        minimumPointTravelSquared = 0.0002 * scale
    }

    private func shouldStartRecognition(with touches: [TouchPoint]) -> Bool {
        guard touches.count == 2 else { return false }
        guard !CGEventSource.buttonState(.hidSystemState, button: .left) else { return false }

        let sorted = touches.sorted { $0.position.x < $1.position.x }
        let horizontalDistance = sorted[1].position.x - sorted[0].position.x
        let verticalDistance = abs(sorted[1].position.y - sorted[0].position.y)

        guard
            horizontalDistance > startingFingerDistance,
            horizontalDistance < maximumFingerDistance,
            verticalDistance < maximumVerticalOffset,
            sorted.allSatisfy({ $0.position.y > minimumTouchHeight }),
            !looksLikePalmPose(sorted)
        else {
            return false
        }

        return true
    }

    private func update(session: inout TrackpadCharacterSession, with touches: [TouchPoint]) -> [GestureEvent] {
        guard touches.count == 2 else {
            return finish(session: &session, cancelled: touches.count == 3)
        }

        let ids = Set(touches.map(\.id))
        guard ids == session.touchIDs else {
            session.isActive = false
            return []
        }

        let midpoint = center(of: touches)
        guard squaredDistance(session.lastPoint, midpoint) > minimumPointTravelSquared else {
            if session.engine.isCancelled {
                session.isActive = false
            }
            return []
        }

        let angle = atan2(midpoint.y - session.lastPoint.y, midpoint.x - session.lastPoint.x)
        session.engine.advance(angle: angle)
        session.lastPoint = midpoint
        session.expandBounds(with: midpoint)
        session.segmentCount += 1

        if !session.isValidated, session.segmentCount >= minimumValidatedSegments {
            let sortedInitialTouches = session.initialTouchMap.values.sorted { $0.x < $1.x }
            let startDistanceSquared = squaredDistance(sortedInitialTouches[0], sortedInitialTouches[1])
            let currentDistanceSquared = squaredDistance(touches[0].position, touches[1].position)
            let finger0Travel = squaredDistance(session.initialTouchMap[touches[0].id] ?? touches[0].position, touches[0].position)
            let finger1Travel = squaredDistance(session.initialTouchMap[touches[1].id] ?? touches[1].position, touches[1].position)

            if
                finger0Travel > minimumFingerTravelSquared,
                finger1Travel > minimumFingerTravelSquared,
                abs(startDistanceSquared - currentDistanceSquared) < distanceStabilityThreshold
            {
                session.isValidated = true
            } else {
                session.isActive = false
                return []
            }
        }

        if session.engine.isCancelled {
            session.isActive = false
        }

        return []
    }

    private func finish(session: inout TrackpadCharacterSession, cancelled: Bool) -> [GestureEvent] {
        defer { session.isActive = false }

        guard !cancelled, session.isValidated else {
            return []
        }

        let geometry = CharacterStrokeGeometry(
            start: session.firstPoint,
            end: session.lastPoint,
            top: session.top,
            bottom: session.bottom,
            left: session.left,
            right: session.right
        )

        guard let character = session.engine.bestMatch(for: geometry) else {
            return []
        }

        return [.characterRecognized(character)]
    }

    private func looksLikePalmPose(_ touches: [TouchPoint]) -> Bool {
        guard touches.count == 2 else { return false }
        let left = touches[0]
        let right = touches[1]

        return
            left.majorAxis >= 11 &&
            right.majorAxis >= 11 &&
            right.angle > Float.pi / 2 &&
            left.angle < Float.pi / 2 &&
            (right.angle - left.angle) > 0.5
    }

    private func center(of touches: [TouchPoint]) -> CGPoint {
        let sum = touches.reduce(CGPoint.zero) { partial, touch in
            CGPoint(x: partial.x + touch.position.x, y: partial.y + touch.position.y)
        }
        return CGPoint(x: sum.x / CGFloat(touches.count), y: sum.y / CGFloat(touches.count))
    }

    private func squaredDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }
}

private struct TrackpadCharacterSession {
    let touchIDs: Set<Int>
    let initialTouchMap: [Int: CGPoint]
    let firstPoint: CGPoint
    var lastPoint: CGPoint
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
    var segmentCount = 0
    var isValidated = false
    var isActive = true
    var engine = CharacterRecognitionEngine()

    init(touches: [TouchPoint]) {
        let firstPoint = CGPoint(
            x: (touches[0].position.x + touches[1].position.x) / 2,
            y: (touches[0].position.y + touches[1].position.y) / 2
        )

        self.touchIDs = Set(touches.map(\.id))
        self.initialTouchMap = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
        self.firstPoint = firstPoint
        self.lastPoint = firstPoint
        self.top = firstPoint.y
        self.bottom = firstPoint.y
        self.left = firstPoint.x
        self.right = firstPoint.x
    }

    mutating func expandBounds(with point: CGPoint) {
        top = max(top, point.y)
        bottom = min(bottom, point.y)
        left = min(left, point.x)
        right = max(right, point.x)
    }
}
