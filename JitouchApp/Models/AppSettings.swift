import Foundation

enum LogLevel: Int, CaseIterable, Identifiable, Sendable {
    case error = -1
    case defaultLevel = 0
    case info = 1
    case debug = 2
    case trace = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .error:
            "Error"
        case .defaultLevel:
            "Default"
        case .info:
            "Info"
        case .debug:
            "Debug"
        case .trace:
            "Trace"
        }
    }
}

enum Handedness: Int, CaseIterable, Identifiable, Sendable {
    case right = 0
    case left = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .right:
            "Right Handed"
        case .left:
            "Left Handed"
        }
    }
}

struct JitouchSettings: Sendable {
    var isEnabled: Bool
    var clickSpeed: Double
    var sensitivity: Double
    var showMenuBarIcon: Bool
    var logLevel: LogLevel

    var trackpadEnabled: Bool
    var trackpadHandedness: Handedness

    var magicMouseEnabled: Bool
    var magicMouseHandedness: Handedness

    var trackpadCharacterRecognitionEnabled: Bool
    var magicMouseCharacterRecognitionEnabled: Bool
    var characterRecognitionIndexRingDistance: Double
    var characterRecognitionMouseButton: Int
    var oneFingerDrawingEnabled: Bool
    var twoFingerDrawingEnabled: Bool
    var characterRecognitionDiagnosticsEnabled: Bool
    var characterRecognitionHintDelay: Double
    var trackpadCharacterMinimumTravel: Double
    var trackpadCharacterValidationSegments: Int
    var magicMouseCharacterMinimumTravel: Double
    var magicMouseCharacterActivationSegments: Int

    var commandSets: [CommandDevice: [ApplicationCommandSet]]

    var trackpadCommands: [ApplicationCommandSet] {
        get { commandSets[.trackpad, default: []] }
        set { commandSets[.trackpad] = newValue }
    }

    var magicMouseCommands: [ApplicationCommandSet] {
        get { commandSets[.magicMouse, default: []] }
        set { commandSets[.magicMouse] = newValue }
    }

    var recognitionCommands: [ApplicationCommandSet] {
        get { commandSets[.recognition, default: []] }
        set { commandSets[.recognition] = newValue }
    }

    func commandCount(for device: CommandDevice) -> Int {
        commandSets[device, default: []].reduce(into: 0) { result, app in
            result += app.gestures.count
        }
    }
}
