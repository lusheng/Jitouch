import Foundation

@MainActor
protocol GestureRecognizer: AnyObject {
    var isEnabled: Bool { get set }
    func processFrame(_ frame: TouchFrame) -> [GestureEvent]
    func reset()
    func updateSettings(_ settings: JitouchSettings)
}

@MainActor
final class PlaceholderGestureRecognizer: GestureRecognizer {
    let name: String
    var isEnabled: Bool

    init(name: String, isEnabled: Bool = true) {
        self.name = name
        self.isEnabled = isEnabled
    }

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        []
    }

    func reset() {}

    func updateSettings(_ settings: JitouchSettings) {}
}
