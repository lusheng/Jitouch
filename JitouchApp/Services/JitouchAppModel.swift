import Foundation
import Observation

@MainActor
@Observable
final class JitouchAppModel {
    private let settingsStore: LegacySettingsStore
    private let accessibilityPermissionService: AccessibilityPermissionService
    let deviceManager: DeviceManager
    let eventTapManager: EventTapManager
    let gestureEngine: GestureEngine
    let commandExecutor: CommandExecutor

    private(set) var settings: JitouchSettings
    private(set) var lastReloadDate: Date?
    private(set) var lastError: String?
    private(set) var legacyPreferencesFound: Bool
    private(set) var lastRecognizedGestureSummary = "No gestures recognized yet"

    init(
        settingsStore: LegacySettingsStore = LegacySettingsStore(),
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        deviceManager: DeviceManager = DeviceManager(),
        eventTapManager: EventTapManager = EventTapManager(),
        gestureEngine: GestureEngine = GestureEngine(),
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.settingsStore = settingsStore
        self.accessibilityPermissionService = accessibilityPermissionService
        self.deviceManager = deviceManager
        self.eventTapManager = eventTapManager
        self.gestureEngine = gestureEngine
        self.commandExecutor = commandExecutor
        self.settings = settingsStore.load()
        self.legacyPreferencesFound = settingsStore.preferencesFileExists

        commandExecutor.installEventTapHandler(on: eventTapManager)

        gestureEngine.onGestureEvent = { [weak self] event in
            guard let self else { return }
            self.lastRecognizedGestureSummary = event.debugName
            self.commandExecutor.execute(event: event, settings: self.settings)
            self.lastError = self.commandExecutor.lastError
        }

        gestureEngine.updateSettings(settings)
        startRuntimeServices()
    }

    var menuBarSymbolName: String {
        settings.isEnabled ? "hand.tap.fill" : "hand.tap"
    }

    var accessibilityGranted: Bool {
        accessibilityPermissionService.isTrusted(prompt: false)
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
        legacyPreferencesFound = settingsStore.preferencesFileExists
        lastReloadDate = .now
        lastError = nil
        gestureEngine.updateSettings(settings)
        deviceManager.refreshDevicesNow()
    }

    func requestAccessibilityPermission() {
        _ = accessibilityPermissionService.isTrusted(prompt: true)
        restartEventTap()
    }

    func setEnabled(_ isEnabled: Bool) {
        settings.isEnabled = isEnabled
        if !isEnabled {
            gestureEngine.reset()
            commandExecutor.cancelTransientState()
        }
        persist()
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

    func setCharacterRecognitionIndexRingDistance(_ distance: Double) {
        settings.characterRecognitionIndexRingDistance = distance
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
        deviceManager.stop()
        eventTapManager.stop()
    }

    private func persist() {
        do {
            try settingsStore.save(settings)
            legacyPreferencesFound = settingsStore.preferencesFileExists
            lastError = nil
            gestureEngine.updateSettings(settings)
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
}
