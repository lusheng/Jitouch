import CoreGraphics
import Foundation

@MainActor
final class TrackpadTabSwitchRecognizer: GestureRecognizer {
    var isEnabled = true

    private let context: TrackpadGestureContext
    private var clickSpeed = 0.25

    private var sessions: [TabDirection: TabSwitchSession] = [
        .indexToPinky: TabSwitchSession(),
        .pinkyToIndex: TabSwitchSession(),
    ]

    init(context: TrackpadGestureContext) {
        self.context = context
    }

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        let fingerCount = frame.fingerCount
        let averageDiagonal = averageDiagonalCoordinate(for: frame.activeTouches)

        for direction in [TabDirection.indexToPinky, .pinkyToIndex] {
            if let event = processDirection(
                direction,
                fingerCount: fingerCount,
                averageDiagonal: averageDiagonal,
                timestamp: frame.timestamp
            ) {
                context.suppressFourFingerTapOnce()
                return [event]
            }
        }

        return []
    }

    func reset() {
        sessions = [
            .indexToPinky: TabSwitchSession(),
            .pinkyToIndex: TabSwitchSession(),
        ]
    }

    func updateSettings(_ settings: JitouchSettings) {
        clickSpeed = settings.clickSpeed
    }

    private func processDirection(
        _ direction: TabDirection,
        fingerCount: Int,
        averageDiagonal: CGFloat,
        timestamp: Double
    ) -> GestureEvent? {
        guard var session = sessions[direction] else { return nil }

        if session.step == 0 {
            if fingerCount == 1 {
                session.step = 1
                session.lastFingerCount = 1
                session.lastAverageDiagonal = averageDiagonal
                session.lastStepTimestamp = timestamp
            }
            sessions[direction] = session
            return nil
        }

        if session.step == 4 {
            if timestamp - session.lastStepTimestamp > clickSpeed {
                sessions[direction] = TabSwitchSession()
                return nil
            }

            if fingerCount == 4 {
                if abs(averageDiagonal - session.lastAverageDiagonal) > 0.1 {
                    sessions[direction] = TabSwitchSession()
                } else {
                    session.lastFingerCount = 4
                    sessions[direction] = session
                }
                return nil
            }

            if fingerCount == 0 {
                sessions[direction] = TabSwitchSession()
                return .tabSwitch(direction)
            }

            if fingerCount > 4 {
                sessions[direction] = TabSwitchSession()
                return nil
            }

            session.lastFingerCount = fingerCount
            sessions[direction] = session
            return nil
        }

        if timestamp - session.lastStepTimestamp > clickSpeed {
            sessions[direction] = TabSwitchSession()
            return nil
        }

        if fingerCount == session.lastFingerCount + 1 {
            let shouldAdvance: Bool
            switch direction {
            case .indexToPinky:
                shouldAdvance = averageDiagonal > session.lastAverageDiagonal
            case .pinkyToIndex:
                shouldAdvance = averageDiagonal < session.lastAverageDiagonal
            }

            if shouldAdvance {
                session.step += 1
                session.lastAverageDiagonal = averageDiagonal
                session.lastStepTimestamp = timestamp
            }
        } else if fingerCount < session.lastFingerCount || fingerCount > session.lastFingerCount + 1 {
            sessions[direction] = TabSwitchSession()
            return nil
        }

        session.lastFingerCount = fingerCount
        sessions[direction] = session
        return nil
    }

    private func averageDiagonalCoordinate(for touches: [TouchPoint]) -> CGFloat {
        guard !touches.isEmpty else { return 0 }
        let total = touches.reduce(CGFloat.zero) { partial, touch in
            partial + touch.position.x + touch.position.y
        }
        return total / CGFloat(touches.count)
    }
}

private struct TabSwitchSession {
    var step = 0
    var lastFingerCount = 0
    var lastAverageDiagonal: CGFloat = 0
    var lastStepTimestamp: Double = -1
}
