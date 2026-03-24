import Foundation

@MainActor
final class TrackpadPinchRecognizer: GestureRecognizer {
    var isEnabled = true

    private var pinchOutRatio: CGFloat = 1.22
    private var pinchInRatio: CGFloat = 0.82
    private var minimumOuterTravelSquared: CGFloat = 0.003
    private var centroidDriftLimitSquared: CGFloat = 0.0025

    private var session: PinchSession?

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }
        let touches = frame.activeTouches

        guard touches.count == 3 else {
            session = nil
            return []
        }

        guard var currentSession = session else {
            session = PinchSession(touches: touches)
            return []
        }

        if currentSession.touchIDs != Set(touches.map(\.id)) {
            session = PinchSession(touches: touches)
            return []
        }

        guard
            let leftOrigin = currentSession.origins[currentSession.outerTouchIDs.left],
            let rightOrigin = currentSession.origins[currentSession.outerTouchIDs.right],
            let leftTouch = touches.first(where: { $0.id == currentSession.outerTouchIDs.left }),
            let rightTouch = touches.first(where: { $0.id == currentSession.outerTouchIDs.right })
        else {
            session = PinchSession(touches: touches)
            return []
        }

        let leftDelta = CGPoint(
            x: leftTouch.position.x - leftOrigin.x,
            y: leftTouch.position.y - leftOrigin.y
        )
        let rightDelta = CGPoint(
            x: rightTouch.position.x - rightOrigin.x,
            y: rightTouch.position.y - rightOrigin.y
        )

        guard
            lengthSquared(leftDelta) >= minimumOuterTravelSquared,
            lengthSquared(rightDelta) >= minimumOuterTravelSquared,
            cosineBetween(leftDelta, rightDelta) <= 0.2
        else {
            session = currentSession
            return []
        }

        let startCentroid = centroid(for: Array(currentSession.origins.values))
        let currentCentroid = centroid(for: touches.map(\.position))
        guard distanceSquared(startCentroid, currentCentroid) <= centroidDriftLimitSquared else {
            session = currentSession
            return []
        }

        let startDistance = distance(leftOrigin, rightOrigin)
        let currentDistance = distance(leftTouch.position, rightTouch.position)
        guard startDistance > 0.001 else {
            session = PinchSession(touches: touches)
            return []
        }

        let ratio = currentDistance / startDistance
        let direction: PinchDirection?
        if ratio >= pinchOutRatio, currentSession.lastDirection != .outward {
            direction = .outward
        } else if ratio <= pinchInRatio, currentSession.lastDirection != .inward {
            direction = .inward
        } else {
            direction = nil
        }

        guard let direction else {
            session = currentSession
            return []
        }

        currentSession = PinchSession(touches: touches, lastDirection: direction)
        session = currentSession
        return [.threeFingerPinch(direction)]
    }

    func reset() {
        session = nil
    }

    func updateSettings(_ settings: JitouchSettings) {
        let scale = max(0.65, min(1.35, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        pinchOutRatio = 1 + (0.22 * scale)
        pinchInRatio = max(0.55, 1 - (0.18 * scale))
        minimumOuterTravelSquared = 0.003 * scale
        centroidDriftLimitSquared = pow(0.05 * scale, 2)
    }

    private func centroid(for points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        sqrt(distanceSquared(lhs, rhs))
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }

    private func lengthSquared(_ point: CGPoint) -> CGFloat {
        (point.x * point.x) + (point.y * point.y)
    }

    private func cosineBetween(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let denominator = sqrt(lengthSquared(lhs) * lengthSquared(rhs))
        guard denominator > 0.0001 else { return 1 }
        return ((lhs.x * rhs.x) + (lhs.y * rhs.y)) / denominator
    }
}

private struct PinchSession {
    let origins: [Int: CGPoint]
    let outerTouchIDs: (left: Int, right: Int)
    let touchIDs: Set<Int>
    let lastDirection: PinchDirection?

    init(touches: [TouchPoint], lastDirection: PinchDirection? = nil) {
        let sorted = touches.sorted { ($0.position.x + $0.position.y) < ($1.position.x + $1.position.y) }
        self.origins = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
        self.outerTouchIDs = (left: sorted[0].id, right: sorted[2].id)
        self.touchIDs = Set(touches.map(\.id))
        self.lastDirection = lastDirection
    }
}
