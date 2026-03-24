import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class MagicMouseRecognizer: GestureRecognizer {
    var isEnabled = true

    private let vShapeMovementSquared: CGFloat = 0.0005
    private let oneFixTapMovementSquared: CGFloat = 0.0007
    private let middleClickMovementSquared: CGFloat = 0.0008
    private let twoFixOneSlideAnchorMovementSquared: CGFloat = 0.001
    private let twoFixOneSlideActivationMovementSquared: CGFloat = 0.001
    private let twoFixOneSlideStopMovementSquared: CGFloat = 0.000001

    private var handedness: Handedness = .right
    private var clickSpeed = 0.25
    private var oneFixTapSizeThreshold: Float = 0.6667
    private var twoFixOneSlideHorizontalTrigger: CGFloat = 0.07
    private var twoFixOneSlideVerticalTrigger: CGFloat = 0.08

    private var horizontalConsistencyThreshold: CGFloat = 0.015
    private var rightConsistencyThreshold: CGFloat = 0.01
    private var verticalConsistencyThreshold: CGFloat = 0.03
    private var veryDownConsistencyThreshold: CGFloat = 0.04

    private var leftTrigger: CGFloat = 0.25
    private var rightTrigger: CGFloat = 0.22
    private var upTrigger: CGFloat = 0.25
    private var downTrigger: CGFloat = 0.17

    private var thumbActive = false
    private var swipeSession: MagicMouseSwipeSession?
    private var twoFingerSession: MagicMouseTwoFingerSession?
    private var twoFixOneSlideState: MagicMouseTwoFixOneSlideState = .idle
    private var oneFixTapState: MagicMouseOneFixTapState = .idle
    private var vShapeCandidate: MagicMouseVShapeCandidate?
    private var moveResizeMode: MoveResizeMode?
    private var middleClickCandidate: MagicMouseMiddleClickCandidate?

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .magicMouse else { return [] }

        let prepared = preparedTouches(from: frame)
        if prepared.shouldIgnoreFrame {
            let events = forcedTerminationEvents()
            reset()
            return events
        }

        let activeTouches = prepared.activeTouches
        let gestureTouches = prepared.gestureTouches
        var events = [GestureEvent]()
        events.append(contentsOf: processThumb(thumb: prepared.thumbTouch))
        events.append(contentsOf: processSwipe(touches: gestureTouches))
        events.append(contentsOf: processTwoFingerGestures(touches: gestureTouches))
        events.append(contentsOf: processTwoFixOneSlide(touches: gestureTouches))
        events.append(contentsOf: processOneFixTap(touches: activeTouches, timestamp: frame.timestamp))
        events.append(contentsOf: processMoveResize(touches: gestureTouches))
        events.append(contentsOf: processMiddleClick(touches: gestureTouches, timestamp: frame.timestamp))
        return events
    }

    func reset() {
        thumbActive = false
        swipeSession = nil
        twoFingerSession = nil
        twoFixOneSlideState = .idle
        oneFixTapState = .idle
        vShapeCandidate = nil
        moveResizeMode = nil
        middleClickCandidate = nil
    }

    private func forcedTerminationEvents() -> [GestureEvent] {
        var events: [GestureEvent] = []
        if thumbActive {
            events.append(.mmThumb(.ended))
        }
        if moveResizeMode != nil {
            events.append(.mmVShapeMoveResize(.ended))
        }
        return events
    }

    func updateSettings(_ settings: JitouchSettings) {
        isEnabled = settings.magicMouseEnabled
        handedness = settings.magicMouseHandedness
        clickSpeed = settings.clickSpeed
        oneFixTapSizeThreshold = Float(settings.sensitivity / 10) + 0.2

        let scale = max(0.65, min(1.35, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        let characterDistanceScale = CGFloat(settings.characterRecognitionIndexRingDistance / 0.33)
        leftTrigger = 0.25 * scale
        rightTrigger = 0.22 * scale
        upTrigger = 0.25 * scale
        downTrigger = 0.17 * scale
        twoFixOneSlideHorizontalTrigger = 0.07 * characterDistanceScale
        twoFixOneSlideVerticalTrigger = 0.08 * characterDistanceScale
    }

    private func processThumb(thumb: MagicMouseTouch?) -> [GestureEvent] {
        switch (thumbActive, thumb != nil) {
        case (false, true):
            thumbActive = true
            return [.mmThumb(.began)]
        case (true, false):
            thumbActive = false
            return [.mmThumb(.ended)]
        default:
            return []
        }
    }

    private func processSwipe(touches: [MagicMouseTouch]) -> [GestureEvent] {
        guard touches.count == 3 else {
            swipeSession = nil
            return []
        }

        let ids = Set(touches.map(\.id))
        if swipeSession == nil || swipeSession?.ids != ids {
            swipeSession = MagicMouseSwipeSession(
                ids: ids,
                origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
            )
            return []
        }

        guard var session = swipeSession else { return [] }
        guard !session.hasTriggered else { return [] }

        let deltas = touches.compactMap { touch -> CGPoint? in
            guard let origin = session.origins[touch.id] else { return nil }
            return CGPoint(x: touch.position.x - origin.x, y: touch.position.y - origin.y)
        }

        guard deltas.count == touches.count else {
            swipeSession = MagicMouseSwipeSession(
                ids: ids,
                origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
            )
            return []
        }

        let sumX = deltas.map(\.x).reduce(0, +)
        let sumY = deltas.map(\.y).reduce(0, +)

        let movingLeft = deltas.allSatisfy { $0.x < -horizontalConsistencyThreshold }
        let movingRight = deltas.allSatisfy { $0.x > rightConsistencyThreshold }
        let movingUp = deltas.allSatisfy { $0.y > verticalConsistencyThreshold }
        let movingDown = deltas.allSatisfy { $0.y < -verticalConsistencyThreshold }
        let movingVeryDown = deltas.allSatisfy { $0.y < -veryDownConsistencyThreshold }

        let direction: Direction?
        if !movingDown && !movingUp {
            if movingLeft && sumX < -leftTrigger {
                direction = .left
            } else if movingRight && sumX > rightTrigger {
                direction = .right
            } else {
                direction = nil
            }
        } else if movingVeryDown && sumY < -downTrigger {
            direction = .down
        } else if movingUp && sumY > upTrigger {
            direction = .up
        } else {
            direction = nil
        }

        guard let direction else {
            return []
        }

        session.hasTriggered = true
        swipeSession = session
        return [.mmThreeFingerSwipe(direction)]
    }

    private func processTwoFingerGestures(touches: [MagicMouseTouch]) -> [GestureEvent] {
        guard touches.count == 2 else {
            twoFingerSession = nil
            return []
        }

        let sorted = touches.sorted { $0.position.x < $1.position.x }
        let orderedIDs = sorted.map(\.id)
        if twoFingerSession == nil || twoFingerSession?.orderedIDs != orderedIDs {
            twoFingerSession = MagicMouseTwoFingerSession(
                orderedIDs: orderedIDs,
                origins: Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.position) })
            )
            return []
        }

        guard var session = twoFingerSession else { return [] }
        guard !session.hasTriggered else { return [] }

        guard
            let origin0 = session.origins[sorted[0].id],
            let origin1 = session.origins[sorted[1].id]
        else {
            twoFingerSession = MagicMouseTwoFingerSession(
                orderedIDs: orderedIDs,
                origins: Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.position) })
            )
            return []
        }

        let diff0 = CGPoint(x: sorted[0].position.x - origin0.x, y: sorted[0].position.y - origin0.y)
        let diff1 = CGPoint(x: sorted[1].position.x - origin1.x, y: sorted[1].position.y - origin1.y)
        let dis0 = lengthSquared(diff0)
        let dis1 = lengthSquared(diff1)

        let event: GestureEvent?
        if dis1 < 0.002, dis0 > 0.06, abs(diff0.y) < 0.05 {
            event = .mmTwoFingerSlide(diff0.x < 0 ? .middleFixIndexSlideOut : .middleFixIndexSlideIn)
        } else if dis0 < 0.002, dis1 > 0.02, abs(diff1.y) < 0.05 {
            event = .mmTwoFingerSlide(diff1.x < 0 ? .indexFixMiddleSlideIn : .indexFixMiddleSlideOut)
        } else if
            dis0 > 0.01,
            dis1 > 0.01,
            (dis0 > 0.02 || dis1 > 0.02),
            abs(diff0.y) < 0.1,
            abs(diff1.y) < 0.1
        {
            if diff0.x < 0, diff1.x > 0 {
                event = .mmPinch(.outward)
            } else if diff0.x > 0, diff1.x < 0 {
                event = .mmPinch(.inward)
            } else {
                event = nil
            }
        } else {
            event = nil
        }

        guard let event else { return [] }
        session.hasTriggered = true
        twoFingerSession = session
        return [event]
    }

    private func processTwoFixOneSlide(touches: [MagicMouseTouch]) -> [GestureEvent] {
        switch twoFixOneSlideState {
        case .idle:
            guard touches.count == 2 else { return [] }
            if squaredDistance(between: touches[0].position, and: touches[1].position) < 0.4 {
                twoFixOneSlideState = .armed(ids: Set(touches.map(\.id)))
            }
            return []

        case .armed:
            switch touches.count {
            case 2:
                if squaredDistance(between: touches[0].position, and: touches[1].position) >= 0.4 {
                    twoFixOneSlideState = .idle
                } else {
                    twoFixOneSlideState = .armed(ids: Set(touches.map(\.id)))
                }
                return []
            case 3:
                guard let candidate = makeTwoFixOneSlideCandidate(from: touches) else {
                    twoFixOneSlideState = .idle
                    return []
                }
                twoFixOneSlideState = .tracking(candidate)
                return []
            default:
                twoFixOneSlideState = .idle
                return []
            }

        case var .tracking(candidate):
            switch touches.count {
            case 3:
                guard
                    let movingTouch = touches.first(where: { $0.id == candidate.movingTouchID }),
                    anchorsRemainStable(candidate: candidate, touches: touches)
                else {
                    twoFixOneSlideState = .idle
                    return []
                }

                let movementFromOrigin = squaredDistance(
                    between: movingTouch.position,
                    and: candidate.movingOrigin
                )
                if !candidate.hasStartedMoving {
                    if movementFromOrigin > twoFixOneSlideActivationMovementSquared {
                        candidate.hasStartedMoving = true
                        candidate.lastPosition = movingTouch.position
                    }
                    twoFixOneSlideState = .tracking(candidate)
                    return []
                }

                let movementFromLast = squaredDistance(
                    between: movingTouch.position,
                    and: candidate.lastPosition
                )
                let event = twoFixOneSlideEvent(origin: candidate.movingOrigin, current: movingTouch.position)
                candidate.lastPosition = movingTouch.position

                if movementFromLast < twoFixOneSlideStopMovementSquared, let event {
                    candidate.hasStartedMoving = false
                    candidate.movingOrigin = movingTouch.position
                    twoFixOneSlideState = .tracking(candidate)
                    return [event]
                }

                twoFixOneSlideState = .tracking(candidate)
                return []

            case 2:
                if candidate.anchorIDs == Set(touches.map(\.id)),
                   candidate.hasStartedMoving,
                   let event = twoFixOneSlideEvent(origin: candidate.movingOrigin, current: candidate.lastPosition) {
                    twoFixOneSlideState = .armed(ids: candidate.anchorIDs)
                    return [event]
                }
                twoFixOneSlideState = touches.count == 2 ? .armed(ids: Set(touches.map(\.id))) : .idle
                return []

            default:
                twoFixOneSlideState = .idle
                return []
            }
        }
    }

    private func processOneFixTap(touches: [MagicMouseTouch], timestamp: Double) -> [GestureEvent] {
        if CGEventSource.buttonState(.hidSystemState, button: .left) {
            oneFixTapState = .idle
            return []
        }

        switch oneFixTapState {
        case .idle:
            if let touch = touches.onlyElement {
                oneFixTapState = .oneFinger(id: touch.id)
            }
            return []

        case let .oneFinger(fixedFingerID):
            switch touches.count {
            case 1:
                oneFixTapState = .oneFinger(id: touches[0].id)
                return []
            case 2:
                guard abs(touches[0].position.y - touches[1].position.y) < 0.25 else {
                    oneFixTapState = .idle
                    return []
                }

                guard touches.allSatisfy({ $0.id == fixedFingerID || $0.size > oneFixTapSizeThreshold }) else {
                    return []
                }

                let averagePosition = CGPoint(
                    x: (touches[0].position.x + touches[1].position.x) / 2,
                    y: (touches[0].position.y + touches[1].position.y) / 2
                )
                oneFixTapState = .twoFinger(
                    MagicMouseOneFixTapCandidate(
                        fixedFingerID: fixedFingerID,
                        startedAt: timestamp,
                        averagePosition: averagePosition,
                        origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
                    )
                )
                return []
            default:
                oneFixTapState = .idle
                return []
            }

        case let .twoFinger(candidate):
            switch touches.count {
            case 1:
                let remainingTouch = touches[0]
                oneFixTapState = .oneFinger(id: remainingTouch.id)

                guard
                    timestamp - candidate.startedAt <= clickSpeed,
                    remainingTouch.id == candidate.fixedFingerID
                else {
                    return []
                }

                let distance = abs(candidate.averagePosition.x - remainingTouch.position.x)
                if candidate.averagePosition.x < remainingTouch.position.x {
                    return [.mmOneFixOneTap(distance > 0.22 ? .middleFixIndexFar : .middleFixIndexNear)]
                }
                return [.mmOneFixOneTap(distance > 0.22 ? .indexFixMiddleFar : .indexFixMiddleNear)]

            case 2:
                guard
                    timestamp - candidate.startedAt <= clickSpeed,
                    touchesStable(touches, origins: candidate.origins, threshold: oneFixTapMovementSquared)
                else {
                    oneFixTapState = .idle
                    return []
                }
                return []

            default:
                oneFixTapState = .idle
                return []
            }
        }
    }

    private func processMoveResize(touches: [MagicMouseTouch]) -> [GestureEvent] {
        switch touches.count {
        case 2:
            if let currentMode = moveResizeMode {
                let point = centroid(of: touches)
                if currentMode != .move {
                    moveResizeMode = .move
                    return [.mmVShapeMoveResize(.began(.move))]
                }
                return [.mmVShapeMoveResize(.changed(mode: .move, dx: point.x, dy: point.y))]
            }

            let sorted = touches.sorted { $0.position.x < $1.position.x }
            guard isVShape(sorted) else {
                vShapeCandidate = nil
                return []
            }

            let ids = Set(sorted.map(\.id))
            if let candidate = vShapeCandidate,
               candidate.ids == ids,
               touchesStable(sorted, origins: candidate.origins, threshold: vShapeMovementSquared) {
                vShapeCandidate = nil
                moveResizeMode = .move
                return [.mmVShapeMoveResize(.began(.move))]
            }

            vShapeCandidate = MagicMouseVShapeCandidate(
                ids: ids,
                origins: Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0.position) })
            )
            return []

        case 1:
            vShapeCandidate = nil
            guard let currentMode = moveResizeMode, let touch = touches.first else {
                return []
            }

            if currentMode != .resize {
                moveResizeMode = .resize
                return [.mmVShapeMoveResize(.began(.resize))]
            }

            return [.mmVShapeMoveResize(.changed(mode: .resize, dx: touch.position.x, dy: touch.position.y))]

        default:
            vShapeCandidate = nil
            guard moveResizeMode != nil else { return [] }
            moveResizeMode = nil
            return [.mmVShapeMoveResize(.ended)]
        }
    }

    private func processMiddleClick(touches: [MagicMouseTouch], timestamp: Double) -> [GestureEvent] {
        guard isMiddleClickCandidate(touches) else {
            defer { middleClickCandidate = nil }

            guard let candidate = middleClickCandidate else { return [] }
            if timestamp - candidate.startedAt <= clickSpeed {
                return [.mmMiddleClick]
            }
            return []
        }

        let ids = Set(touches.map(\.id))
        if let candidate = middleClickCandidate {
            guard candidate.ids == ids else {
                middleClickCandidate = MagicMouseMiddleClickCandidate(
                    ids: ids,
                    startedAt: timestamp,
                    origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
                )
                return []
            }

            if !touchesStable(touches, origins: candidate.origins, threshold: middleClickMovementSquared) {
                middleClickCandidate = nil
            }
            return []
        }

        middleClickCandidate = MagicMouseMiddleClickCandidate(
            ids: ids,
            startedAt: timestamp,
            origins: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
        )
        return []
    }

    private func preparedTouches(from frame: TouchFrame) -> MagicMousePreparedTouches {
        let activeTouches = frame.activeTouches.map(normalizedTouch(from:))
        if activeTouches.contains(where: { $0.size > 5.5 }) {
            return MagicMousePreparedTouches(
                activeTouches: [],
                gestureTouches: [],
                thumbTouch: nil,
                shouldIgnoreFrame: true
            )
        }

        let filteredTouches = activeTouches.filter { touch in
            if activeTouches.count > 1 && touch.position.y < 0.3 {
                return false
            }
            if (touch.position.x < 0.001 || touch.position.x > 0.999) && touch.size < 0.375 {
                return false
            }
            return true
        }

        let thumbID = filteredTouches.count > 1
            ? filteredTouches
                .filter { $0.position.y <= 0.6 && $0.position.x <= 0.15 }
                .min(by: { $0.position.y < $1.position.y })?.id
            : nil

        let thumbTouch = filteredTouches.first(where: { $0.id == thumbID })
        let gestureTouches = filteredTouches.filter { touch in
            touch.id != thumbID
        }

        return MagicMousePreparedTouches(
            activeTouches: filteredTouches,
            gestureTouches: gestureTouches,
            thumbTouch: thumbTouch,
            shouldIgnoreFrame: false
        )
    }

    private func normalizedTouch(from touch: TouchPoint) -> MagicMouseTouch {
        let position = CGPoint(
            x: handedness == .left ? 1 - touch.position.x : touch.position.x,
            y: touch.position.y
        )
        return MagicMouseTouch(
            id: touch.id,
            position: position,
            size: touch.size,
            angle: touch.angle,
            majorAxis: touch.majorAxis
        )
    }

    private func touchesStable(
        _ touches: [MagicMouseTouch],
        origins: [Int: CGPoint],
        threshold: CGFloat
    ) -> Bool {
        touches.allSatisfy { touch in
            guard let origin = origins[touch.id] else { return false }
            let dx = touch.position.x - origin.x
            let dy = touch.position.y - origin.y
            return (dx * dx) + (dy * dy) <= threshold
        }
    }

    private func lengthSquared(_ point: CGPoint) -> CGFloat {
        (point.x * point.x) + (point.y * point.y)
    }

    private func squaredDistance(between lhs: CGPoint, and rhs: CGPoint) -> CGFloat {
        lengthSquared(CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y))
    }

    private func makeTwoFixOneSlideCandidate(from touches: [MagicMouseTouch]) -> MagicMouseTwoFixOneSlideCandidate? {
        guard touches.count == 3 else { return nil }
        let sorted = touches.sorted { diagonalCoordinate(for: $0.position) < diagonalCoordinate(for: $1.position) }
        guard let movingTouch = sorted.first else { return nil }

        let anchorTouches = touches.filter { $0.id != movingTouch.id }
        guard anchorTouches.count == 2 else { return nil }

        return MagicMouseTwoFixOneSlideCandidate(
            anchorIDs: Set(anchorTouches.map(\.id)),
            anchorOrigins: Dictionary(uniqueKeysWithValues: anchorTouches.map { ($0.id, $0.position) }),
            movingTouchID: movingTouch.id,
            movingOrigin: movingTouch.position,
            lastPosition: movingTouch.position
        )
    }

    private func anchorsRemainStable(
        candidate: MagicMouseTwoFixOneSlideCandidate,
        touches: [MagicMouseTouch]
    ) -> Bool {
        let anchors = touches.filter { candidate.anchorIDs.contains($0.id) }
        guard anchors.count == candidate.anchorIDs.count else { return false }
        return touchesStable(
            anchors,
            origins: candidate.anchorOrigins,
            threshold: twoFixOneSlideAnchorMovementSquared
        )
    }

    private func twoFixOneSlideEvent(origin: CGPoint, current: CGPoint) -> GestureEvent? {
        let deltaX = current.x - origin.x
        let deltaY = current.y - origin.y

        guard
            abs(deltaX) >= twoFixOneSlideHorizontalTrigger ||
            abs(deltaY) >= twoFixOneSlideVerticalTrigger
        else {
            return nil
        }

        if abs(deltaX) > abs(deltaY) {
            return .mmTwoFixOneSlide(deltaX >= 0 ? .right : .left)
        }
        return .mmTwoFixOneSlide(deltaY >= 0 ? .up : .down)
    }

    private func diagonalCoordinate(for point: CGPoint) -> CGFloat {
        point.x + point.y
    }

    private func isVShape(_ touches: [MagicMouseTouch]) -> Bool {
        guard touches.count == 2 else { return false }
        let left = touches[0]
        let right = touches[1]

        let leftMatches = (left.position.y > 0.9 && left.position.x <= 0.18) ||
            (left.position.y > 0.8 && left.position.x <= 0.15)
        let rightMatches = (right.position.y > 0.9 && right.position.x >= 0.82) ||
            (right.position.y > 0.8 && right.position.x >= 0.85)
        return leftMatches && rightMatches
    }

    private func centroid(of touches: [MagicMouseTouch]) -> CGPoint {
        let sum = touches.reduce(CGPoint.zero) { partial, touch in
            CGPoint(x: partial.x + touch.position.x, y: partial.y + touch.position.y)
        }
        let count = CGFloat(touches.count)
        return CGPoint(x: sum.x / count, y: sum.y / count)
    }

    private func isMiddleClickCandidate(_ touches: [MagicMouseTouch]) -> Bool {
        guard touches.count == 2 else { return false }
        let sorted = touches.sorted { $0.position.x < $1.position.x }
        let left = sorted[0]
        let right = sorted[1]
        let deltaX = max(0.0001, right.position.x - left.position.x)
        let slope = (right.position.y - left.position.y) / deltaX
        return left.position.x > 0.47 || (left.position.x > 0.35 && slope >= 0.16)
    }
}

private struct MagicMousePreparedTouches {
    let activeTouches: [MagicMouseTouch]
    let gestureTouches: [MagicMouseTouch]
    let thumbTouch: MagicMouseTouch?
    let shouldIgnoreFrame: Bool
}

private struct MagicMouseTouch: Sendable {
    let id: Int
    let position: CGPoint
    let size: Float
    let angle: Float
    let majorAxis: Float
}

private struct MagicMouseSwipeSession {
    let ids: Set<Int>
    let origins: [Int: CGPoint]
    var hasTriggered = false
}

private struct MagicMouseTwoFingerSession {
    let orderedIDs: [Int]
    let origins: [Int: CGPoint]
    var hasTriggered = false
}

private enum MagicMouseTwoFixOneSlideState {
    case idle
    case armed(ids: Set<Int>)
    case tracking(MagicMouseTwoFixOneSlideCandidate)
}

private struct MagicMouseTwoFixOneSlideCandidate {
    let anchorIDs: Set<Int>
    let anchorOrigins: [Int: CGPoint]
    let movingTouchID: Int
    var movingOrigin: CGPoint
    var lastPosition: CGPoint
    var hasStartedMoving = false
}

private enum MagicMouseOneFixTapState {
    case idle
    case oneFinger(id: Int)
    case twoFinger(MagicMouseOneFixTapCandidate)
}

private struct MagicMouseOneFixTapCandidate {
    let fixedFingerID: Int
    let startedAt: Double
    let averagePosition: CGPoint
    let origins: [Int: CGPoint]
}

private struct MagicMouseVShapeCandidate {
    let ids: Set<Int>
    let origins: [Int: CGPoint]
}

private struct MagicMouseMiddleClickCandidate {
    let ids: Set<Int>
    let startedAt: Double
    let origins: [Int: CGPoint]
}

private extension Array {
    var onlyElement: Element? {
        count == 1 ? self[0] : nil
    }
}
