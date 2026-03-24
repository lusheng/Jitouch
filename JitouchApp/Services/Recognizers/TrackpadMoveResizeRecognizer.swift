import CoreGraphics
import Foundation

@MainActor
final class TrackpadMoveResizeRecognizer: GestureRecognizer {
    var isEnabled = true

    private let maximumFingerDistanceSquared: CGFloat = 0.2
    private let fixedFingerMovementSquared: CGFloat = 0.0001
    private let activationMovementSquared: CGFloat = 0.012
    private let toggleMovementSquared: CGFloat = 0.001
    private let stationaryExitMovementSquared: CGFloat = 0.001

    private var clickSpeed = 0.25

    private var detectionState: DetectionState = .idle
    private var activeSession: ActiveSession?

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        let touches = frame.activeTouches
        if activeSession != nil {
            return processActiveSession(touches: touches, timestamp: frame.timestamp)
        }
        return processDetection(touches: touches, timestamp: frame.timestamp)
    }

    func reset() {
        detectionState = .idle
        activeSession = nil
    }

    func updateSettings(_ settings: JitouchSettings) {
        clickSpeed = settings.clickSpeed
    }

    private func processDetection(touches: [TouchPoint], timestamp: Double) -> [GestureEvent] {
        switch detectionState {
        case .idle:
            if touches.count == 1 {
                detectionState = .singleFinger
            }
            return []

        case .singleFinger:
            guard touches.count == 2 else {
                detectionState = touches.count == 1 ? .singleFinger : .idle
                return []
            }

            guard distanceSquared(touches[0].position, touches[1].position) <= maximumFingerDistanceSquared else {
                detectionState = .idle
                return []
            }

            let sorted = touches.sorted { diagonalCoordinate(for: $0.position) < diagonalCoordinate(for: $1.position) }
            detectionState = .twoFingerCandidate(
                TwoFingerCandidate(
                    fixedFingerID: sorted[0].id,
                    fixedOrigin: sorted[0].position,
                    movingFingerID: sorted[1].id,
                    movingOrigin: sorted[1].position,
                    startedAt: timestamp
                )
            )
            return []

        case let .twoFingerCandidate(candidate):
            guard touches.count == 2 else {
                detectionState = .idle
                return []
            }

            guard timestamp - candidate.startedAt <= clickSpeed * 2 else {
                detectionState = .idle
                return []
            }

            guard
                let fixedTouch = touches.first(where: { $0.id == candidate.fixedFingerID }),
                let movingTouch = touches.first(where: { $0.id == candidate.movingFingerID })
            else {
                detectionState = .idle
                return []
            }

            guard distanceSquared(candidate.fixedOrigin, fixedTouch.position) <= fixedFingerMovementSquared else {
                detectionState = .idle
                return []
            }

            let movement = CGPoint(
                x: movingTouch.position.x - candidate.movingOrigin.x,
                y: movingTouch.position.y - candidate.movingOrigin.y
            )
            guard lengthSquared(movement) >= activationMovementSquared else { return [] }

            let referenceVector = CGPoint(
                x: movingTouch.position.x - candidate.fixedOrigin.x,
                y: movingTouch.position.y - candidate.fixedOrigin.y
            )
            guard abs(cosineBetween(movement, referenceVector)) <= 0.8 else {
                detectionState = .idle
                return []
            }

            let mode: MoveResizeMode = movingTouch.position.y < candidate.movingOrigin.y ? .move : .resize
            activeSession = ActiveSession(mode: mode)
            detectionState = .idle
            return [.moveResize(.began(mode))]
        }
    }

    private func processActiveSession(touches: [TouchPoint], timestamp: Double) -> [GestureEvent] {
        guard var activeSession else { return [] }

        switch touches.count {
        case 0:
            let shouldExit: Bool
            if let stationarySince = activeSession.stationarySince, stationarySince > 0 {
                shouldExit = timestamp - stationarySince <= clickSpeed
            } else {
                shouldExit = false
            }

            activeSession.stationaryFingerID = nil
            activeSession.stationaryOrigin = nil
            activeSession.stationarySince = nil
            activeSession.toggleCandidate = nil

            if shouldExit {
                self.activeSession = nil
                return [.moveResize(.ended)]
            }

            self.activeSession = activeSession
            return []

        case 1:
            if let toggleCandidate = activeSession.toggleCandidate {
                if timestamp - toggleCandidate.startedAt <= clickSpeed {
                    let toggledMode: MoveResizeMode = activeSession.mode == .move ? .resize : .move
                    activeSession.mode = toggledMode
                    activeSession.toggleCandidate = nil
                    activeSession.stationaryFingerID = touches[0].id
                    activeSession.stationaryOrigin = touches[0].position
                    activeSession.stationarySince = timestamp
                    self.activeSession = activeSession
                    return [.moveResize(.began(toggledMode))]
                }

                activeSession.toggleCandidate = nil
            }

            let touch = touches[0]
            if activeSession.stationaryFingerID != touch.id {
                activeSession.stationaryFingerID = touch.id
                activeSession.stationaryOrigin = touch.position
                activeSession.stationarySince = timestamp
            } else if
                let stationaryOrigin = activeSession.stationaryOrigin,
                distanceSquared(stationaryOrigin, touch.position) >= stationaryExitMovementSquared
            {
                activeSession.stationarySince = 0
            }

            self.activeSession = activeSession
            return [.moveResize(.changed(mode: activeSession.mode, dx: touch.position.x, dy: touch.position.y))]

        case 2:
            let touchOrigins = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
            if let toggleCandidate = activeSession.toggleCandidate {
                let movedTooFar = touches.contains { touch in
                    guard let origin = toggleCandidate.touchOrigins[touch.id] else { return true }
                    return distanceSquared(origin, touch.position) >= toggleMovementSquared
                }
                if movedTooFar || timestamp - toggleCandidate.startedAt > clickSpeed {
                    activeSession.toggleCandidate = nil
                }
            } else if touches.allSatisfy({ $0.size >= 0.1 }) {
                activeSession.toggleCandidate = ToggleCandidate(
                    startedAt: timestamp,
                    touchOrigins: touchOrigins
                )
            }

            activeSession.stationaryFingerID = nil
            activeSession.stationaryOrigin = nil
            activeSession.stationarySince = nil
            self.activeSession = activeSession
            return []

        default:
            activeSession.toggleCandidate = nil
            activeSession.stationaryFingerID = nil
            activeSession.stationaryOrigin = nil
            activeSession.stationarySince = nil
            self.activeSession = activeSession
            return []
        }
    }

    private func diagonalCoordinate(for point: CGPoint) -> CGFloat {
        point.x + point.y
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

private enum DetectionState {
    case idle
    case singleFinger
    case twoFingerCandidate(TwoFingerCandidate)
}

private struct TwoFingerCandidate {
    let fixedFingerID: Int
    let fixedOrigin: CGPoint
    let movingFingerID: Int
    let movingOrigin: CGPoint
    let startedAt: Double
}

private struct ActiveSession {
    var mode: MoveResizeMode
    var stationaryFingerID: Int?
    var stationaryOrigin: CGPoint?
    var stationarySince: Double?
    var toggleCandidate: ToggleCandidate?
}

private struct ToggleCandidate {
    let startedAt: Double
    let touchOrigins: [Int: CGPoint]
}
