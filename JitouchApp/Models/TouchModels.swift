import CoreGraphics
import Foundation

enum TouchState: Int, Sendable {
    case notTracking = 0
    case startInRange = 1
    case hoverInRange = 2
    case makeTouch = 3
    case touching = 4
    case breakTouch = 5
    case lingerInRange = 6
    case outOfRange = 7

    var isActive: Bool {
        self == .makeTouch || self == .touching
    }
}

struct TouchPoint: Hashable, Sendable {
    let id: Int
    let state: TouchState
    let position: CGPoint
    let velocity: CGVector
    let size: Float
    let angle: Float
    let majorAxis: Float
    let minorAxis: Float
    let timestamp: Double

    init(
        id: Int,
        state: TouchState,
        position: CGPoint,
        velocity: CGVector,
        size: Float,
        angle: Float,
        majorAxis: Float,
        minorAxis: Float,
        timestamp: Double
    ) {
        self.id = id
        self.state = state
        self.position = position
        self.velocity = velocity
        self.size = size
        self.angle = angle
        self.majorAxis = majorAxis
        self.minorAxis = minorAxis
        self.timestamp = timestamp
    }

    init(finger: Finger) {
        self.init(
            id: Int(finger.identifier),
            state: TouchState(rawValue: Int(finger.state.rawValue)) ?? .notTracking,
            position: CGPoint(
                x: CGFloat(finger.normalized.pos.x),
                y: CGFloat(finger.normalized.pos.y)
            ),
            velocity: CGVector(
                dx: CGFloat(finger.normalized.vel.x),
                dy: CGFloat(finger.normalized.vel.y)
            ),
            size: finger.size,
            angle: finger.angle,
            majorAxis: finger.majorAxis,
            minorAxis: finger.minorAxis,
            timestamp: finger.timestamp
        )
    }
}

enum DeviceType: String, CaseIterable, Sendable {
    case trackpad
    case magicMouse
}

struct TouchFrame: Sendable {
    let touches: [TouchPoint]
    let timestamp: Double
    let deviceType: DeviceType

    var activeTouches: [TouchPoint] {
        touches.filter { $0.state.isActive }
    }

    var fingerCount: Int {
        activeTouches.count
    }
}

enum Direction: String, Sendable {
    case left
    case right
    case up
    case down
}

enum Side: String, Sendable {
    case left
    case right
}

enum PinchDirection: String, Sendable {
    case inward
    case outward
}

enum MagicMouseOneFixTap: String, Sendable, Hashable {
    case middleFixIndexNear
    case middleFixIndexFar
    case indexFixMiddleNear
    case indexFixMiddleFar
}

enum MagicMouseTwoFingerSlide: String, Sendable, Hashable {
    case middleFixIndexSlideOut
    case middleFixIndexSlideIn
    case indexFixMiddleSlideIn
    case indexFixMiddleSlideOut
}

enum ThumbPhase: String, Sendable, Hashable {
    case began
    case ended
}

enum TabDirection: String, Sendable {
    case pinkyToIndex
    case indexToPinky
}

enum MoveResizeMode: String, Sendable, Hashable {
    case move
    case resize
}

enum MoveResizePhase: Sendable, Hashable {
    case began(MoveResizeMode)
    case changed(mode: MoveResizeMode, dx: CGFloat, dy: CGFloat)
    case ended
}

struct RecognizedCharacter: Sendable, Hashable {
    let value: String
    let score: Double
}

enum GestureEvent: Sendable, Hashable {
    case threeFingerTap
    case threeFingerSwipe(Direction)
    case fourFingerTap
    case fourFingerSwipe(Direction)
    case oneFixOneTap(Side)
    case oneFixTwoSlide(Direction)
    case oneFixPressTwoSlide(Direction)
    case twoFixIndexDoubleTap
    case twoFixMiddleDoubleTap
    case twoFixRingDoubleTap
    case twoFixOneSlide(Direction)
    case threeFingerPinch(PinchDirection)
    case moveResize(MoveResizePhase)
    case tabSwitch(TabDirection)
    case characterRecognized(RecognizedCharacter)
    case mmOneFixOneTap(MagicMouseOneFixTap)
    case mmTwoFingerSlide(MagicMouseTwoFingerSlide)
    case mmTwoFixOneSlide(Direction)
    case mmThumb(ThumbPhase)
    case mmPinch(PinchDirection)
    case mmThreeFingerSwipe(Direction)
    case mmMiddleClick
    case mmVShapeMoveResize(MoveResizePhase)
}
