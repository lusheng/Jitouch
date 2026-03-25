import Foundation

enum CommandCatalog {
    static let supportedActionCommands: [String] = [
        "-",
        "Next Tab",
        "Previous Tab",
        "Open Link in New Tab",
        "Full Screen",
        "Open Recently Closed Tab",
        "Close / Close Tab",
        "Quit",
        "Hide",
        "Minimize",
        "Zoom",
        "Un-Maximize",
        "Maximize",
        "Maximize Left",
        "Maximize Right",
        "Copy",
        "Paste",
        "New",
        "New Tab",
        "Open",
        "Save",
        "Launch Finder",
        "Launch Browser",
        "Middle Click",
        "Left Click",
        "Right Click",
        "Move / Resize",
        "Show Desktop",
        "Application Windows",
        "Mission Control",
        "Launchpad",
        "Refresh",
        "Scroll to Top",
        "Scroll to Bottom",
        "Application Switcher",
        "Play / Pause",
        "Next",
        "Previous",
        "Volume Up",
        "Volume Down",
        "Brightness Up",
        "Brightness Down",
    ]

    static let allUnassignedGesture = "All Unassigned Gestures"

    static let trackpadGestureOptions: [String] = [
        "Three-Finger Tap",
        "Three-Swipe-Left",
        "Three-Swipe-Right",
        "Three-Swipe-Up",
        "Three-Swipe-Down",
        "Four-Finger Tap",
        "Four-Swipe-Left",
        "Four-Swipe-Right",
        "Four-Swipe-Up",
        "Four-Swipe-Down",
        "One-Fix Left-Tap",
        "One-Fix Right-Tap",
        "One-Fix One-Slide",
        "One-Fix Two-Slide-Up",
        "One-Fix Two-Slide-Down",
        "One-Fix-Press Two-Slide-Up",
        "One-Fix-Press Two-Slide-Down",
        "Two-Fix Index-Double-Tap",
        "Two-Fix Middle-Double-Tap",
        "Two-Fix Ring-Double-Tap",
        "Three-Finger Pinch-In",
        "Three-Finger Pinch-Out",
        "Pinky-To-Index",
        "Index-To-Pinky",
        allUnassignedGesture,
    ]

    static let magicMouseGestureOptions: [String] = [
        "Middle-Fix Index-Near-Tap",
        "Middle-Fix Index-Far-Tap",
        "Index-Fix Middle-Near-Tap",
        "Index-Fix Middle-Far-Tap",
        "Middle-Fix Index-Slide-Out",
        "Middle-Fix Index-Slide-In",
        "Index-Fix Middle-Slide-In",
        "Index-Fix Middle-Slide-Out",
        "Two-Fix One-Slide-Left",
        "Two-Fix One-Slide-Right",
        "Two-Fix One-Slide-Up",
        "Two-Fix One-Slide-Down",
        "Thumb",
        "Pinch In",
        "Pinch Out",
        "Three-Swipe-Left",
        "Three-Swipe-Right",
        "Three-Swipe-Up",
        "Three-Swipe-Down",
        "Middle Click",
        "V-Shape",
        allUnassignedGesture,
    ]

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
            launchAtLoginEnabled: false,
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

    static func editableGestures(for device: CommandDevice) -> [String] {
        switch device {
        case .trackpad:
            trackpadGestureOptions
        case .magicMouse:
            magicMouseGestureOptions
        case .recognition:
            CharacterRecognitionEngine.supportedCharacterValues
        }
    }
}
