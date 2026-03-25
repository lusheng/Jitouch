import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class JitouchAppModel {
    private let settingsStore: LegacySettingsStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let launchAtLoginService: LaunchAtLoginService
    let deviceManager: DeviceManager
    let eventTapManager: EventTapManager
    let gestureEngine: GestureEngine
    let commandExecutor: CommandExecutor
    let magicMouseCharacterRecognitionService: MagicMouseCharacterRecognitionService
    let characterRecognitionDiagnostics: CharacterRecognitionDiagnosticsStore

    private(set) var settings: JitouchSettings
    private(set) var launchAtLoginStatus: LaunchAtLoginStatusSnapshot
    private(set) var lastReloadDate: Date?
    private(set) var lastError: String?
    private(set) var legacyPreferencesFound: Bool
    private(set) var lastRecognizedGestureSummary = "No gestures recognized yet"

    init(
        settingsStore: LegacySettingsStore = LegacySettingsStore(),
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
        characterRecognitionDiagnostics: CharacterRecognitionDiagnosticsStore = CharacterRecognitionDiagnosticsStore(),
        deviceManager: DeviceManager = DeviceManager(),
        eventTapManager: EventTapManager = EventTapManager(),
        gestureEngine: GestureEngine? = nil,
        commandExecutor: CommandExecutor = CommandExecutor(),
        magicMouseCharacterRecognitionService: MagicMouseCharacterRecognitionService? = nil
    ) {
        self.settingsStore = settingsStore
        self.accessibilityPermissionService = accessibilityPermissionService
        self.launchAtLoginService = launchAtLoginService
        self.characterRecognitionDiagnostics = characterRecognitionDiagnostics
        self.deviceManager = deviceManager
        self.eventTapManager = eventTapManager
        self.gestureEngine = gestureEngine ?? GestureEngine(characterRecognitionDiagnostics: characterRecognitionDiagnostics)
        self.commandExecutor = commandExecutor
        self.magicMouseCharacterRecognitionService = magicMouseCharacterRecognitionService ?? MagicMouseCharacterRecognitionService(
            diagnostics: characterRecognitionDiagnostics
        )
        var initialSettings = settingsStore.load()
        let launchAtLoginStatus = launchAtLoginService.status()
        initialSettings.launchAtLoginEnabled = launchAtLoginStatus.isEnabled
        self.settings = initialSettings
        self.launchAtLoginStatus = launchAtLoginStatus
        self.legacyPreferencesFound = settingsStore.preferencesFileExists

        commandExecutor.installEventTapHandler(on: eventTapManager)
        self.magicMouseCharacterRecognitionService.installEventTapHandler(on: eventTapManager)
        self.magicMouseCharacterRecognitionService.onRecognizedCharacter = { [weak self] character in
            self?.gestureEngine.publish(.characterRecognized(character))
        }

        self.gestureEngine.onGestureEvent = { [weak self] event in
            guard let self else { return }
            self.lastRecognizedGestureSummary = event.debugName
            self.commandExecutor.execute(event: event, settings: self.settings)
            self.lastError = self.commandExecutor.lastError
        }

        self.gestureEngine.updateSettings(settings)
        self.magicMouseCharacterRecognitionService.updateSettings(settings)
        characterRecognitionDiagnostics.configure(from: settings)
        startRuntimeServices()
    }

    var menuBarSymbolName: String {
        settings.isEnabled ? "hand.tap.fill" : "hand.tap"
    }

    var accessibilityGranted: Bool {
        accessibilityPermissionService.isTrusted(prompt: false)
    }

    var accessibilityStatusText: String {
        accessibilityGranted ? "Granted" : "Needs Permission"
    }

    var accessibilityGuidance: String {
        accessibilityGranted
            ? "Accessibility permission is active, so event taps and AX window commands can run."
            : "Grant Accessibility access so Jitouch can observe input and control windows."
    }

    var trackpadCommandCount: Int {
        settings.commandCount(for: .trackpad)
    }

    var magicMouseCommandCount: Int {
        settings.commandCount(for: .magicMouse)
    }

    var recognitionCommandCount: Int {
        settings.commandCount(for: .recognition)
    }

    var menuBarVisibilityNote: String {
        "Standalone app mode keeps the menu bar icon visible until another launch surface is ready."
    }

    var runtimeStatusSummary: String {
        let deviceCount = deviceManager.totalDeviceCount
        let tapStatus = eventTapManager.isRunning ? "event tap active" : "event tap inactive"
        return "\(deviceCount) touch devices, \(tapStatus)"
    }

    func refresh() {
        settings = settingsStore.load()
        launchAtLoginStatus = launchAtLoginService.status()
        settings.launchAtLoginEnabled = launchAtLoginStatus.isEnabled
        legacyPreferencesFound = settingsStore.preferencesFileExists
        lastReloadDate = .now
        lastError = nil
        gestureEngine.updateSettings(settings)
        magicMouseCharacterRecognitionService.updateSettings(settings)
        characterRecognitionDiagnostics.configure(from: settings)
        deviceManager.refreshDevicesNow()
    }

    func requestAccessibilityPermission() {
        _ = accessibilityPermissionService.isTrusted(prompt: true)
        restartEventTap()
    }

    func openAccessibilitySystemSettings() {
        accessibilityPermissionService.openSystemSettings()
    }

    func openLoginItemsSystemSettings() {
        launchAtLoginService.openSystemSettings()
    }

    func setEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled
        if !isEnabled {
            gestureEngine.reset()
            commandExecutor.cancelTransientState()
            magicMouseCharacterRecognitionService.reset()
        }
        persist()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            launchAtLoginStatus = try launchAtLoginService.setEnabled(isEnabled)
            settings.launchAtLoginEnabled = launchAtLoginStatus.isEnabled
            persist()
        } catch {
            launchAtLoginStatus = launchAtLoginService.status()
            settings.launchAtLoginEnabled = launchAtLoginStatus.isEnabled
            lastError = "Failed to update launch at login: \(error.localizedDescription)"
        }
    }

    func setClickSpeed(_ clickSpeed: Double) {
        settings.clickSpeed = clickSpeed
        gestureEngine.updateSettings(settings)
        persist()
    }

    func setSensitivity(_ sensitivity: Double) {
        settings.sensitivity = sensitivity
        gestureEngine.updateSettings(settings)
        persist()
    }

    func setTrackpadEnabled(_ isEnabled: Bool) {
        settings.trackpadEnabled = isEnabled
        persist()
    }

    func setMagicMouseEnabled(_ isEnabled: Bool) {
        settings.magicMouseEnabled = isEnabled
        persist()
    }

    func setTrackpadCharacterRecognitionEnabled(_ isEnabled: Bool) {
        settings.trackpadCharacterRecognitionEnabled = isEnabled
        persist()
    }

    func setTwoFingerDrawingEnabled(_ isEnabled: Bool) {
        settings.twoFingerDrawingEnabled = isEnabled
        persist()
    }

    func setOneFingerDrawingEnabled(_ isEnabled: Bool) {
        settings.oneFingerDrawingEnabled = isEnabled
        persist()
    }

    func setCharacterRecognitionIndexRingDistance(_ distance: Double) {
        settings.characterRecognitionIndexRingDistance = distance
        persist()
    }

    func setMagicMouseCharacterRecognitionEnabled(_ isEnabled: Bool) {
        settings.magicMouseCharacterRecognitionEnabled = isEnabled
        persist()
    }

    func setCharacterRecognitionMouseButton(_ button: Int) {
        settings.characterRecognitionMouseButton = button
        persist()
    }

    func setCharacterRecognitionDiagnosticsEnabled(_ isEnabled: Bool) {
        settings.characterRecognitionDiagnosticsEnabled = isEnabled
        persist()
    }

    func setCharacterRecognitionHintDelay(_ delay: Double) {
        settings.characterRecognitionHintDelay = delay
        persist()
    }

    func setTrackpadCharacterMinimumTravel(_ value: Double) {
        settings.trackpadCharacterMinimumTravel = value
        persist()
    }

    func setTrackpadCharacterValidationSegments(_ value: Int) {
        settings.trackpadCharacterValidationSegments = value
        persist()
    }

    func setMagicMouseCharacterMinimumTravel(_ value: Double) {
        settings.magicMouseCharacterMinimumTravel = value
        persist()
    }

    func setMagicMouseCharacterActivationSegments(_ value: Int) {
        settings.magicMouseCharacterActivationSegments = value
        persist()
    }

    func clearCharacterRecognitionDiagnostics() {
        characterRecognitionDiagnostics.clear()
    }

    func commandSets(for device: CommandDevice) -> [ApplicationCommandSet] {
        settings.commandSets[device, default: []]
    }

    func gestureCommand(
        for device: CommandDevice,
        setID: String,
        gesture: String
    ) -> GestureCommand {
        commandSets(for: device)
            .first(where: { $0.id == setID })?
            .gestures
            .first(where: { $0.gesture == gesture }) ??
        GestureCommand(
            gesture: gesture,
            command: "-",
            isAction: true,
            modifierFlags: 0,
            keyCode: 0,
            isEnabled: false
        )
    }

    func updateGestureCommand(
        _ command: GestureCommand,
        for device: CommandDevice,
        setID: String
    ) {
        mutateCommandSet(for: device, setID: setID) { set in
            set.gestures.removeAll { $0.gesture == command.gesture }

            if let storedCommand = storedGestureCommand(from: command) {
                set.gestures.append(storedCommand)
                let order = CommandCatalog.editableGestures(for: device)
                set.gestures.sort { lhs, rhs in
                    let lhsIndex = order.firstIndex(of: lhs.gesture) ?? Int.max
                    let rhsIndex = order.firstIndex(of: rhs.gesture) ?? Int.max
                    if lhsIndex == rhsIndex {
                        return lhs.gesture < rhs.gesture
                    }
                    return lhsIndex < rhsIndex
                }
            }
        }
        persist()
    }

    func addApplicationOverrideFromOpenPanel(for device: CommandDevice) {
        let panel = NSOpenPanel()
        panel.title = "Choose an app override"
        panel.prompt = "Add Override"
        panel.message = "Jitouch will create an app-specific gesture profile that starts from the current All Applications bindings."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        addApplicationOverride(
            for: device,
            application: applicationName(for: url),
            path: url.standardizedFileURL.path
        )
    }

    func removeApplicationOverride(for device: CommandDevice, setID: String) {
        guard setID != "All Applications" else { return }

        var sets = commandSets(for: device)
        sets.removeAll { $0.id == setID }
        settings.commandSets[device] = sets
        persist()
    }

    func restartRuntimeServices() {
        deviceManager.restart()
        restartEventTap()
    }

    func restartEventTap() {
        do {
            try eventTapManager.start()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopRuntimeServices() {
        commandExecutor.cancelTransientState()
        magicMouseCharacterRecognitionService.reset()
        deviceManager.stop()
        eventTapManager.stop()
    }

    private func persist() {
        do {
            settings.launchAtLoginEnabled = launchAtLoginStatus.isEnabled
            try settingsStore.save(settings)
            legacyPreferencesFound = settingsStore.preferencesFileExists
            lastError = nil
            gestureEngine.updateSettings(settings)
            magicMouseCharacterRecognitionService.updateSettings(settings)
            characterRecognitionDiagnostics.configure(from: settings)
        } catch {
            lastError = "Failed to save settings: \(error.localizedDescription)"
        }
    }

    private func startRuntimeServices() {
        deviceManager.start(
            trackpadHandler: { [weak self] frame in
                self?.handleTouchFrame(frame)
            },
            mouseHandler: { [weak self] frame in
                self?.handleTouchFrame(frame)
            }
        )
        restartEventTap()
    }

    private func handleTouchFrame(_ frame: TouchFrame) {
        guard settings.isEnabled else { return }
        gestureEngine.handleTouchFrame(frame)
    }

    private func mutateCommandSet(
        for device: CommandDevice,
        setID: String,
        update: (inout ApplicationCommandSet) -> Void
    ) {
        var sets = commandSets(for: device)
        guard let index = sets.firstIndex(where: { $0.id == setID }) else { return }
        update(&sets[index])
        settings.commandSets[device] = sets
    }

    private func addApplicationOverride(
        for device: CommandDevice,
        application: String,
        path: String
    ) {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path

        if commandSets(for: device).contains(where: {
            !$0.path.isEmpty && URL(fileURLWithPath: $0.path).standardizedFileURL.path == normalizedPath
        }) {
            lastError = "An override already exists for \(application)."
            return
        }

        let seedGestures = commandSets(for: device)
            .first(where: { $0.application == "All Applications" })?
            .gestures ?? []

        var sets = commandSets(for: device)
        sets.append(
            ApplicationCommandSet(
                application: application,
                path: normalizedPath,
                gestures: seedGestures
            )
        )
        settings.commandSets[device] = sets
        persist()
    }

    private func applicationName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func storedGestureCommand(from command: GestureCommand) -> GestureCommand? {
        var normalized = command

        switch normalized.commandKind {
        case .action:
            normalized.isAction = true
            normalized.openFilePath = nil
            normalized.openURL = nil
            normalized.command = normalized.command.isEmpty ? "-" : normalized.command
        case .shortcut:
            normalized.isAction = false
            normalized.openFilePath = nil
            normalized.openURL = nil
            normalized.command = normalized.command.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.command.isEmpty || normalized.command == "-" {
                normalized.command = "Shortcut"
            }
        case .openURL:
            normalized.isAction = true
            normalized.openFilePath = nil
            normalized.openURL = normalized.openURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.command = "Open URL"
        case .openFile:
            normalized.isAction = true
            normalized.openURL = nil
            normalized.openFilePath = normalized.openFilePath?.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.command = "Open File"
        }

        let hasPayload: Bool
        switch normalized.commandKind {
        case .action:
            hasPayload = normalized.command != "-"
        case .shortcut:
            hasPayload = normalized.keyCode != 0 || normalized.modifierFlags != 0
        case .openURL:
            hasPayload = !(normalized.openURL?.isEmpty ?? true)
        case .openFile:
            hasPayload = !(normalized.openFilePath?.isEmpty ?? true)
        }

        if !normalized.isEnabled && !hasPayload {
            return nil
        }

        return normalized
    }
}
