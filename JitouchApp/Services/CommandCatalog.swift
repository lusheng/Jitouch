import Foundation

enum CommandCatalog {
    static let trackpadDefaults: [ApplicationCommandSet] = [
        ApplicationCommandSet(
            application: "All Applications",
            gestures: [
                GestureCommand(gesture: "One-Fix Left-Tap", command: "Previous Tab"),
                GestureCommand(gesture: "One-Fix Right-Tap", command: "Next Tab"),
                GestureCommand(gesture: "One-Fix One-Slide", command: "Move / Resize"),
                GestureCommand(gesture: "One-Fix Two-Slide-Down", command: "Close / Close Tab"),
                GestureCommand(gesture: "One-Fix-Press Two-Slide-Down", command: "Quit"),
                GestureCommand(gesture: "Two-Fix Index-Double-Tap", command: "Refresh"),
                GestureCommand(gesture: "Three-Finger Tap", command: "Middle Click"),
                GestureCommand(gesture: "Pinky-To-Index", command: "Zoom"),
                GestureCommand(gesture: "Index-To-Pinky", command: "Minimize"),
            ]
        )
    ]

    static let magicMouseDefaults: [ApplicationCommandSet] = [
        ApplicationCommandSet(
            application: "All Applications",
            gestures: [
                GestureCommand(gesture: "Middle-Fix Index-Near-Tap", command: "Next Tab"),
                GestureCommand(gesture: "Middle-Fix Index-Far-Tap", command: "Previous Tab"),
                GestureCommand(gesture: "Middle-Fix Index-Slide-Out", command: "Close / Close Tab"),
                GestureCommand(gesture: "Middle-Fix Index-Slide-In", command: "Refresh"),
                GestureCommand(gesture: "Three-Swipe-Up", command: "Show Desktop"),
                GestureCommand(gesture: "Three-Swipe-Down", command: "Mission Control"),
                GestureCommand(gesture: "V-Shape", command: "Move / Resize"),
                GestureCommand(gesture: "Middle Click", command: "Middle Click"),
            ]
        )
    ]

    static let recognitionDefaults: [ApplicationCommandSet] = [
        ApplicationCommandSet(
            application: "All Applications",
            gestures: [
                GestureCommand(gesture: "B", command: "Launch Browser"),
                GestureCommand(gesture: "F", command: "Launch Finder"),
                GestureCommand(gesture: "N", command: "New"),
                GestureCommand(gesture: "O", command: "Open"),
                GestureCommand(gesture: "S", command: "Save"),
                GestureCommand(gesture: "T", command: "New Tab"),
                GestureCommand(gesture: "Up", command: "Copy"),
                GestureCommand(gesture: "Down", command: "Paste"),
                GestureCommand(gesture: "/ Up", command: "Maximize"),
                GestureCommand(gesture: "Left", command: "Maximize Left"),
                GestureCommand(gesture: "Right", command: "Maximize Right"),
                GestureCommand(gesture: "/ Down", command: "Un-Maximize"),
            ]
        )
    ]

    static var defaultSettings: JitouchSettings {
        JitouchSettings(
            isEnabled: true,
            clickSpeed: 0.25,
            sensitivity: 4.6666,
            showMenuBarIcon: true,
            logLevel: .defaultLevel,
            trackpadEnabled: true,
            trackpadHandedness: .right,
            magicMouseEnabled: true,
            magicMouseHandedness: .right,
            trackpadCharacterRecognitionEnabled: false,
            magicMouseCharacterRecognitionEnabled: false,
            characterRecognitionIndexRingDistance: 0.33,
            characterRecognitionMouseButton: 0,
            oneFingerDrawingEnabled: false,
            twoFingerDrawingEnabled: true,
            characterRecognitionDiagnosticsEnabled: true,
            characterRecognitionHintDelay: 0.30,
            trackpadCharacterMinimumTravel: 0.0002,
            trackpadCharacterValidationSegments: 5,
            magicMouseCharacterMinimumTravel: 5.0,
            magicMouseCharacterActivationSegments: 3,
            commandSets: [
                .trackpad: trackpadDefaults,
                .magicMouse: magicMouseDefaults,
                .recognition: recognitionDefaults,
            ]
        )
    }
}
