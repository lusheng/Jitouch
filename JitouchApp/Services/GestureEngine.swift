import Observation

@MainActor
@Observable
final class GestureEngine {
    var onGestureEvent: ((GestureEvent) -> Void)?
    private(set) var recentEvents: [GestureEvent] = []

    private let trackpadContext: TrackpadGestureContext
    private var trackpadCharacterRecognizers: [any GestureRecognizer]
    private var trackpadGestureRecognizers: [any GestureRecognizer]
    private var mouseRecognizers: [any GestureRecognizer]

    init(
        trackpadRecognizers: [any GestureRecognizer]? = nil,
        mouseRecognizers: [any GestureRecognizer]? = nil
    ) {
        let trackpadContext = TrackpadGestureContext()
        self.trackpadContext = trackpadContext
        self.trackpadCharacterRecognizers = [
            TrackpadCharacterRecognizer(context: trackpadContext),
            TrackpadOneFingerCharacterRecognizer(context: trackpadContext),
        ]
        self.trackpadGestureRecognizers = trackpadRecognizers ?? [
            TrackpadMoveResizeRecognizer(),
            TrackpadTabSwitchRecognizer(context: trackpadContext),
            TrackpadTapRecognizer(context: trackpadContext),
            TrackpadFixFingerRecognizer(),
            TrackpadSwipeRecognizer(),
            TrackpadPinchRecognizer(),
        ]
        self.mouseRecognizers = mouseRecognizers ?? [
            MagicMouseRecognizer(),
        ]
    }

    var recognizerCount: Int {
        trackpadCharacterRecognizers.count + trackpadGestureRecognizers.count + mouseRecognizers.count
    }

    func handleTouchFrame(_ frame: TouchFrame) {
        if frame.deviceType == .trackpad {
            for recognizer in trackpadCharacterRecognizers where recognizer.isEnabled {
                for event in recognizer.processFrame(frame) {
                    append(event)
                    onGestureEvent?(event)
                }
            }

            guard !trackpadContext.isCharacterRecognitionActive else {
                return
            }

            for recognizer in trackpadGestureRecognizers where recognizer.isEnabled {
                for event in recognizer.processFrame(frame) {
                    append(event)
                    onGestureEvent?(event)
                }
            }
            return
        }

        for recognizer in mouseRecognizers where recognizer.isEnabled {
            for event in recognizer.processFrame(frame) {
                append(event)
                onGestureEvent?(event)
            }
        }
    }

    func reset() {
        trackpadCharacterRecognizers.forEach { $0.reset() }
        trackpadGestureRecognizers.forEach { $0.reset() }
        mouseRecognizers.forEach { $0.reset() }
        trackpadContext.endCharacterRecognition()
        recentEvents.removeAll()
    }

    func updateSettings(_ settings: JitouchSettings) {
        trackpadCharacterRecognizers.forEach { $0.updateSettings(settings) }
        trackpadGestureRecognizers.forEach { $0.updateSettings(settings) }
        mouseRecognizers.forEach { $0.updateSettings(settings) }
    }

    func publish(_ event: GestureEvent) {
        append(event)
        onGestureEvent?(event)
    }

    private func append(_ event: GestureEvent) {
        recentEvents.append(event)
        if recentEvents.count > 20 {
            recentEvents.removeFirst(recentEvents.count - 20)
        }
    }
}
