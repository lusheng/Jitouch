import AppKit
import SwiftUI

struct SettingsRootView: View {
    @Environment(JitouchAppModel.self) private var appModel
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(EventTapManager.self) private var eventTapManager
    @Environment(CommandExecutor.self) private var commandExecutor

    @State private var selectedPane: JitouchSettingsPane? = .overview
    @State private var selectedTrackpadSetID = ""
    @State private var selectedMagicMouseSetID = ""
    @State private var selectedRecognitionSetID = ""
    @State private var trackpadGestureSearchText = ""
    @State private var magicMouseGestureSearchText = ""
    @State private var recognitionGestureSearchText = ""

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.isEnabled },
            set: { appModel.setEnabled($0) }
        )
    }

    private var launchAtLoginEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.launchAtLoginEnabled },
            set: { appModel.setLaunchAtLoginEnabled($0) }
        )
    }

    private var clickSpeedBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.clickSpeed },
            set: { appModel.setClickSpeed($0) }
        )
    }

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.sensitivity },
            set: { appModel.setSensitivity($0) }
        )
    }

    private var trackpadEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.trackpadEnabled },
            set: { appModel.setTrackpadEnabled($0) }
        )
    }

    private var magicMouseEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.magicMouseEnabled },
            set: { appModel.setMagicMouseEnabled($0) }
        )
    }

    private var trackpadCharacterRecognitionEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.trackpadCharacterRecognitionEnabled },
            set: { appModel.setTrackpadCharacterRecognitionEnabled($0) }
        )
    }

    private var twoFingerDrawingEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.twoFingerDrawingEnabled },
            set: { appModel.setTwoFingerDrawingEnabled($0) }
        )
    }

    private var oneFingerDrawingEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.oneFingerDrawingEnabled },
            set: { appModel.setOneFingerDrawingEnabled($0) }
        )
    }

    private var characterRecognitionDistanceBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.characterRecognitionIndexRingDistance },
            set: { appModel.setCharacterRecognitionIndexRingDistance($0) }
        )
    }

    private var magicMouseCharacterRecognitionEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.magicMouseCharacterRecognitionEnabled },
            set: { appModel.setMagicMouseCharacterRecognitionEnabled($0) }
        )
    }

    private var characterRecognitionMouseButtonBinding: Binding<Int> {
        Binding(
            get: { appModel.settings.characterRecognitionMouseButton },
            set: { appModel.setCharacterRecognitionMouseButton($0) }
        )
    }

    private var characterRecognitionDiagnosticsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.characterRecognitionDiagnosticsEnabled },
            set: { appModel.setCharacterRecognitionDiagnosticsEnabled($0) }
        )
    }

    private var characterRecognitionHintDelayBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.characterRecognitionHintDelay },
            set: { appModel.setCharacterRecognitionHintDelay($0) }
        )
    }

    private var trackpadCharacterMinimumTravelBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.trackpadCharacterMinimumTravel },
            set: { appModel.setTrackpadCharacterMinimumTravel($0) }
        )
    }

    private var trackpadCharacterValidationSegmentsBinding: Binding<Int> {
        Binding(
            get: { appModel.settings.trackpadCharacterValidationSegments },
            set: { appModel.setTrackpadCharacterValidationSegments($0) }
        )
    }

    private var magicMouseCharacterMinimumTravelBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.magicMouseCharacterMinimumTravel },
            set: { appModel.setMagicMouseCharacterMinimumTravel($0) }
        )
    }

    private var magicMouseCharacterActivationSegmentsBinding: Binding<Int> {
        Binding(
            get: { appModel.settings.magicMouseCharacterActivationSegments },
            set: { appModel.setMagicMouseCharacterActivationSegments($0) }
        )
    }

    private var onboardingPresentedBinding: Binding<Bool> {
        Binding(
            get: { appModel.isOnboardingPresented },
            set: { isPresented in
                if isPresented {
                    appModel.presentOnboarding()
                } else {
                    appModel.dismissOnboarding()
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(
                header: AnyView(sidebarHeader),
                footer: AnyView(sidebarFooter),
                selectedPane: $selectedPane
            )
                .frame(width: 320, alignment: .topLeading)

            Divider()
                .overlay(Color.black.opacity(0.06))

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 1280, minHeight: 760)
        .sheet(isPresented: onboardingPresentedBinding) {
            OnboardingFlowView()
                .environment(appModel)
        }
        .onAppear {
            appModel.maybePresentOnboarding()
            selectedPane = appModel.preferredSettingsPane
        }
        .onChange(of: appModel.preferredSettingsPane) { _, newValue in
            selectedPane = newValue
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPane ?? .overview {
        case .overview:
            OverviewSettingsTab(
                isEnabled: appModel.settings.isEnabled,
                menuBarSymbolName: appModel.menuBarSymbolName,
                isRuntimeReady: eventTapManager.isRunning,
                deviceCount: deviceManager.totalDeviceCount,
                focusedApplicationName: commandExecutor.activeApplicationDisplayName,
                hasCompletedOnboarding: appModel.settings.hasCompletedOnboarding,
                onboardingProgressSummary: appModel.onboardingProgressSummary,
                onboardingCoreRequirementsMet: appModel.onboardingCoreRequirementsMet,
                accessibilityGranted: appModel.accessibilityGranted,
                accessibilityStatusText: appModel.accessibilityStatusText,
                accessibilityGuidance: appModel.accessibilityGuidance,
                launchAtLoginStatus: appModel.launchAtLoginStatus,
                trackpadDeviceCount: deviceManager.trackpadDevices.count,
                magicMouseDeviceCount: deviceManager.magicMouseDevices.count,
                lastExecutedCommandSummary: commandExecutor.lastExecutedCommandSummary,
                lastRecognizedGestureSummary: appModel.lastRecognizedGestureSummary,
                lastReloadDate: appModel.lastReloadDate,
                trackpadCommandCount: appModel.trackpadCommandCount,
                magicMouseCommandCount: appModel.magicMouseCommandCount,
                recognitionCommandCount: appModel.recognitionCommandCount,
                trackpadCommands: appModel.settings.trackpadCommands,
                magicMouseCommands: appModel.settings.magicMouseCommands,
                recognitionCommands: appModel.settings.recognitionCommands,
                lastError: appModel.lastError,
                jitouchEnabled: enabledBinding,
                trackpadEnabled: trackpadEnabledBinding,
                magicMouseEnabled: magicMouseEnabledBinding,
                clickSpeed: clickSpeedBinding,
                sensitivity: sensitivityBinding,
                onOpenSetupGuide: appModel.presentOnboarding,
                onResetSetupStatus: {
                    appModel.resetOnboarding()
                    appModel.presentOnboarding()
                },
                onOpenAccessibilitySettings: appModel.openAccessibilitySystemSettings,
                onRefreshPreferences: appModel.refresh,
                onRestartRuntime: appModel.restartRuntimeServices
            )
        case .permissions:
            PermissionsSettingsTab(
                accessibilityGranted: appModel.accessibilityGranted,
                accessibilityStatusText: appModel.accessibilityStatusText,
                accessibilityGuidance: appModel.accessibilityGuidance,
                launchAtLoginStatus: appModel.launchAtLoginStatus,
                launchAtLoginEnabled: launchAtLoginEnabledBinding,
                onPromptForAccess: {
                    appModel.requestAccessibilityPermission()
                    appModel.refresh()
                },
                onOpenAccessibilitySettings: appModel.openAccessibilitySystemSettings,
                onOpenLoginItemsSettings: appModel.openLoginItemsSystemSettings
            )
        case .trackpad:
            deviceConfigurationPane(for: .trackpad)
        case .magicMouse:
            deviceConfigurationPane(for: .magicMouse)
        case .recognition:
            RecognitionSettingsTab(
                recognitionSummary: AnyView(recognitionSummaryCard),
                characterRecognitionSettings: AnyView(characterRecognitionSettings),
                profileSelection: AnyView(profileSelectionCard(for: .recognition)),
                gestureSearch: AnyView(gestureSearchCard(for: .recognition)),
                gestureEditor: AnyView(gestureEditorSection(for: .recognition))
            )
        case .diagnostics:
            DiagnosticsSettingsTab(
                eventTapStatusText: eventTapManager.statusText,
                eventTapIsRunning: eventTapManager.isRunning,
                observedEventCount: eventTapManager.observedEventCount,
                recoveryCount: eventTapManager.recoveryCount,
                lastObservedEventType: eventTapManager.lastObservedEventType.map(String.init(describing:)),
                totalDeviceCount: deviceManager.totalDeviceCount,
                trackpadDevices: deviceManager.trackpadDevices,
                magicMouseDevices: deviceManager.magicMouseDevices,
                lastRecognizedGestureSummary: appModel.lastRecognizedGestureSummary,
                lastExecutedCommandSummary: commandExecutor.lastExecutedCommandSummary,
                menuBarVisibilityNote: appModel.menuBarVisibilityNote,
                lastEventDescription: deviceManager.lastEventDescription
            ) {
                characterRecognitionCalibration
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.43, blue: 0.94),
                                    Color(red: 0.10, green: 0.73, blue: 0.66),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: appModel.menuBarSymbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jitouch Settings")
                        .font(.title3.weight(.semibold))
                    Text("Standalone gesture utility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            JitouchStatusBadge(
                title: appModel.settings.isEnabled ? "Active" : "Paused",
                tint: appModel.settings.isEnabled ? .green : .orange
            )

            Text("App-first controls for the Swift rewrite.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func deviceConfigurationPane(for device: CommandDevice) -> some View {
        let pane: JitouchSettingsPane = device == .trackpad ? .trackpad : .magicMouse

        return DeviceSettingsTab(
            title: pane.title,
            subtitle: pane.subtitle,
            summary: AnyView(deviceSummaryCard(for: device)),
            profileSelection: AnyView(profileSelectionCard(for: device)),
            overrideManager: AnyView(overrideManagerCard(for: device)),
            gestureSearch: AnyView(gestureSearchCard(for: device)),
            gestureEditor: AnyView(gestureEditorSection(for: device))
        )
    }

    private var characterRecognitionSettings: some View {
        JitouchSurfaceCard(
            title: "Character Recognition",
            subtitle: "Configure drawing-based input on trackpad and Magic Mouse, plus the shared thresholds that shape recognition stability.",
            symbol: "character.cursor.ibeam",
            tint: .purple
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Trackpad Character Recognition", isOn: trackpadCharacterRecognitionEnabledBinding)
                Toggle("Enable One-Finger Drawing", isOn: oneFingerDrawingEnabledBinding)
                    .disabled(!trackpadCharacterRecognitionEnabledBinding.wrappedValue)
                Toggle("Enable Two-Finger Drawing", isOn: twoFingerDrawingEnabledBinding)
                    .disabled(!trackpadCharacterRecognitionEnabledBinding.wrappedValue)
                Toggle("Enable Magic Mouse Character Recognition", isOn: magicMouseCharacterRecognitionEnabledBinding)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Index / Ring Distance")
                        Spacer()
                        Text(characterRecognitionDistanceBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: characterRecognitionDistanceBinding, in: 0.18 ... 0.50)
                }

                Picker("Mouse Recognition Button", selection: characterRecognitionMouseButtonBinding) {
                    Text("Middle Click").tag(0)
                    Text("Right Click").tag(1)
                }
                .pickerStyle(.segmented)
                .disabled(!magicMouseCharacterRecognitionEnabledBinding.wrappedValue)

                Text("Trackpad one-finger and two-finger drawing, plus Magic Mouse drag-to-character, are now wired up in Swift. Character overlay timing is much closer to the legacy build, but threshold calibration still needs real-device tuning.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var characterRecognitionCalibration: some View {
        SettingsCharacterRecognitionCalibrationCard(
            isDiagnosticsEnabled: characterRecognitionDiagnosticsEnabledBinding,
            hintDelay: characterRecognitionHintDelayBinding,
            trackpadMinimumTravel: trackpadCharacterMinimumTravelBinding,
            trackpadValidationSegments: trackpadCharacterValidationSegmentsBinding,
            magicMouseMinimumTravel: magicMouseCharacterMinimumTravelBinding,
            magicMouseActivationSegments: magicMouseCharacterActivationSegmentsBinding,
            diagnostics: appModel.characterRecognitionDiagnostics,
            onClearDiagnostics: appModel.clearCharacterRecognitionDiagnostics
        )
    }

    private var recognitionSummaryCard: some View {
        JitouchSurfaceCard(
            title: "Recognition Modes",
            subtitle: "Trackpad and Magic Mouse drawing now share the same Swift recognition core, with adjustable thresholds and profile-based command outputs.",
            symbol: "signature",
            tint: .purple
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                JitouchMetricTile(
                    title: "Trackpad Recognition",
                    value: trackpadCharacterRecognitionEnabledBinding.wrappedValue ? "Enabled" : "Disabled",
                    detail: oneFingerDrawingEnabledBinding.wrappedValue || twoFingerDrawingEnabledBinding.wrappedValue
                        ? "Drawing input is available on trackpad."
                        : "No trackpad drawing modes are active.",
                    symbol: "rectangle.and.pencil.and.ellipsis",
                    tint: trackpadCharacterRecognitionEnabledBinding.wrappedValue ? .green : .secondary
                )
                JitouchMetricTile(
                    title: "Magic Mouse Recognition",
                    value: magicMouseCharacterRecognitionEnabledBinding.wrappedValue ? "Enabled" : "Disabled",
                    detail: characterRecognitionMouseButtonBinding.wrappedValue == 0 ? "Triggered from middle click." : "Triggered from right click.",
                    symbol: "mouse",
                    tint: magicMouseCharacterRecognitionEnabledBinding.wrappedValue ? .blue : .secondary
                )
                JitouchMetricTile(
                    title: "Diagnostics",
                    value: characterRecognitionDiagnosticsEnabledBinding.wrappedValue ? "Live" : "Off",
                    detail: appModel.characterRecognitionDiagnostics.liveSnapshot == nil ? "No live snapshot yet." : "Receiving recognizer snapshots.",
                    symbol: "waveform.path.ecg",
                    tint: characterRecognitionDiagnosticsEnabledBinding.wrappedValue ? .pink : .secondary
                )
            }
        }
    }

    private func deviceSummaryCard(for device: CommandDevice) -> some View {
        let title = device == .trackpad ? "Trackpad Runtime" : "Magic Mouse Runtime"
        let subtitle = device == .trackpad
            ? "Trackpad tap, swipe, fix-finger, pinch, move/resize, tab switch, and drawing recognition now live in the standalone app."
            : "Magic Mouse taps, swipes, slides, thumb gestures, V-shape, pinch, and drag recognition now live in the standalone app."
        let symbol = device == .trackpad ? "rectangle.and.hand.point.up.left" : "mouse"
        let tint: Color = device == .trackpad ? .blue : .mint
        let isEnabledBinding = device == .trackpad ? trackpadEnabledBinding : magicMouseEnabledBinding
        let mappingCount = device == .trackpad ? appModel.trackpadCommandCount : appModel.magicMouseCommandCount
        let deviceCount = device == .trackpad ? deviceManager.trackpadDevices.count : deviceManager.magicMouseDevices.count

        return JitouchSurfaceCard(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            tint: tint
        ) {
            Toggle("Enable \(device.title) Profiles", isOn: isEnabledBinding)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                JitouchMetricTile(
                    title: "Mappings",
                    value: "\(mappingCount)",
                    detail: "Loaded from the legacy command store and editable in-place.",
                    symbol: "square.grid.2x2",
                    tint: tint
                )
                JitouchMetricTile(
                    title: "Connected Devices",
                    value: "\(deviceCount)",
                    detail: deviceCount == 0 ? "No matching device detected right now." : "Hardware is visible to the runtime.",
                    symbol: "dot.radiowaves.left.and.right",
                    tint: deviceCount == 0 ? .orange : .green
                )
            }
        }
    }

    private func profileSelectionCard(for device: CommandDevice) -> some View {
        let sets = appModel.commandSets(for: device)
        return SettingsProfileSelectionCard(
            device: device,
            sets: sets,
            selectedSet: selectedCommandSet(for: device),
            selectedSetID: selectedSetIDBinding(for: device),
            profileTitle: { set in
                set.path.isEmpty ? set.application : "\(set.application) Override"
            },
            profileDescription: { set in
                set.path.isEmpty
                    ? "Changes here apply when no app-specific override matches."
                    : set.path
            }
        )
    }

    private func overrideManagerCard(for device: CommandDevice) -> some View {
        let overrides = applicationOverrides(for: device)
        let sets = appModel.commandSets(for: device)

        return SettingsOverrideManagerCard(
            device: device,
            overrides: overrides,
            currentSelectedSetID: currentSelectedSetID(for: device),
            differenceCount: { set in
                overrideDifferenceCount(for: set, device: device)
            },
            onAddOverride: {
                let previousIDs = Set(sets.map(\.id))
                appModel.addApplicationOverrideFromOpenPanel(for: device)
                if let newID = appModel.commandSets(for: device)
                    .map(\.id)
                    .first(where: { !previousIDs.contains($0) }) {
                    setSelectedSetID(newID, for: device)
                }
            },
            onSelectOverride: { setID in
                setSelectedSetID(setID, for: device)
            },
            onResetOverride: { setID in
                appModel.resetApplicationOverrideToDefault(for: device, setID: setID)
            },
            onOpenApp: openOverrideApplication,
            onReveal: revealFilePath,
            onRemoveOverride: { setID in
                appModel.removeApplicationOverride(for: device, setID: setID)
            }
        )
    }

    private func gestureEditorSection(for device: CommandDevice) -> some View {
        let selectedSet = selectedCommandSet(for: device)

        return JitouchSurfaceCard(
            title: "Gesture Mappings",
            subtitle: "Enable only the gestures you care about, then assign actions, shortcuts, URLs, or file launches.",
            symbol: "wand.and.stars",
            tint: .indigo
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let selectedSet {
                    SettingsProfileEditingContextView(
                        device: device,
                        set: selectedSet,
                        enabledCount: selectedSet.gestures.filter(\.isEnabled).count,
                        overrideCount: applicationOverrides(for: device).count,
                        differenceCount: overrideDifferenceCount(for: selectedSet, device: device),
                        onBackToDefault: {
                            setSelectedSetID("All Applications", for: device)
                        },
                        onResetToDefault: {
                            appModel.resetApplicationOverrideToDefault(for: device, setID: selectedSet.id)
                        },
                        onOpenApp: {
                            openOverrideApplication(selectedSet.path)
                        },
                        onReveal: {
                            revealFilePath(selectedSet.path)
                        },
                        onRemoveOverride: {
                            appModel.removeApplicationOverride(for: device, setID: selectedSet.id)
                        }
                    )

                    let searchText = currentSearchText(for: device)
                    let activeGestures = activeGestureNames(for: device, setID: selectedSet.id)
                    let inactiveGestures = inactiveGestureNames(for: device, setID: selectedSet.id)
                    let isFiltering = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    if isFiltering {
                        Text("Showing \(activeGestures.count + inactiveGestures.count) matching gestures for “\(searchText)”")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if activeGestures.isEmpty && !isFiltering {
                        Text("No enabled mappings in this profile yet. Open the list below and turn on the gestures you want.")
                            .foregroundStyle(.secondary)
                    } else if !activeGestures.isEmpty {
                        Text(isFiltering ? "Matching Enabled Gestures" : "Enabled")
                            .font(.headline)

                        ForEach(activeGestures, id: \.self) { gesture in
                            gestureEditor(for: device, setID: selectedSet.id, gesture: gesture)
                        }
                    }

                    if !inactiveGestures.isEmpty && !isFiltering {
                        Divider()

                        DisclosureGroup("More Gestures (\(inactiveGestures.count))") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(inactiveGestures, id: \.self) { gesture in
                                    gestureEditor(for: device, setID: selectedSet.id, gesture: gesture)
                                }
                            }
                            .padding(.top, 10)
                        }
                    } else if !inactiveGestures.isEmpty {
                        Divider()

                        Text("Matching Disabled Gestures")
                            .font(.headline)

                        ForEach(inactiveGestures, id: \.self) { gesture in
                            gestureEditor(for: device, setID: selectedSet.id, gesture: gesture)
                        }
                    } else if activeGestures.isEmpty && isFiltering {
                        ContentUnavailableView(
                            "No Matching Gestures",
                            systemImage: "magnifyingglass",
                            description: Text("Try another search term or clear the filter.")
                        )
                    }
                } else {
                    Text("Pick a profile to start editing gesture bindings.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func gestureEditor(
        for device: CommandDevice,
        setID: String,
        gesture: String
    ) -> SettingsGestureEditorCard {
        SettingsGestureEditorCard(
            device: device,
            gesture: gesture,
            command: gestureCommandBinding(for: device, setID: setID, gesture: gesture),
            onRevealFilePath: revealFilePath
        )
    }

    private func gestureSearchCard(for device: CommandDevice) -> some View {
        SettingsGestureSearchCard(
            device: device,
            searchText: searchTextBinding(for: device)
        )
    }

    private func applicationOverrides(for device: CommandDevice) -> [ApplicationCommandSet] {
        appModel.commandSets(for: device)
            .filter { !$0.path.isEmpty }
            .sorted {
                $0.application.localizedCaseInsensitiveCompare($1.application) == .orderedAscending
            }
    }

    private func overrideDifferenceCount(
        for set: ApplicationCommandSet,
        device: CommandDevice
    ) -> Int {
        guard !set.path.isEmpty else { return 0 }
        let defaultSetID = defaultCommandSet(for: device)?.id ?? "All Applications"

        return CommandCatalog.editableGestures(for: device).reduce(into: 0) { count, gesture in
            let overrideCommand = appModel.gestureCommand(for: device, setID: set.id, gesture: gesture)
            let defaultCommand = appModel.gestureCommand(for: device, setID: defaultSetID, gesture: gesture)
            if overrideCommand != defaultCommand {
                count += 1
            }
        }
    }

    private func defaultCommandSet(for device: CommandDevice) -> ApplicationCommandSet? {
        appModel.commandSets(for: device).first(where: { $0.path.isEmpty })
    }

    private func selectedCommandSet(for device: CommandDevice) -> ApplicationCommandSet? {
        let sets = appModel.commandSets(for: device)
        guard !sets.isEmpty else { return nil }

        let selectedID = currentSelectedSetID(for: device)
        return sets.first(where: { $0.id == selectedID }) ?? sets.first
    }

    private func selectedSetIDBinding(for device: CommandDevice) -> Binding<String> {
        Binding(
            get: { selectedCommandSet(for: device)?.id ?? "" },
            set: { newValue in
                setSelectedSetID(newValue, for: device)
            }
        )
    }

    private func currentSelectedSetID(for device: CommandDevice) -> String {
        switch device {
        case .trackpad:
            selectedTrackpadSetID
        case .magicMouse:
            selectedMagicMouseSetID
        case .recognition:
            selectedRecognitionSetID
        }
    }

    private func setSelectedSetID(_ value: String, for device: CommandDevice) {
        switch device {
        case .trackpad:
            selectedTrackpadSetID = value
        case .magicMouse:
            selectedMagicMouseSetID = value
        case .recognition:
            selectedRecognitionSetID = value
        }
    }

    private func activeGestureNames(for device: CommandDevice, setID: String) -> [String] {
        CommandCatalog.editableGestures(for: device).filter {
            let command = appModel.gestureCommand(for: device, setID: setID, gesture: $0)
            return command.isEnabled && gestureMatchesSearch($0, command: command, device: device)
        }
    }

    private func inactiveGestureNames(for device: CommandDevice, setID: String) -> [String] {
        CommandCatalog.editableGestures(for: device).filter {
            let command = appModel.gestureCommand(for: device, setID: setID, gesture: $0)
            return !command.isEnabled && gestureMatchesSearch($0, command: command, device: device)
        }
    }

    private func gestureMatchesSearch(
        _ gesture: String,
        command: GestureCommand,
        device: CommandDevice
    ) -> Bool {
        let searchText = currentSearchText(for: device).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return true }

        let haystacks = [
            gesture,
            command.command,
            command.openURL ?? "",
            command.openFilePath ?? "",
        ]
        return haystacks.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func searchTextBinding(for device: CommandDevice) -> Binding<String> {
        Binding(
            get: { currentSearchText(for: device) },
            set: { setSearchText($0, for: device) }
        )
    }

    private func currentSearchText(for device: CommandDevice) -> String {
        switch device {
        case .trackpad:
            trackpadGestureSearchText
        case .magicMouse:
            magicMouseGestureSearchText
        case .recognition:
            recognitionGestureSearchText
        }
    }

    private func setSearchText(_ value: String, for device: CommandDevice) {
        switch device {
        case .trackpad:
            trackpadGestureSearchText = value
        case .magicMouse:
            magicMouseGestureSearchText = value
        case .recognition:
            recognitionGestureSearchText = value
        }
    }

    private func revealFilePath(_ path: String) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openOverrideApplication(_ path: String) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        NSWorkspace.shared.open(url)
    }

    private func gestureCommandBinding(
        for device: CommandDevice,
        setID: String,
        gesture: String
    ) -> Binding<GestureCommand> {
        Binding(
            get: {
                appModel.gestureCommand(for: device, setID: setID, gesture: gesture)
            },
            set: { updatedCommand in
                appModel.updateGestureCommand(updatedCommand, for: device, setID: setID)
            }
        )
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Runtime")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(appModel.runtimeStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
        )
    }
}
