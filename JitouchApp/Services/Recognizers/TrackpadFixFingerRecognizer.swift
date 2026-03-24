import ApplicationServices
import Foundation

@MainActor
final class TrackpadFixFingerRecognizer: GestureRecognizer {
    var isEnabled = true

    private let minimumRestDuration = 0.06
    private let maximumTapPairDistanceSquared: CGFloat = 0.15
    private let maximumTapMovementSquared: CGFloat = 0.0015
    private let maximumFixedFingerDriftSquared: CGFloat = 0.0015

    private var clickSpeed = 0.25
    private var handedness: Handedness = .right
    private var slideTriggerDistance: CGFloat = 0.12
    private var slideMinimumFingerTravel: CGFloat = 0.08
    private var slideMaximumHorizontalDrift: CGFloat = 0.06

    private var restingFinger: RestingFinger?
    private var tapSession: OneFixTapSession?
    private var slideSession: OneFixSlideSession?
    private var slideLocked = false
    private var doubleTapPhase: TwoFixDoubleTapPhase = .idle

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        let touches = frame.activeTouches
        var events: [GestureEvent] = []
        events.append(contentsOf: processOneFixTap(touches: touches, timestamp: frame.timestamp))
        events.append(contentsOf: processOneFixTwoSlide(touches: touches))
        events.append(contentsOf: processTwoFixDoubleTap(touches: touches, timestamp: frame.timestamp))
        return events
    }

    func reset() {
        restingFinger = nil
        tapSession = nil
        slideSession = nil
        slideLocked = false
        doubleTapPhase = .idle
    }

    func updateSettings(_ settings: JitouchSettings) {
        clickSpeed = settings.clickSpeed
        handedness = settings.trackpadHandedness

        let scale = max(0.65, min(1.35, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        slideTriggerDistance = 0.12 * scale
        slideMinimumFingerTravel = 0.08 * scale
        slideMaximumHorizontalDrift = 0.06 * scale
    }

    private func processOneFixTap(touches: [TouchPoint], timestamp: Double) -> [GestureEvent] {
        switch touches.count {
        case 0:
            restingFinger = nil
            tapSession = nil
            return []
        case 1:
            let touch = touches[0]
            guard let session = tapSession else {
                if restingFinger?.id != touch.id {
                    restingFinger = RestingFinger(id: touch.id, startedAt: timestamp)
                }
                return []
            }
            tapSession = nil

            guard
                timestamp - session.startedAt <= clickSpeed,
                touch.id == session.fixedFingerID
            else {
                restingFinger = RestingFinger(id: touch.id, startedAt: timestamp)
                return []
            }

            restingFinger = RestingFinger(id: touch.id, startedAt: timestamp)
            let side: Side = session.transformedTapOrigin.x < session.transformedFixedOrigin.x ? .left : .right
            return [.oneFixOneTap(side)]
        case 2:
            guard let restingFinger else {
                tapSession = nil
                return []
            }

            guard
                touches.contains(where: { $0.id == restingFinger.id }),
                timestamp - restingFinger.startedAt >= minimumRestDuration
            else {
                tapSession = nil
                return []
            }

            let transformedTouches = transformedTouches(from: touches)
            guard
                let fixedTouch = transformedTouches.first(where: { $0.touch.id == restingFinger.id }),
                let tappedTouch = transformedTouches.first(where: { $0.touch.id != restingFinger.id }),
                distanceSquared(fixedTouch.position, tappedTouch.position) <= maximumTapPairDistanceSquared
            else {
                tapSession = nil
                return []
            }

            if tapSession == nil {
                tapSession = OneFixTapSession(
                    fixedFingerID: fixedTouch.touch.id,
                    startedAt: timestamp,
                    initialPositions: [
                        fixedTouch.touch.id: fixedTouch.position,
                        tappedTouch.touch.id: tappedTouch.position,
                    ],
                    transformedFixedOrigin: fixedTouch.position,
                    transformedTapOrigin: tappedTouch.position
                )
                return []
            }

            guard var session = tapSession else { return [] }
            if timestamp - session.startedAt > clickSpeed {
                tapSession = nil
                return []
            }

            for touch in transformedTouches {
                guard let origin = session.initialPositions[touch.touch.id] else {
                    tapSession = nil
                    return []
                }

                if distanceSquared(origin, touch.position) > maximumTapMovementSquared {
                    tapSession = nil
                    return []
                }
            }

            session.initialPositions[fixedTouch.touch.id] = session.initialPositions[fixedTouch.touch.id] ?? fixedTouch.position
            session.initialPositions[tappedTouch.touch.id] = session.initialPositions[tappedTouch.touch.id] ?? tappedTouch.position
            tapSession = session
            return []
        default:
            tapSession = nil
            return []
        }
    }

    private func processOneFixTwoSlide(touches: [TouchPoint]) -> [GestureEvent] {
        if touches.count < 2 {
            slideLocked = false
        }

        guard !slideLocked else { return [] }
        guard touches.count == 3 else {
            slideSession = nil
            return []
        }

        let transformedTouches = transformedTouches(from: touches)
        guard
            let fixedTouch = transformedTouches.min(by: { diagonalCoordinate(for: $0.position) < diagonalCoordinate(for: $1.position) })
        else {
            slideSession = nil
            return []
        }

        let sliderTouches = transformedTouches.filter { $0.touch.id != fixedTouch.touch.id }
        guard sliderTouches.count == 2 else {
            slideSession = nil
            return []
        }

        guard let session = slideSession else {
            slideSession = OneFixSlideSession(
                fixedFingerID: fixedTouch.touch.id,
                fixedOrigin: fixedTouch.position,
                sliderOrigins: Dictionary(uniqueKeysWithValues: sliderTouches.map { ($0.touch.id, $0.position) })
            )
            return []
        }

        guard session.fixedFingerID == fixedTouch.touch.id else {
            slideSession = OneFixSlideSession(
                fixedFingerID: fixedTouch.touch.id,
                fixedOrigin: fixedTouch.position,
                sliderOrigins: Dictionary(uniqueKeysWithValues: sliderTouches.map { ($0.touch.id, $0.position) })
            )
            return []
        }

        guard distanceSquared(session.fixedOrigin, fixedTouch.position) <= maximumFixedFingerDriftSquared else {
            slideSession = nil
            return []
        }

        let deltas = sliderTouches.compactMap { touch -> CGPoint? in
            guard let origin = session.sliderOrigins[touch.touch.id] else { return nil }
            return CGPoint(x: touch.position.x - origin.x, y: touch.position.y - origin.y)
        }

        guard deltas.count == sliderTouches.count else {
            slideSession = OneFixSlideSession(
                fixedFingerID: fixedTouch.touch.id,
                fixedOrigin: fixedTouch.position,
                sliderOrigins: Dictionary(uniqueKeysWithValues: sliderTouches.map { ($0.touch.id, $0.position) })
            )
            return []
        }

        let averageY = deltas.map(\.y).reduce(0, +) / CGFloat(deltas.count)
        let averageX = deltas.map(\.x).reduce(0, +) / CGFloat(deltas.count)

        let verticalConsistent = deltas.allSatisfy {
            abs($0.y) >= slideMinimumFingerTravel &&
            abs($0.x) <= max(abs($0.y) * 0.9, slideMaximumHorizontalDrift)
        }
        let sameDirection = deltas.reduce(0) { $0 + ($1.y >= 0 ? 1 : -1) }

        guard
            verticalConsistent,
            abs(averageY) >= slideTriggerDistance,
            abs(averageX) <= slideMaximumHorizontalDrift,
            abs(sameDirection) == deltas.count
        else {
            slideSession = session
            return []
        }

        slideLocked = true
        slideSession = nil

        let direction: Direction = averageY >= 0 ? .up : .down
        if CGEventSource.buttonState(.hidSystemState, button: .left) {
            return [.oneFixPressTwoSlide(direction)]
        }
        return [.oneFixTwoSlide(direction)]
    }

    private func processTwoFixDoubleTap(touches: [TouchPoint], timestamp: Double) -> [GestureEvent] {
        switch doubleTapPhase {
        case .idle:
            if touches.count == 2 {
                doubleTapPhase = .anchored(anchorSet(from: touches))
            }
            return []

        case let .anchored(anchorIDs):
            switch touches.count {
            case 2:
                doubleTapPhase = .anchored(anchorSet(from: touches))
                return []
            case 3:
                guard
                    anchorIDs.isSubset(of: anchorSet(from: touches)),
                    let role = tapRole(for: touches, anchorIDs: anchorIDs)
                else {
                    doubleTapPhase = .idle
                    return []
                }
                doubleTapPhase = .firstTapDown(
                    TwoFixDoubleTapCandidate(anchorIDs: anchorIDs, role: role, lastTransitionAt: timestamp)
                )
                return []
            default:
                doubleTapPhase = .idle
                return []
            }

        case var .firstTapDown(candidate):
            if timestamp - candidate.lastTransitionAt > clickSpeed {
                doubleTapPhase = touches.count == 2 ? .anchored(anchorSet(from: touches)) : .idle
                return []
            }

            if touches.count == 2, anchorSet(from: touches) == candidate.anchorIDs {
                candidate.lastTransitionAt = timestamp
                doubleTapPhase = .betweenTaps(candidate)
            } else if touches.count != 3 {
                doubleTapPhase = touches.count == 2 ? .anchored(anchorSet(from: touches)) : .idle
            }
            return []

        case var .betweenTaps(candidate):
            if timestamp - candidate.lastTransitionAt > clickSpeed {
                doubleTapPhase = touches.count == 2 ? .anchored(anchorSet(from: touches)) : .idle
                return []
            }

            switch touches.count {
            case 2:
                if anchorSet(from: touches) != candidate.anchorIDs {
                    doubleTapPhase = .anchored(anchorSet(from: touches))
                }
                return []
            case 3:
                guard candidate.anchorIDs.isSubset(of: anchorSet(from: touches)) else {
                    doubleTapPhase = .idle
                    return []
                }
                candidate.lastTransitionAt = timestamp
                doubleTapPhase = .secondTapDown(candidate)
                return []
            default:
                doubleTapPhase = .idle
                return []
            }

        case let .secondTapDown(candidate):
            if timestamp - candidate.lastTransitionAt > clickSpeed {
                doubleTapPhase = touches.count == 2 ? .anchored(anchorSet(from: touches)) : .idle
                return []
            }

            guard touches.count == 2 else {
                if touches.count != 3 {
                    doubleTapPhase = .idle
                }
                return []
            }

            guard anchorSet(from: touches) == candidate.anchorIDs else {
                doubleTapPhase = .anchored(anchorSet(from: touches))
                return []
            }

            doubleTapPhase = .anchored(candidate.anchorIDs)
            switch candidate.role {
            case .index:
                return [.twoFixIndexDoubleTap]
            case .middle:
                return [.twoFixMiddleDoubleTap]
            case .ring:
                return [.twoFixRingDoubleTap]
            }
        }
    }

    private func anchorSet(from touches: [TouchPoint]) -> Set<Int> {
        Set(touches.map(\.id))
    }

    private func tapRole(for touches: [TouchPoint], anchorIDs: Set<Int>) -> TwoFixDoubleTapRole? {
        guard touches.count == 3 else { return nil }
        let transformedTouches = transformedTouches(from: touches)
        guard let transientTouch = transformedTouches.first(where: { !anchorIDs.contains($0.touch.id) }) else {
            return nil
        }

        let orderedTouches = transformedTouches.sorted {
            diagonalCoordinate(for: $0.position) < diagonalCoordinate(for: $1.position)
        }

        guard let index = orderedTouches.firstIndex(where: { $0.touch.id == transientTouch.touch.id }) else {
            return nil
        }

        switch index {
        case 0:
            return .index
        case 1:
            return .middle
        default:
            return .ring
        }
    }

    private func transformedTouches(from touches: [TouchPoint]) -> [TransformedTouch] {
        touches.map { touch in
            let transformedX = handedness == .left ? 1 - touch.position.x : touch.position.x
            return TransformedTouch(
                touch: touch,
                position: CGPoint(x: transformedX, y: touch.position.y)
            )
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
}

private struct RestingFinger {
    let id: Int
    let startedAt: Double
}

private struct OneFixTapSession {
    let fixedFingerID: Int
    let startedAt: Double
    var initialPositions: [Int: CGPoint]
    let transformedFixedOrigin: CGPoint
    let transformedTapOrigin: CGPoint
}

private struct OneFixSlideSession {
    let fixedFingerID: Int
    let fixedOrigin: CGPoint
    let sliderOrigins: [Int: CGPoint]
}

private enum TwoFixDoubleTapRole {
    case index
    case middle
    case ring
}

private struct TwoFixDoubleTapCandidate {
    let anchorIDs: Set<Int>
    let role: TwoFixDoubleTapRole
    var lastTransitionAt: Double
}

private enum TwoFixDoubleTapPhase {
    case idle
    case anchored(Set<Int>)
    case firstTapDown(TwoFixDoubleTapCandidate)
    case betweenTaps(TwoFixDoubleTapCandidate)
    case secondTapDown(TwoFixDoubleTapCandidate)
}

private struct TransformedTouch {
    let touch: TouchPoint
    let position: CGPoint
}
