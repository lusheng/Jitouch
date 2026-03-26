import AppKit
import SwiftUI

struct SettingsRootView: View {
    private enum Layout {
        static let minimumSize = CGSize(width: 1440, height: 860)
    }

    private struct CommandEditingContext {
        let device: CommandDevice
        let commandSets: [ApplicationCommandSet]
        let defaultSetID: String
        let selectedSet: ApplicationCommandSet?
        let selectedSetID: String
        let profileItems: [SettingsProfileRuleItem]
        let overrideCount: Int
        let enabledGestureItems: [SettingsGestureRuleItem]
        let availableGestureItems: [SettingsGestureRuleItem]
        let selectedGestureItem: SettingsGestureRuleItem?
        let addableGestures: [String]
    }

    @Environment(JitouchAppModel.self) private var appModel
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(EventTapManager.self) private var eventTapManager
    @Environment(CommandExecutor.self) private var commandExecutor

    @State private var selectedPane: JitouchSettingsPane? = .overview
    @State private var selectedTrackpadSetID = ""
    @State private var selectedMagicMouseSetID = ""
    @State private var selectedRecognitionSetID = ""
    @State private var selectedTrackpadGesture = ""
    @State private var selectedMagicMouseGesture = ""
    @State private var selectedRecognitionGesture = ""
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
                selectedPane: $selectedPane
            ) {
                sidebarHeader
            } footer: {
                sidebarFooter
            }
                .frame(width: 320, alignment: .topLeading)

            Divider()
                .overlay(Color.black.opacity(0.06))

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: Layout.minimumSize.width, minHeight: Layout.minimumSize.height)
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
            let context = commandEditingContext(for: .recognition)

            RecognitionSettingsTab(
                trackpadCharacterRecognitionEnabled: trackpadCharacterRecognitionEnabledBinding,
                oneFingerDrawingEnabled: oneFingerDrawingEnabledBinding,
                twoFingerDrawingEnabled: twoFingerDrawingEnabledBinding,
                magicMouseCharacterRecognitionEnabled: magicMouseCharacterRecognitionEnabledBinding,
                characterRecognitionDistance: characterRecognitionDistanceBinding,
                characterRecognitionMouseButton: characterRecognitionMouseButtonBinding,
                hasLiveDiagnosticsSnapshot: appModel.characterRecognitionDiagnostics.liveSnapshot != nil,
                characterRecognitionDiagnosticsEnabled: characterRecognitionDiagnosticsEnabledBinding
            ) {
                ruleWorkspaceSection(context)
            }
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
        let context = commandEditingContext(for: device)
        let pane: JitouchSettingsPane = device == .trackpad ? .trackpad : .magicMouse
        let mappingCount = device == .trackpad ? appModel.trackpadCommandCount : appModel.magicMouseCommandCount
        let connectedDeviceCount = device == .trackpad ? deviceManager.trackpadDevices.count : deviceManager.magicMouseDevices.count
        let isProfilesEnabled = device == .trackpad ? trackpadEnabledBinding : magicMouseEnabledBinding

        return DeviceSettingsTab(
            device: device,
            title: pane.title,
            subtitle: pane.subtitle,
            mappingCount: mappingCount,
            connectedDeviceCount: connectedDeviceCount,
            isProfilesEnabled: isProfilesEnabled
        ) {
            ruleWorkspaceSection(context)
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

    private func ruleWorkspaceSection(_ context: CommandEditingContext) -> some View {
        SettingsRuleWorkspace(
            title: context.device == .recognition ? "Character Mapping Workspace" : "Rule Workspace",
            subtitle: context.device == .recognition
                ? "Select a character mapping on the left, then use the inspector on the right to restore the classic add/remove workflow with a modern editor."
                : "Select an app profile on the left, a gesture rule in the middle, then tune the selected mapping in the inspector on the right.",
            symbol: context.device == .recognition ? "signature" : "slider.horizontal.below.rectangle",
            tint: workspaceTint(for: context.device),
            showsProfileRules: context.device != .recognition,
            profileItems: context.profileItems,
            selectedProfileID: context.selectedSetID,
            onSelectProfile: { selectedSetIDStorage(for: context.device).wrappedValue = $0 },
            onAddProfile: context.device == .recognition ? nil : {
                let previousIDs = Set(context.commandSets.map(\.id))
                appModel.addApplicationOverrideFromOpenPanel(for: context.device)
                if let newID = appModel.commandSets(for: context.device)
                    .map(\.id)
                    .first(where: { !previousIDs.contains($0) }) {
                    selectedSetIDStorage(for: context.device).wrappedValue = newID
                }
            },
            onRemoveProfile: context.device == .recognition ? nil : {
                removeSelectedOverride(from: context)
            },
            searchText: searchTextBinding(for: context.device),
            searchPlaceholder: searchPlaceholder(for: context.device),
            enabledGestureItems: context.enabledGestureItems,
            availableGestureItems: context.availableGestureItems,
            selectedGestureItem: context.selectedGestureItem,
            onSelectGesture: { selectedGestureStorage(for: context.device).wrappedValue = $0 },
            addGestureOptions: context.addableGestures,
            onAddGesture: { gesture in
                let setID = context.selectedSet?.id ?? context.defaultSetID
                appModel.addGestureRule(
                    for: context.device,
                    setID: setID,
                    gesture: gesture,
                    defaultSetID: context.defaultSetID
                )
                selectedGestureStorage(for: context.device).wrappedValue = gesture
            },
            onRemoveGesture: {
                removeSelectedGestureRule(from: context)
            }
        ) {
            gestureInspectorContent(context)
        }
    }

    private func commandEditingContext(for device: CommandDevice) -> CommandEditingContext {
        let commandSets = appModel.commandSets(for: device)
        let defaultSetID = commandSets.first(where: { $0.path.isEmpty })?.id ?? "All Applications"
        let rawSelectedSetID = selectedSetIDStorage(for: device).wrappedValue
        let selectedSet = commandSets.first(where: { $0.id == rawSelectedSetID }) ?? commandSets.first
        let selectedSetID = selectedSet?.id ?? ""
        let searchText = searchTextBinding(for: device).wrappedValue
        let profileItems = profileItems(for: device, commandSets: commandSets, defaultSetID: defaultSetID)
        let allGestureItems = selectedSet.map {
            gestureRuleItems(for: device, selectedSet: $0, defaultSetID: defaultSetID)
        } ?? []
        let filteredGestureItems = allGestureItems.filter {
            gestureRuleMatchesSearch($0, searchText: searchText)
        }
        let enabledGestureItems = filteredGestureItems.filter { $0.state == .enabled }
        let availableGestureItems = filteredGestureItems.filter { $0.state != .enabled }
        let rawSelectedGesture = selectedGestureStorage(for: device).wrappedValue
        let selectedGestureItem = filteredGestureItems.first(where: { $0.gesture == rawSelectedGesture })
            ?? enabledGestureItems.first
            ?? availableGestureItems.first
        let addableGestures = allGestureItems.filter(\.canAdd).map(\.gesture)

        return CommandEditingContext(
            device: device,
            commandSets: commandSets,
            defaultSetID: defaultSetID,
            selectedSet: selectedSet,
            selectedSetID: selectedSetID,
            profileItems: profileItems,
            overrideCount: profileItems.filter { !$0.set.path.isEmpty }.count,
            enabledGestureItems: enabledGestureItems,
            availableGestureItems: availableGestureItems,
            selectedGestureItem: selectedGestureItem,
            addableGestures: addableGestures
        )
    }

    private func overrideDifferenceCount(
        for set: ApplicationCommandSet,
        defaultSetID: String,
        device: CommandDevice
    ) -> Int {
        guard !set.path.isEmpty else { return 0 }

        return CommandCatalog.editableGestures(for: device).reduce(into: 0) { count, gesture in
            let overrideCommand = appModel.gestureCommand(for: device, setID: set.id, gesture: gesture)
            let defaultCommand = appModel.gestureCommand(for: device, setID: defaultSetID, gesture: gesture)
            if overrideCommand != defaultCommand {
                count += 1
            }
        }
    }

    private func selectedSetIDStorage(for device: CommandDevice) -> Binding<String> {
        switch device {
        case .trackpad:
            $selectedTrackpadSetID
        case .magicMouse:
            $selectedMagicMouseSetID
        case .recognition:
            $selectedRecognitionSetID
        }
    }

    private func selectedGestureStorage(for device: CommandDevice) -> Binding<String> {
        switch device {
        case .trackpad:
            $selectedTrackpadGesture
        case .magicMouse:
            $selectedMagicMouseGesture
        case .recognition:
            $selectedRecognitionGesture
        }
    }

    private func profileItems(
        for device: CommandDevice,
        commandSets: [ApplicationCommandSet],
        defaultSetID: String
    ) -> [SettingsProfileRuleItem] {
        let defaultItem = commandSets.first(where: { $0.id == defaultSetID }).map {
            SettingsProfileRuleItem(set: $0, differenceCount: 0)
        }

        let overrideItems = commandSets
            .filter { !$0.path.isEmpty }
            .sorted {
                $0.application.localizedCaseInsensitiveCompare($1.application) == .orderedAscending
            }
            .map {
                SettingsProfileRuleItem(
                    set: $0,
                    differenceCount: overrideDifferenceCount(
                        for: $0,
                        defaultSetID: defaultSetID,
                        device: device
                    )
                )
            }

        return (defaultItem.map { [$0] } ?? []) + overrideItems
    }

    private func gestureRuleItems(
        for device: CommandDevice,
        selectedSet: ApplicationCommandSet,
        defaultSetID: String
    ) -> [SettingsGestureRuleItem] {
        CommandCatalog.editableGestures(for: device).map { gesture in
            let currentCommand = appModel.gestureCommand(for: device, setID: selectedSet.id, gesture: gesture)
            let hasStoredRule = gestureRuleExists(currentCommand)
            let inheritedCommand: GestureCommand?

            if
                selectedSet.id != defaultSetID,
                !currentCommand.isEnabled,
                !hasStoredRule
            {
                let defaultCommand = appModel.gestureCommand(for: device, setID: defaultSetID, gesture: gesture)
                inheritedCommand = defaultCommand.isEnabled ? defaultCommand : nil
            } else {
                inheritedCommand = nil
            }

            let state: SettingsGestureRuleState
            if currentCommand.isEnabled {
                state = .enabled
            } else if inheritedCommand != nil {
                state = .inherited
            } else {
                state = .disabled
            }

            return SettingsGestureRuleItem(
                gesture: gesture,
                state: state,
                currentCommand: currentCommand,
                displayCommand: inheritedCommand ?? currentCommand,
                canAdd: !currentCommand.isEnabled,
                canRemove: hasStoredRule
            )
        }
    }

    private func gestureRuleExists(_ command: GestureCommand) -> Bool {
        command.isEnabled || gestureCommandHasPayload(command)
    }

    private func gestureCommandHasPayload(_ command: GestureCommand) -> Bool {
        switch command.commandKind {
        case .action:
            command.command != "-"
        case .shortcut:
            command.keyCode != 0 || command.modifierFlags != 0
        case .openURL:
            !(command.openURL?.isEmpty ?? true)
        case .openFile:
            !(command.openFilePath?.isEmpty ?? true)
        }
    }

    private func gestureRuleMatchesSearch(
        _ item: SettingsGestureRuleItem,
        searchText: String
    ) -> Bool {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSearchText.isEmpty else { return true }

        let haystacks = [
            item.gesture,
            item.currentCommand.command,
            item.currentCommand.openURL ?? "",
            item.currentCommand.openFilePath ?? "",
            item.displayCommand.command,
            item.displayCommand.openURL ?? "",
            item.displayCommand.openFilePath ?? "",
            settingsGestureCommandSummary(item.displayCommand),
        ]

        return haystacks.contains { $0.localizedCaseInsensitiveContains(normalizedSearchText) }
    }

    @ViewBuilder
    private func gestureInspectorContent(_ context: CommandEditingContext) -> some View {
        if let selectedSet = context.selectedSet {
            let differenceCount = overrideDifferenceCount(
                for: selectedSet,
                defaultSetID: context.defaultSetID,
                device: context.device
            )

            VStack(alignment: .leading, spacing: 14) {
                SettingsProfileEditingContextView(
                    device: context.device,
                    set: selectedSet,
                    enabledCount: selectedSet.gestures.filter(\.isEnabled).count,
                    overrideCount: context.overrideCount,
                    differenceCount: differenceCount,
                    onBackToDefault: {
                        selectedSetIDStorage(for: context.device).wrappedValue = context.defaultSetID
                    },
                    onResetToDefault: {
                        appModel.resetApplicationOverrideToDefault(for: context.device, setID: selectedSet.id)
                    },
                    onOpenApp: {
                        openOverrideApplication(selectedSet.path)
                    },
                    onReveal: {
                        revealFilePath(selectedSet.path)
                    },
                    onRemoveOverride: {
                        appModel.removeApplicationOverride(for: context.device, setID: selectedSet.id)
                        selectedSetIDStorage(for: context.device).wrappedValue = context.defaultSetID
                    }
                )

                if let selectedGestureItem = context.selectedGestureItem {
                    gestureInspectorNote(for: selectedGestureItem)

                    SettingsGestureEditorCard(
                        device: context.device,
                        gesture: selectedGestureItem.gesture,
                        command: gestureCommandBinding(for: context, gesture: selectedGestureItem.gesture),
                        onRevealFilePath: revealFilePath
                    )
                } else {
                    SettingsEmptyStateView(
                        title: "Select a Rule",
                        systemImage: "cursorarrow.motionlines",
                        description: "Choose a gesture or character rule from the middle column to edit its action."
                    )
                }
            }
        } else {
            SettingsEmptyStateView(
                title: "No Profile Loaded",
                systemImage: "square.on.square.dashed",
                description: "Reload legacy preferences or create a profile to begin editing rules."
            )
        }
    }

    @ViewBuilder
    private func gestureInspectorNote(for item: SettingsGestureRuleItem) -> some View {
        switch item.state {
        case .enabled:
            EmptyView()
        case .inherited:
            SettingsFootnoteText(
                text: "This rule currently inherits \(settingsGestureCommandSummary(item.displayCommand)) from All Applications. Use + to clone it into the current profile, or edit below to replace it."
            )
        case .disabled:
            SettingsFootnoteText(
                text: item.canRemove
                    ? "This rule is stored but disabled. Re-enable it below or press - to clear it completely."
                    : "This gesture is not active in the current profile yet. Use + to add it, or enable and edit it below."
            )
        }
    }

    private func removeSelectedOverride(from context: CommandEditingContext) {
        guard
            let selectedSet = context.selectedSet,
            !selectedSet.path.isEmpty
        else {
            return
        }

        appModel.removeApplicationOverride(for: context.device, setID: selectedSet.id)
        selectedSetIDStorage(for: context.device).wrappedValue = context.defaultSetID
    }

    private func removeSelectedGestureRule(from context: CommandEditingContext) {
        guard let selectedGestureItem = context.selectedGestureItem else {
            return
        }

        let setID = context.selectedSet?.id ?? context.defaultSetID
        appModel.removeGestureRule(
            for: context.device,
            setID: setID,
            gesture: selectedGestureItem.gesture,
            defaultSetID: context.defaultSetID
        )
        selectedGestureStorage(for: context.device).wrappedValue = selectedGestureItem.gesture
    }

    private func searchPlaceholder(for device: CommandDevice) -> String {
        switch device {
        case .trackpad:
            "Search trackpad rules or commands"
        case .magicMouse:
            "Search Magic Mouse rules or commands"
        case .recognition:
            "Search characters or recognition commands"
        }
    }

    private func workspaceTint(for device: CommandDevice) -> Color {
        switch device {
        case .trackpad:
            .blue
        case .magicMouse:
            .mint
        case .recognition:
            .purple
        }
    }

    private func searchTextBinding(for device: CommandDevice) -> Binding<String> {
        switch device {
        case .trackpad:
            $trackpadGestureSearchText
        case .magicMouse:
            $magicMouseGestureSearchText
        case .recognition:
            $recognitionGestureSearchText
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
        for context: CommandEditingContext,
        gesture: String
    ) -> Binding<GestureCommand> {
        let setID = context.selectedSet?.id ?? context.defaultSetID

        return Binding(
            get: {
                appModel.gestureCommand(for: context.device, setID: setID, gesture: gesture)
            },
            set: { updatedCommand in
                appModel.updateGestureCommand(updatedCommand, for: context.device, setID: setID)
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
