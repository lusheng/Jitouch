import CoreGraphics

@testable import Jitouch

enum TouchFrameFactory {
    static func touch(
        id: Int,
        x: CGFloat,
        y: CGFloat,
        timestamp: Double = 0,
        state: TouchState = .touching,
        size: Float = 0.35,
        angle: Float = 0,
        majorAxis: Float = 1,
        minorAxis: Float = 1,
        velocity: CGVector = .zero
    ) -> TouchPoint {
        TouchPoint(
            id: id,
            state: state,
            position: CGPoint(x: x, y: y),
            velocity: velocity,
            size: size,
            angle: angle,
            majorAxis: majorAxis,
            minorAxis: minorAxis,
            timestamp: timestamp
        )
    }

    static func trackpadFrame(timestamp: Double, touches: [TouchPoint]) -> TouchFrame {
        TouchFrame(touches: touches, timestamp: timestamp, deviceType: .trackpad)
    }

    static func magicMouseFrame(timestamp: Double, touches: [TouchPoint]) -> TouchFrame {
        TouchFrame(touches: touches, timestamp: timestamp, deviceType: .magicMouse)
    }

    static func releaseFrame(deviceType: DeviceType, timestamp: Double) -> TouchFrame {
        TouchFrame(touches: [], timestamp: timestamp, deviceType: deviceType)
    }

    static func trackpadThreeFingerTap(startTimestamp: Double = 0) -> [TouchFrame] {
        let touches = [
            touch(id: 1, x: 0.25, y: 0.45, timestamp: startTimestamp),
            touch(id: 2, x: 0.40, y: 0.48, timestamp: startTimestamp),
            touch(id: 3, x: 0.55, y: 0.46, timestamp: startTimestamp),
        ]

        return [
            trackpadFrame(timestamp: startTimestamp, touches: touches),
            trackpadFrame(timestamp: startTimestamp + 0.05, touches: touches),
            releaseFrame(deviceType: .trackpad, timestamp: startTimestamp + 0.10),
        ]
    }

    static func trackpadFourFingerTap(startTimestamp: Double = 0) -> [TouchFrame] {
        let touches = [
            touch(id: 1, x: 0.20, y: 0.45, timestamp: startTimestamp),
            touch(id: 2, x: 0.35, y: 0.47, timestamp: startTimestamp),
            touch(id: 3, x: 0.50, y: 0.49, timestamp: startTimestamp),
            touch(id: 4, x: 0.65, y: 0.46, timestamp: startTimestamp),
        ]

        return [
            trackpadFrame(timestamp: startTimestamp, touches: touches),
            trackpadFrame(timestamp: startTimestamp + 0.05, touches: touches),
            releaseFrame(deviceType: .trackpad, timestamp: startTimestamp + 0.10),
        ]
    }

    static func trackpadThreeFingerSwipe(
        direction: Direction,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let start = [
            touch(id: 1, x: 0.30, y: 0.55, timestamp: startTimestamp),
            touch(id: 2, x: 0.45, y: 0.56, timestamp: startTimestamp),
            touch(id: 3, x: 0.60, y: 0.54, timestamp: startTimestamp),
        ]

        let delta: CGPoint
        switch direction {
        case .left:
            delta = CGPoint(x: -0.14, y: 0)
        case .right:
            delta = CGPoint(x: 0.14, y: 0)
        case .up:
            delta = CGPoint(x: 0, y: 0.15)
        case .down:
            delta = CGPoint(x: 0, y: -0.15)
        }

        let moved = start.map { original in
            touch(
                id: original.id,
                x: original.position.x + delta.x,
                y: original.position.y + delta.y,
                timestamp: startTimestamp + 0.05
            )
        }

        return [
            trackpadFrame(timestamp: startTimestamp, touches: start),
            trackpadFrame(timestamp: startTimestamp + 0.05, touches: moved),
        ]
    }

    static func trackpadOneFixTap(
        side: Side,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let fixedX: CGFloat = 0.28
        let tappedX: CGFloat = side == .left ? 0.18 : 0.38

        let rest = [
            touch(id: 1, x: fixedX, y: 0.46, timestamp: startTimestamp),
        ]

        let pair = [
            touch(id: 1, x: fixedX, y: 0.46, timestamp: startTimestamp + 0.07),
            touch(id: 2, x: tappedX, y: 0.47, timestamp: startTimestamp + 0.07),
        ]

        let settledPair = [
            touch(id: 1, x: fixedX, y: 0.46, timestamp: startTimestamp + 0.11),
            touch(id: 2, x: tappedX, y: 0.47, timestamp: startTimestamp + 0.11),
        ]

        let release = [
            touch(id: 1, x: fixedX, y: 0.46, timestamp: startTimestamp + 0.16),
        ]

        return [
            trackpadFrame(timestamp: startTimestamp, touches: rest),
            trackpadFrame(timestamp: startTimestamp + 0.07, touches: pair),
            trackpadFrame(timestamp: startTimestamp + 0.11, touches: settledPair),
            trackpadFrame(timestamp: startTimestamp + 0.16, touches: release),
        ]
    }

    static func trackpadOneFixTwoSlide(
        direction: Direction,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let start = [
            touch(id: 1, x: 0.18, y: 0.35, timestamp: startTimestamp),
            touch(id: 2, x: 0.34, y: 0.58, timestamp: startTimestamp),
            touch(id: 3, x: 0.50, y: 0.60, timestamp: startTimestamp),
        ]

        let deltaY: CGFloat
        switch direction {
        case .up:
            deltaY = 0.18
        case .down:
            deltaY = -0.18
        case .left, .right:
            deltaY = 0
        }

        let moved = [
            touch(id: 1, x: 0.18, y: 0.35, timestamp: startTimestamp + 0.05),
            touch(id: 2, x: 0.34, y: 0.58 + deltaY, timestamp: startTimestamp + 0.05),
            touch(id: 3, x: 0.50, y: 0.60 + deltaY, timestamp: startTimestamp + 0.05),
        ]

        return [
            trackpadFrame(timestamp: startTimestamp, touches: start),
            trackpadFrame(timestamp: startTimestamp + 0.05, touches: moved),
        ]
    }

    static func trackpadThreeFingerPinch(
        direction: PinchDirection,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let start = [
            touch(id: 1, x: 0.20, y: 0.50, timestamp: startTimestamp),
            touch(id: 2, x: 0.50, y: 0.50, timestamp: startTimestamp),
            touch(id: 3, x: 0.80, y: 0.50, timestamp: startTimestamp),
        ]

        let moved: [TouchPoint]
        switch direction {
        case .outward:
            moved = [
                touch(id: 1, x: 0.08, y: 0.50, timestamp: startTimestamp + 0.05),
                touch(id: 2, x: 0.50, y: 0.50, timestamp: startTimestamp + 0.05),
                touch(id: 3, x: 0.92, y: 0.50, timestamp: startTimestamp + 0.05),
            ]
        case .inward:
            moved = [
                touch(id: 1, x: 0.32, y: 0.50, timestamp: startTimestamp + 0.05),
                touch(id: 2, x: 0.50, y: 0.50, timestamp: startTimestamp + 0.05),
                touch(id: 3, x: 0.68, y: 0.50, timestamp: startTimestamp + 0.05),
            ]
        }

        return [
            trackpadFrame(timestamp: startTimestamp, touches: start),
            trackpadFrame(timestamp: startTimestamp + 0.05, touches: moved),
        ]
    }

    static func trackpadTabSwitch(
        direction: TabDirection,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let coordinates: [[CGPoint]]
        switch direction {
        case .indexToPinky:
            coordinates = [
                [CGPoint(x: 0.10, y: 0.10)],
                [CGPoint(x: 0.18, y: 0.18), CGPoint(x: 0.22, y: 0.22)],
                [CGPoint(x: 0.28, y: 0.28), CGPoint(x: 0.32, y: 0.32), CGPoint(x: 0.36, y: 0.36)],
                [CGPoint(x: 0.40, y: 0.40), CGPoint(x: 0.44, y: 0.44), CGPoint(x: 0.48, y: 0.48), CGPoint(x: 0.52, y: 0.52)],
            ]
        case .pinkyToIndex:
            coordinates = [
                [CGPoint(x: 0.70, y: 0.70)],
                [CGPoint(x: 0.55, y: 0.55), CGPoint(x: 0.60, y: 0.60)],
                [CGPoint(x: 0.40, y: 0.40), CGPoint(x: 0.45, y: 0.45), CGPoint(x: 0.50, y: 0.50)],
                [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.30, y: 0.30), CGPoint(x: 0.35, y: 0.35), CGPoint(x: 0.40, y: 0.40)],
            ]
        }

        let activeFrames = coordinates.enumerated().map { index, points in
            let timestamp = startTimestamp + (Double(index) * 0.05)
            let touches = points.enumerated().map { offset, point in
                touch(id: offset + 1, x: point.x, y: point.y, timestamp: timestamp)
            }
            return trackpadFrame(timestamp: timestamp, touches: touches)
        }

        return activeFrames + [
            releaseFrame(deviceType: .trackpad, timestamp: startTimestamp + 0.20),
        ]
    }

    static func trackpadMoveResizeSession(
        mode: MoveResizeMode,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let activationPoint: CGPoint = mode == .move
            ? CGPoint(x: 0.50, y: 0.35)
            : CGPoint(x: 0.35, y: 0.65)
        let changedPoint: CGPoint = mode == .move
            ? CGPoint(x: 0.52, y: 0.32)
            : CGPoint(x: 0.33, y: 0.69)

        return [
            trackpadFrame(
                timestamp: startTimestamp,
                touches: [
                    touch(id: 1, x: 0.30, y: 0.30, timestamp: startTimestamp),
                ]
            ),
            trackpadFrame(
                timestamp: startTimestamp + 0.05,
                touches: [
                    touch(id: 1, x: 0.30, y: 0.30, timestamp: startTimestamp + 0.05),
                    touch(id: 2, x: 0.50, y: 0.50, timestamp: startTimestamp + 0.05),
                ]
            ),
            trackpadFrame(
                timestamp: startTimestamp + 0.10,
                touches: [
                    touch(id: 1, x: 0.30, y: 0.30, timestamp: startTimestamp + 0.10),
                    touch(
                        id: 2,
                        x: activationPoint.x,
                        y: activationPoint.y,
                        timestamp: startTimestamp + 0.10
                    ),
                ]
            ),
            trackpadFrame(
                timestamp: startTimestamp + 0.15,
                touches: [
                    touch(
                        id: 2,
                        x: changedPoint.x,
                        y: changedPoint.y,
                        timestamp: startTimestamp + 0.15
                    ),
                ]
            ),
            releaseFrame(deviceType: .trackpad, timestamp: startTimestamp + 0.20),
        ]
    }

    static func magicMouseThreeFingerSwipe(
        direction: Direction,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let start = [
            touch(id: 1, x: 0.28, y: 0.78, timestamp: startTimestamp),
            touch(id: 2, x: 0.50, y: 0.80, timestamp: startTimestamp),
            touch(id: 3, x: 0.72, y: 0.79, timestamp: startTimestamp),
        ]

        let delta: CGPoint
        switch direction {
        case .left:
            delta = CGPoint(x: -0.12, y: 0)
        case .right:
            delta = CGPoint(x: 0.12, y: 0)
        case .up:
            delta = CGPoint(x: 0, y: 0.10)
        case .down:
            delta = CGPoint(x: 0, y: -0.10)
        }

        let moved = start.map { original in
            touch(
                id: original.id,
                x: original.position.x + delta.x,
                y: original.position.y + delta.y,
                timestamp: startTimestamp + 0.05
            )
        }

        return [
            magicMouseFrame(timestamp: startTimestamp, touches: start),
            magicMouseFrame(timestamp: startTimestamp + 0.05, touches: moved),
        ]
    }

    static func magicMousePinch(
        direction: PinchDirection,
        startTimestamp: Double = 0
    ) -> [TouchFrame] {
        let start = [
            touch(id: 1, x: 0.42, y: 0.80, timestamp: startTimestamp),
            touch(id: 2, x: 0.58, y: 0.81, timestamp: startTimestamp),
        ]

        let moved: [TouchPoint]
        switch direction {
        case .outward:
            moved = [
                touch(id: 1, x: 0.22, y: 0.80, timestamp: startTimestamp + 0.05),
                touch(id: 2, x: 0.78, y: 0.81, timestamp: startTimestamp + 0.05),
            ]
        case .inward:
            moved = [
                touch(id: 1, x: 0.48, y: 0.80, timestamp: startTimestamp + 0.05),
                touch(id: 2, x: 0.52, y: 0.81, timestamp: startTimestamp + 0.05),
            ]
        }

        return [
            magicMouseFrame(timestamp: startTimestamp, touches: start),
            magicMouseFrame(timestamp: startTimestamp + 0.05, touches: moved),
        ]
    }

    static let characterLAngles: [CGFloat] = [-.pi / 2, 0]
    static let characterUpAngles: [CGFloat] = [.pi / 2]
}
