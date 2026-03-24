import Foundation

struct LegacySettingsStore {
    let domainIdentifier = "com.jitouch.Jitouch"

    var preferencesURL: URL {
        URL(
            fileURLWithPath: NSString(
                string: "~/Library/Preferences/\(domainIdentifier).plist"
            ).expandingTildeInPath
        )
    }

    var preferencesFileExists: Bool {
        FileManager.default.fileExists(atPath: preferencesURL.path)
    }

    func load() -> JitouchSettings {
        let defaults = CommandCatalog.defaultSettings
        guard let rawDomain = loadRawDomain() else {
            return defaults
        }

        var settings = defaults
        settings.isEnabled = LegacyValue.bool(from: rawDomain["enAll"], default: defaults.isEnabled)
        settings.clickSpeed = LegacyValue.double(from: rawDomain["ClickSpeed"], default: defaults.clickSpeed)
        settings.sensitivity = LegacyValue.double(from: rawDomain["Sensitivity"], default: defaults.sensitivity)
        settings.showMenuBarIcon = LegacyValue.bool(from: rawDomain["ShowIcon"], default: defaults.showMenuBarIcon)
        settings.logLevel = LogLevel(rawValue: LegacyValue.int(from: rawDomain["LogLevel"], default: defaults.logLevel.rawValue)) ?? defaults.logLevel

        settings.trackpadEnabled = LegacyValue.bool(from: rawDomain["enTPAll"], default: defaults.trackpadEnabled)
        settings.trackpadHandedness = Handedness(rawValue: LegacyValue.int(from: rawDomain["Handed"], default: defaults.trackpadHandedness.rawValue)) ?? defaults.trackpadHandedness

        settings.magicMouseEnabled = LegacyValue.bool(from: rawDomain["enMMAll"], default: defaults.magicMouseEnabled)
        settings.magicMouseHandedness = Handedness(rawValue: LegacyValue.int(from: rawDomain["MMHanded"], default: defaults.magicMouseHandedness.rawValue)) ?? defaults.magicMouseHandedness

        settings.trackpadCharacterRecognitionEnabled = LegacyValue.bool(from: rawDomain["enCharRegTP"], default: defaults.trackpadCharacterRecognitionEnabled)
        settings.magicMouseCharacterRecognitionEnabled = LegacyValue.bool(from: rawDomain["enCharRegMM"], default: defaults.magicMouseCharacterRecognitionEnabled)
        settings.characterRecognitionIndexRingDistance = LegacyValue.double(
            from: rawDomain["charRegIndexRingDistance"],
            default: defaults.characterRecognitionIndexRingDistance
        )
        settings.characterRecognitionMouseButton = LegacyValue.int(
            from: rawDomain["charRegMouseButton"],
            default: defaults.characterRecognitionMouseButton
        )
        settings.oneFingerDrawingEnabled = LegacyValue.bool(from: rawDomain["enOneDrawing"], default: defaults.oneFingerDrawingEnabled)
        settings.twoFingerDrawingEnabled = LegacyValue.bool(from: rawDomain["enTwoDrawing"], default: defaults.twoFingerDrawingEnabled)

        settings.trackpadCommands = commandSets(
            for: .trackpad,
            rawDomain: rawDomain,
            defaultValue: defaults.trackpadCommands
        )
        settings.magicMouseCommands = commandSets(
            for: .magicMouse,
            rawDomain: rawDomain,
            defaultValue: defaults.magicMouseCommands
        )
        settings.recognitionCommands = commandSets(
            for: .recognition,
            rawDomain: rawDomain,
            defaultValue: defaults.recognitionCommands
        )
        return settings
    }

    func save(_ settings: JitouchSettings) throws {
        var domain = loadRawDomain() ?? [:]
        domain["enAll"] = settings.isEnabled ? 1 : 0
        domain["ClickSpeed"] = settings.clickSpeed
        domain["Sensitivity"] = settings.sensitivity
        domain["ShowIcon"] = settings.showMenuBarIcon ? 1 : 0
        domain["LogLevel"] = settings.logLevel.rawValue

        domain["enTPAll"] = settings.trackpadEnabled ? 1 : 0
        domain["Handed"] = settings.trackpadHandedness.rawValue

        domain["enMMAll"] = settings.magicMouseEnabled ? 1 : 0
        domain["MMHanded"] = settings.magicMouseHandedness.rawValue

        domain["enCharRegTP"] = settings.trackpadCharacterRecognitionEnabled ? 1 : 0
        domain["enCharRegMM"] = settings.magicMouseCharacterRecognitionEnabled ? 1 : 0
        domain["charRegIndexRingDistance"] = settings.characterRecognitionIndexRingDistance
        domain["charRegMouseButton"] = settings.characterRecognitionMouseButton
        domain["enOneDrawing"] = settings.oneFingerDrawingEnabled ? 1 : 0
        domain["enTwoDrawing"] = settings.twoFingerDrawingEnabled ? 1 : 0

        domain[CommandDevice.trackpad.legacyKey] = settings.trackpadCommands.map(\.legacyDictionary)
        domain[CommandDevice.magicMouse.legacyKey] = settings.magicMouseCommands.map(\.legacyDictionary)
        domain[CommandDevice.recognition.legacyKey] = settings.recognitionCommands.map(\.legacyDictionary)

        let data = try PropertyListSerialization.data(
            fromPropertyList: domain,
            format: .xml,
            options: 0
        )
        let directory = preferencesURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: preferencesURL, options: .atomic)
    }

    private func loadRawDomain() -> [String: Any]? {
        guard let data = try? Data(contentsOf: preferencesURL) else {
            return nil
        }

        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [.mutableContainersAndLeaves],
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }

        return plist
    }

    private func commandSets(
        for device: CommandDevice,
        rawDomain: [String: Any],
        defaultValue: [ApplicationCommandSet]
    ) -> [ApplicationCommandSet] {
        guard let rawCommands = rawDomain[device.legacyKey] as? [[String: Any]] else {
            return defaultValue
        }

        return rawCommands.compactMap(ApplicationCommandSet.init(legacyDictionary:))
    }
}
