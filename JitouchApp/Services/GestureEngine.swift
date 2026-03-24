import Observation

@MainActor
@Observable
final class GestureEngine {
    var onGestureEvent: ((GestureEvent) -> Void)?
    private(set) var recentEvents: [GestureEvent] = []

    private var trackpadRecognizers: [any GestureRecognizer]
    private var mouseRecognizers: [any GestureRecognizer]

    init(
        trackpadRecognizers: [any GestureRecognizer]? = nil,
        mouseRecognizers: [any GestureRecognizer]? = nil
    ) {
        let trackpadContext = TrackpadGestureContext()
        self.trackpadRecognizers = trackpadRecognizers ?? [
            TrackpadMoveResizeRecognizer(),
            TrackpadTabSwitchRecognizer(context: trackpadContext),
            TrackpadTapRecognizer(context: trackpadContext),
            TrackpadFixFingerRecognizer(),
            TrackpadSwipeRecognizer(),
            TrackpadPinchRecognizer(),
            TrackpadCharacterRecognizer(),
        ]
        self.mouseRecognizers = mouseRecognizers ?? [
            MagicMouseRecognizer(),
            PlaceholderGestureRecognizer(name: "CharacterRecognizer(magicMouse)"),
        ]
    }

    var recognizerCount: Int {
        trackpadRecognizers.count + mouseRecognizers.count
    }

    func handleTouchFrame(_ frame: TouchFrame) {
        let recognizers = frame.deviceType == .trackpad ? trackpadRecognizers : mouseRecognizers
        for recognizer in recognizers where recognizer.isEnabled {
            for event in recognizer.processFrame(frame) {
                append(event)
                onGestureEvent?(event)
            }
        }
    }

    func reset() {
        trackpadRecognizers.forEach { $0.reset() }
        mouseRecognizers.forEach { $0.reset() }
        recentEvents.removeAll()
    }

    func updateSettings(_ settings: JitouchSettings) {
        trackpadRecognizers.forEach { $0.updateSettings(settings) }
        mouseRecognizers.forEach { $0.updateSettings(settings) }
    }

    private func append(_ event: GestureEvent) {
        recentEvents.append(event)
        if recentEvents.count > 20 {
            recentEvents.removeFirst(recentEvents.count - 20)
        }
    }
}
