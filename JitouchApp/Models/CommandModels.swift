import Foundation

enum CommandDevice: String, CaseIterable, Identifiable, Hashable, Sendable {
    case trackpad
    case magicMouse
    case recognition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trackpad:
            "Trackpad"
        case .magicMouse:
            "Magic Mouse"
        case .recognition:
            "Character Recognition"
        }
    }

    var legacyKey: String {
        switch self {
        case .trackpad:
            "TrackpadCommands"
        case .magicMouse:
            "MagicMouseCommands"
        case .recognition:
            "RecognitionCommands"
        }
    }
}

enum GestureCommandKind: String, CaseIterable, Identifiable, Sendable {
    case action
    case shortcut
    case openURL
    case openFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .action:
            "Action"
        case .shortcut:
            "Shortcut"
        case .openURL:
            "Open URL"
        case .openFile:
            "Open File"
        }
    }
}

struct GestureCommand: Identifiable, Hashable, Sendable {
    var id: String {
        "\(gesture)|\(command)|\(modifierFlags)|\(keyCode)|\(openFilePath ?? "")|\(openURL ?? "")"
    }

    var gesture: String
    var command: String
    var isAction: Bool
    var modifierFlags: Int
    var keyCode: Int
    var isEnabled: Bool
    var openFilePath: String?
    var openURL: String?

    init(
        gesture: String,
        command: String,
        isAction: Bool = true,
        modifierFlags: Int = 0,
        keyCode: Int = 0,
        isEnabled: Bool = true,
        openFilePath: String? = nil,
        openURL: String? = nil
    ) {
        self.gesture = gesture
        self.command = command
        self.isAction = isAction
        self.modifierFlags = modifierFlags
        self.keyCode = keyCode
        self.isEnabled = isEnabled
        self.openFilePath = openFilePath
        self.openURL = openURL
    }

    init?(legacyDictionary: [String: Any]) {
        guard
            let gesture = legacyDictionary["Gesture"] as? String,
            let command = legacyDictionary["Command"] as? String
        else {
            return nil
        }

        self.init(
            gesture: gesture,
            command: command,
            isAction: LegacyValue.bool(from: legacyDictionary["IsAction"], default: true),
            modifierFlags: LegacyValue.int(from: legacyDictionary["ModifierFlags"], default: 0),
            keyCode: LegacyValue.int(from: legacyDictionary["KeyCode"], default: 0),
            isEnabled: LegacyValue.bool(from: legacyDictionary["Enable"], default: true),
            openFilePath: legacyDictionary["OpenFilePath"] as? String,
            openURL: legacyDictionary["OpenURL"] as? String
        )
    }

    var legacyDictionary: [String: Any] {
        var dictionary: [String: Any] = [
            "Gesture": gesture,
            "Command": command,
            "IsAction": isAction,
            "ModifierFlags": modifierFlags,
            "KeyCode": keyCode,
            "Enable": isEnabled ? 1 : 0,
        ]

        if let openFilePath {
            dictionary["OpenFilePath"] = openFilePath
        }
        if let openURL {
            dictionary["OpenURL"] = openURL
        }

        return dictionary
    }

    var commandKind: GestureCommandKind {
        if !isAction {
            return .shortcut
        }
        if openURL != nil {
            return .openURL
        }
        if openFilePath != nil {
            return .openFile
        }
        return .action
    }
}

struct ApplicationCommandSet: Identifiable, Hashable, Sendable {
    var id: String {
        path.isEmpty ? application : path
    }

    var application: String
    var path: String
    var gestures: [GestureCommand]

    init(application: String, path: String = "", gestures: [GestureCommand]) {
        self.application = application
        self.path = path
        self.gestures = gestures
    }

    init?(legacyDictionary: [String: Any]) {
        guard let application = legacyDictionary["Application"] as? String else {
            return nil
        }

        let rawGestures = legacyDictionary["Gestures"] as? [[String: Any]] ?? []
        self.init(
            application: application,
            path: legacyDictionary["Path"] as? String ?? "",
            gestures: rawGestures.compactMap(GestureCommand.init(legacyDictionary:))
        )
    }

    var legacyDictionary: [String: Any] {
        [
            "Application": application,
            "Path": path,
            "Gestures": gestures.map(\.legacyDictionary),
        ]
    }
}

enum LegacyValue {
    static func int(from value: Any?, default defaultValue: Int) -> Int {
        switch value {
        case let int as Int:
            int
        case let number as NSNumber:
            number.intValue
        case let string as String:
            Int(string) ?? defaultValue
        default:
            defaultValue
        }
    }

    static func double(from value: Any?, default defaultValue: Double) -> Double {
        switch value {
        case let double as Double:
            double
        case let number as NSNumber:
            number.doubleValue
        case let string as String:
            Double(string) ?? defaultValue
        default:
            defaultValue
        }
    }

    static func bool(from value: Any?, default defaultValue: Bool) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.intValue != 0
        case let string as String:
            if let int = Int(string) {
                return int != 0
            }
            return defaultValue
        default:
            return defaultValue
        }
    }
}
