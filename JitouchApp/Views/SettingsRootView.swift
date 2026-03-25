import AppKit
import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case overview
    case permissions
    case trackpad
    case magicMouse
    case recognition
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .permissions:
            "Permissions & Startup"
        case .trackpad:
            "Trackpad"
        case .magicMouse:
            "Magic Mouse"
        case .recognition:
            "Character Recognition"
        case .diagnostics:
            "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            "Core status, controls, and migration progress."
        case .permissions:
            "Accessibility access, login items, and runtime readiness."
        case .trackpad:
            "Trackpad gesture profiles and per-app overrides."
        case .magicMouse:
            "Magic Mouse gesture profiles and per-app overrides."
        case .recognition:
            "Drawing recognition controls, mappings, and button behavior."
        case .diagnostics:
            "Calibration, device state, and debugging visibility."
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            "square.grid.2x2"
        case .permissions:
            "lock.shield"
        case .trackpad:
            "rectangle.and.hand.point.up.left"
        case .magicMouse:
            "mouse"
        case .recognition:
            "character.cursor.ibeam"
        case .diagnostics:
            "waveform.path.ecg"
        }
    }
}

struct SettingsRootView: View {
    @Environment(JitouchAppModel.self) private var appModel
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(EventTapManager.self) private var eventTapManager
    @Environment(CommandExecutor.self) private var commandExecutor

    @State private var selectedPane: SettingsPane? = .overview
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
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        .frame(minWidth: 1040, minHeight: 720)
        .sheet(isPresented: onboardingPresentedBinding) {
            OnboardingFlowView()
                .environment(appModel)
        }
        .onAppear {
            appModel.maybePresentOnboarding()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarHeader

            List(selection: $selectedPane) {
                ForEach(SettingsPane.allCases) { pane in
                    Label(pane.title, systemImage: pane.symbolName)
                        .tag(Optional(pane))
                }
            }
            .listStyle(.sidebar)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPane ?? .overview {
        case .overview:
            overviewPane
        case .permissions:
            permissionsPane
        case .trackpad:
            deviceConfigurationPane(for: .trackpad)
        case .magicMouse:
            deviceConfigurationPane(for: .magicMouse)
        case .recognition:
            recognitionPane
        case .diagnostics:
            diagnosticsPane
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
                    Text("Jitouch")
                        .font(.headline)
                    Text("Modernization Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Standalone Swift app for Tahoe-era macOS, with editable profiles and a pure Swift migration path.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var overviewPane: some View {
        settingsPage(
            title: SettingsPane.overview.title,
            subtitle: SettingsPane.overview.subtitle
        ) {
            overviewHero
            onboardingGuideCard
            overviewMetrics
            setupChecklist
            quickActionsCard
            generalSettings
            commandCoverage

            if let lastError = appModel.lastError {
                JitouchSurfaceCard(
                    title: "Last Error",
                    subtitle: "The most recent runtime or setup problem reported by the standalone app.",
                    symbol: "exclamationmark.octagon.fill",
                    tint: .red
                ) {
                    Text(lastError)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var permissionsPane: some View {
        settingsPage(
            title: SettingsPane.permissions.title,
            subtitle: SettingsPane.permissions.subtitle
        ) {
            permissionsAndStartup
        }
    }

    private var recognitionPane: some View {
        settingsPage(
            title: SettingsPane.recognition.title,
            subtitle: SettingsPane.recognition.subtitle
        ) {
            recognitionSummaryCard
            characterRecognitionSettings
            profileSelectionCard(for: .recognition)
            gestureSearchCard(for: .recognition)
            gestureEditorSection(for: .recognition)
        }
    }

    private var diagnosticsPane: some View {
        settingsPage(
            title: SettingsPane.diagnostics.title,
            subtitle: SettingsPane.diagnostics.subtitle
        ) {
            diagnosticsSummaryCard
            characterRecognitionCalibration
            deviceDiagnostics
            compatibilityNotes
        }
    }

    private func deviceConfigurationPane(for device: CommandDevice) -> some View {
        let pane: SettingsPane = device == .trackpad ? .trackpad : .magicMouse

        return settingsPage(
            title: pane.title,
            subtitle: pane.subtitle
        ) {
            deviceSummaryCard(for: device)
            profileSelectionCard(for: device)
            gestureSearchCard(for: device)
            gestureEditorSection(for: device)
        }
    }

    private func settingsPage<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                pageHeader(title: title, subtitle: subtitle)
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.semibold))

            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var overviewHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appModel.settings.isEnabled ? "Gesture Engine Ready" : "Jitouch Is Paused")
                        .font(.title2.weight(.semibold))

                    Text("The standalone app now owns device monitoring, event taps, command execution, editable profiles, and character diagnostics. What still needs real-world tuning is mostly feel, thresholds, and hardware-specific behavior.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(appModel.settings.isEnabled ? "Active" : "Paused")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            appModel.settings.isEnabled ? Color.green.opacity(0.16) : Color.orange.opacity(0.16),
                            in: Capsule()
                        )
                        .foregroundStyle(appModel.settings.isEnabled ? .green : .orange)

                    Text(appModel.runtimeStatusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1.00),
                    Color(red: 0.92, green: 0.99, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var onboardingGuideCard: some View {
        JitouchSurfaceCard(
            title: appModel.settings.hasCompletedOnboarding ? "Setup Guide" : "Finish Setup",
            subtitle: appModel.settings.hasCompletedOnboarding
                ? "The guided setup can be reopened any time if you want a quick sanity pass after more refactor work."
                : "A short guided setup now walks through permission, startup behavior, and device readiness instead of making you hunt across the whole settings UI.",
            symbol: "figure.walk.motion",
            tint: appModel.settings.hasCompletedOnboarding ? .blue : .green,
            accessory: {
                JitouchStatusBadge(
                    title: appModel.onboardingProgressSummary,
                    tint: appModel.onboardingCoreRequirementsMet ? .green : .orange
                )
            }
        ) {
            HStack(spacing: 12) {
                Button(appModel.settings.hasCompletedOnboarding ? "Replay Setup Guide" : "Open Setup Guide") {
                    appModel.presentOnboarding()
                }
                .buttonStyle(.borderedProminent)

                if appModel.settings.hasCompletedOnboarding {
                    Button("Reset Setup Status") {
                        appModel.resetOnboarding()
                        appModel.presentOnboarding()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var overviewMetrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            overviewMetricCard(
                title: "Accessibility",
                value: appModel.accessibilityStatusText,
                detail: appModel.accessibilityGuidance,
                symbol: appModel.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield",
                tint: appModel.accessibilityGranted ? .green : .orange
            )
            overviewMetricCard(
                title: "Launch at Login",
                value: appModel.launchAtLoginStatus.title,
                detail: appModel.launchAtLoginStatus.detail,
                symbol: "power.circle",
                tint: .blue
            )
            overviewMetricCard(
                title: "Touch Devices",
                value: "\(deviceManager.totalDeviceCount)",
                detail: "Trackpads: \(deviceManager.trackpadDevices.count)  Magic Mouse: \(deviceManager.magicMouseDevices.count)",
                symbol: "hand.tap",
                tint: .mint
            )
            overviewMetricCard(
                title: "Last Command",
                value: commandExecutor.lastExecutedCommandSummary,
                detail: appModel.lastRecognizedGestureSummary,
                symbol: "sparkles",
                tint: .purple
            )
        }
    }

    private func overviewMetricCard(
        title: String,
        value: String,
        detail: String,
        symbol: String,
        tint: Color
    ) -> some View {
        JitouchMetricTile(
            title: title,
            value: value,
            detail: detail,
            symbol: symbol,
            tint: tint
        )
    }

    private var setupChecklist: some View {
        JitouchSurfaceCard(
            title: "Setup Checklist",
            subtitle: "The refactor is far enough along to use like a real utility app. These are the remaining readiness checks before serious tuning.",
            symbol: "checklist",
            tint: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                checklistRow(
                    title: "Accessibility permission",
                    detail: appModel.accessibilityGranted
                        ? "Granted. Event taps and AX window control can run."
                        : "Still blocked. Jitouch cannot intercept input or move windows until macOS trust is granted.",
                    isComplete: appModel.accessibilityGranted,
                    actionTitle: appModel.accessibilityGranted ? nil : "Open Settings",
                    action: appModel.accessibilityGranted ? nil : {
                        appModel.openAccessibilitySystemSettings()
                    }
                )
                checklistRow(
                    title: "Event tap",
                    detail: eventTapManager.isRunning
                        ? "Running and ready to observe system input."
                        : "Stopped or unavailable. Restart runtime services after fixing permissions.",
                    isComplete: eventTapManager.isRunning,
                    actionTitle: eventTapManager.isRunning ? nil : "Restart Services",
                    action: eventTapManager.isRunning ? nil : {
                        appModel.restartRuntimeServices()
                    }
                )
                checklistRow(
                    title: "Touch devices",
                    detail: deviceManager.totalDeviceCount > 0
                        ? "\(deviceManager.totalDeviceCount) device(s) detected for gesture input."
                        : "No compatible device is currently visible to the runtime.",
                    isComplete: deviceManager.totalDeviceCount > 0
                )
                checklistRow(
                    title: "Imported mappings",
                    detail: (appModel.trackpadCommandCount + appModel.magicMouseCommandCount + appModel.recognitionCommandCount) > 0
                        ? "Legacy mappings are available to edit and execute."
                        : "No gesture bindings are loaded yet, so the app has nothing useful to run.",
                    isComplete: (appModel.trackpadCommandCount + appModel.magicMouseCommandCount + appModel.recognitionCommandCount) > 0
                )
            }
        }
    }

    private var quickActionsCard: some View {
        JitouchSurfaceCard(
            title: "Quick Actions",
            subtitle: "Useful maintenance and recovery actions that would otherwise send you hunting through multiple panels.",
            symbol: "bolt.circle",
            tint: .blue
        ) {
            HStack(spacing: 12) {
                Button("Reload Preferences") {
                    appModel.refresh()
                }
                .buttonStyle(.bordered)

                Button("Restart Runtime") {
                    appModel.restartRuntimeServices()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Accessibility") {
                    appModel.openAccessibilitySystemSettings()
                }
                .buttonStyle(.bordered)
            }

            if let lastReloadDate = appModel.lastReloadDate {
                Text("Last refreshed \(lastReloadDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var generalSettings: some View {
        JitouchSurfaceCard(
            title: "General Controls",
            subtitle: "Master switches and feel settings that affect the entire runtime.",
            symbol: "slider.horizontal.3",
            tint: .indigo
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Jitouch", isOn: enabledBinding)
                Toggle("Enable Trackpad Profiles", isOn: trackpadEnabledBinding)
                Toggle("Enable Magic Mouse Profiles", isOn: magicMouseEnabledBinding)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Click Speed")
                        Spacer()
                        Text(clickSpeedBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: clickSpeedBinding, in: 0.05 ... 0.60)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(sensitivityBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: sensitivityBinding, in: 1.0 ... 8.0)
                }

                HStack(spacing: 12) {
                    Button("Reload Preferences from Disk") {
                        appModel.refresh()
                    }

                    Button("Restart Runtime Services") {
                        appModel.restartRuntimeServices()
                    }
                }
            }
        }
    }

    private var permissionsAndStartup: some View {
        VStack(alignment: .leading, spacing: 18) {
            JitouchSurfaceCard(
                title: "Accessibility Permission",
                subtitle: "macOS must trust Jitouch before event taps, shortcuts, and AX window actions can work.",
                symbol: "lock.shield",
                tint: appModel.accessibilityGranted ? .green : .orange,
                accessory: {
                    JitouchStatusBadge(
                        title: appModel.accessibilityStatusText,
                        tint: appModel.accessibilityGranted ? .green : .orange
                    )
                }
            ) {
                Text(appModel.accessibilityGuidance)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Prompt for Access") {
                        appModel.requestAccessibilityPermission()
                        appModel.refresh()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Accessibility Settings") {
                        appModel.openAccessibilitySystemSettings()
                    }
                    .buttonStyle(.bordered)
                }

                if !appModel.accessibilityGranted {
                    Text("After macOS opens Privacy & Security, enable Jitouch in Accessibility and then come back here to restart services.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            JitouchSurfaceCard(
                title: "Launch at Login",
                subtitle: "Start the standalone app automatically after login using ServiceManagement.",
                symbol: "power.circle",
                tint: .teal,
                accessory: {
                    JitouchStatusBadge(
                        title: appModel.launchAtLoginStatus.title,
                        tint: appModel.launchAtLoginStatus.isEnabled ? .green : .secondary
                    )
                }
            ) {
                Toggle("Start Jitouch automatically after login", isOn: launchAtLoginEnabledBinding)

                Text(appModel.launchAtLoginStatus.detail)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Open Login Items Settings") {
                        appModel.openLoginItemsSystemSettings()
                    }
                    .buttonStyle(.bordered)

                    if appModel.launchAtLoginStatus.requiresApproval {
                        Text("Approval is still pending in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text("Debug builds can still report unavailable or approval-needed states because `SMAppService` behaves best with a properly signed app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var commandCoverage: some View {
        JitouchSurfaceCard(
            title: "Imported Coverage",
            subtitle: "A quick read on how much of the old preference domain has already been pulled into editable Swift models.",
            symbol: "square.grid.2x2",
            tint: .mint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                coverageRow(title: "Trackpad", count: appModel.trackpadCommandCount)
                coverageRow(title: "Magic Mouse", count: appModel.magicMouseCommandCount)
                coverageRow(title: "Character Recognition", count: appModel.recognitionCommandCount)

                Divider()

                Text("Imported legacy profiles")
                    .font(.headline)

                commandSample(for: .trackpad, sets: appModel.settings.trackpadCommands)
                commandSample(for: .magicMouse, sets: appModel.settings.magicMouseCommands)
                commandSample(for: .recognition, sets: appModel.settings.recognitionCommands)
            }
        }
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

    private var compatibilityNotes: some View {
        JitouchSurfaceCard(
            title: "Compatibility Notes",
            subtitle: "A few deliberate differences remain while the old preference pane becomes a real standalone app.",
            symbol: "info.circle",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                noteRow(appModel.menuBarVisibilityNote)
                noteRow("The old preference pane's `ShowIcon` toggle is still preserved in storage, but it is not applied yet so the standalone app does not disappear.")
                noteRow("Trackpad one-finger/two-finger character recognition and Magic Mouse drag-to-character are now running in Swift. Remaining work is mostly gesture feel tuning, extra overlays, and device-by-device calibration.")
                noteRow("Latest touch frame: \(deviceManager.lastEventDescription)")
                noteRow("Last gesture event: \(appModel.lastRecognizedGestureSummary)")
                noteRow("Last executed command: \(commandExecutor.lastExecutedCommandSummary)")
            }
        }
    }

    private var characterRecognitionCalibration: some View {
        JitouchSurfaceCard(
            title: "Calibration & Diagnostics",
            subtitle: "Tune thresholds and inspect recognizer output without needing the old debug-only tooling.",
            symbol: "waveform.path.ecg",
            tint: .pink
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Live Character Diagnostics", isOn: characterRecognitionDiagnosticsEnabledBinding)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hint Delay")
                        Spacer()
                        Text(characterRecognitionHintDelayBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: characterRecognitionHintDelayBinding, in: 0.10 ... 0.60)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Trackpad Min Travel")
                        Spacer()
                        Text(trackpadCharacterMinimumTravelBinding.wrappedValue, format: .number.precision(.fractionLength(5)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: trackpadCharacterMinimumTravelBinding, in: 0.00005 ... 0.0010)
                }

                Stepper(
                    "Trackpad Validation Segments: \(trackpadCharacterValidationSegmentsBinding.wrappedValue)",
                    value: trackpadCharacterValidationSegmentsBinding,
                    in: 2 ... 10
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Magic Mouse Min Travel")
                        Spacer()
                        Text(magicMouseCharacterMinimumTravelBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: magicMouseCharacterMinimumTravelBinding, in: 1.0 ... 15.0)
                }

                Stepper(
                    "Magic Mouse Activation Segments: \(magicMouseCharacterActivationSegmentsBinding.wrappedValue)",
                    value: magicMouseCharacterActivationSegmentsBinding,
                    in: 2 ... 8
                )

                HStack(spacing: 12) {
                    Button("Clear Diagnostics") {
                        appModel.clearCharacterRecognitionDiagnostics()
                    }

                    Text("These controls are stored in the same preference domain, so calibration survives restarts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let snapshot = appModel.characterRecognitionDiagnostics.liveSnapshot {
                    liveDiagnostics(snapshot)
                } else {
                    Text("No live character-recognition snapshot yet.")
                        .foregroundStyle(.secondary)
                }

                if !appModel.characterRecognitionDiagnostics.recentSnapshots.isEmpty {
                    Divider()
                    recentDiagnostics
                }
            }
        }
    }

    private var deviceDiagnostics: some View {
        JitouchSurfaceCard(
            title: "Connected Devices",
            subtitle: "Live device discovery and event-tap counters from the Swift runtime.",
            symbol: "cpu",
            tint: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                deviceSection(title: "Trackpads", devices: deviceManager.trackpadDevices)
                deviceSection(title: "Magic Mouse", devices: deviceManager.magicMouseDevices)

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("Observed Events")
                            .foregroundStyle(.secondary)
                        Text("\(eventTapManager.observedEventCount)")
                    }
                    GridRow {
                        Text("Tap Recoveries")
                            .foregroundStyle(.secondary)
                        Text("\(eventTapManager.recoveryCount)")
                    }
                    GridRow {
                        Text("Last Event Type")
                            .foregroundStyle(.secondary)
                        Text(eventTapManager.lastObservedEventType.map(String.init(describing:)) ?? "None")
                    }
                }
            }
        }
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

    private var diagnosticsSummaryCard: some View {
        JitouchSurfaceCard(
            title: "Runtime Diagnostics",
            subtitle: "A compact read on the observability tools now built into the Swift rewrite.",
            symbol: "stethoscope",
            tint: .pink
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                JitouchMetricTile(
                    title: "Event Tap",
                    value: eventTapManager.statusText,
                    detail: "\(eventTapManager.observedEventCount) observed / \(eventTapManager.recoveryCount) recoveries",
                    symbol: eventTapManager.isRunning ? "dot.radiowaves.left.and.right" : "slash.circle",
                    tint: eventTapManager.isRunning ? .green : .orange
                )
                JitouchMetricTile(
                    title: "Detected Devices",
                    value: "\(deviceManager.totalDeviceCount)",
                    detail: "Trackpads \(deviceManager.trackpadDevices.count), Magic Mouse \(deviceManager.magicMouseDevices.count)",
                    symbol: "cpu",
                    tint: .blue
                )
                JitouchMetricTile(
                    title: "Recent Gesture",
                    value: appModel.lastRecognizedGestureSummary,
                    detail: commandExecutor.lastExecutedCommandSummary,
                    symbol: "hand.tap",
                    tint: .indigo
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

    private func checklistRow(
        title: String,
        detail: String,
        isComplete: Bool,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(isComplete ? .green : .orange)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func noteRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    private func coverageRow(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }

    private func deviceSection(title: String, devices: [ConnectedDevice]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if devices.isEmpty {
                Text("No devices detected.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(devices) { device in
                    HStack {
                        Text(device.displayName)
                        Spacer()
                        Text("family \(device.familyID)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func profileSelectionCard(for device: CommandDevice) -> some View {
        let sets = appModel.commandSets(for: device)
        let selectedSet = selectedCommandSet(for: device)

        return JitouchSurfaceCard(
            title: device == .recognition ? "Recognition Profile" : "Profiles",
            subtitle: device == .recognition
                ? "Character mappings usually stay global, but they still use the same profile storage model."
                : "Choose the default profile or add app-specific overrides that take precedence when a matching app is frontmost.",
            symbol: device == .recognition ? "text.badge.star" : "square.on.square",
            tint: device == .recognition ? .purple : .blue,
            accessory: {
                JitouchStatusBadge(title: "\(sets.count) profile\(sets.count == 1 ? "" : "s")", tint: .secondary)
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if sets.isEmpty {
                    Text("No profiles available yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Editing Profile", selection: selectedSetIDBinding(for: device)) {
                        ForEach(sets) { set in
                            Text(profileTitle(for: set)).tag(set.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let selectedSet {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedSet.path.isEmpty ? "Default profile" : "App-specific override")
                                .font(.subheadline.weight(.semibold))

                            Text(profileDescription(for: selectedSet))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Choose App Override…") {
                            let previousIDs = Set(sets.map(\.id))
                            appModel.addApplicationOverrideFromOpenPanel(for: device)
                            if let newID = appModel.commandSets(for: device)
                                .map(\.id)
                                .first(where: { !previousIDs.contains($0) }) {
                                setSelectedSetID(newID, for: device)
                            }
                        }
                        .disabled(device == .recognition)

                        if let selectedSet, !selectedSet.path.isEmpty {
                            Button("Remove Override", role: .destructive) {
                                appModel.removeApplicationOverride(for: device, setID: selectedSet.id)
                            }
                        }
                    }

                    if device == .recognition {
                        Text("Character mappings reuse the same profile model, but usually stay global to keep recognition predictable.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
    ) -> some View {
        let commandBinding = gestureCommandBinding(for: device, setID: setID, gesture: gesture)
        let command = commandBinding.wrappedValue

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Toggle(gesture, isOn: gestureEnabledBinding(commandBinding))
                    .toggleStyle(.checkbox)

                Spacer()

                Picker("Type", selection: gestureCommandKindBinding(commandBinding)) {
                    ForEach(GestureCommandKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            switch command.commandKind {
            case .action:
                Picker("Action", selection: gestureActionBinding(commandBinding)) {
                    ForEach(CommandCatalog.supportedActionCommands, id: \.self) { action in
                        Text(action).tag(action)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            case .shortcut:
                VStack(alignment: .leading, spacing: 8) {
                    ShortcutRecorderField(
                        keyCode: gestureKeyCodeBinding(commandBinding),
                        modifierFlags: gestureModifierFlagsBinding(commandBinding)
                    )

                    Text("Click the field, then press the shortcut you want. Press Escape to cancel or Delete to clear it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .openURL:
                TextField(
                    "https://example.com",
                    text: gestureOpenURLBinding(commandBinding)
                )
                .textFieldStyle(.roundedBorder)
            case .openFile:
                TextField(
                    "/Applications/Safari.app",
                    text: gestureOpenFilePathBinding(commandBinding)
                )
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func commandSample(
        for device: CommandDevice,
        sets: [ApplicationCommandSet]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(device.title)
                .font(.subheadline.weight(.semibold))

            if let firstSet = sets.first {
                let preview = firstSet.gestures.prefix(3).map { "\($0.gesture) -> \($0.command)" }.joined(separator: " • ")
                Text(preview.isEmpty ? "No commands imported." : preview)
                    .foregroundStyle(.secondary)
            } else {
                Text("No commands imported.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func gestureSearchCard(for device: CommandDevice) -> some View {
        JitouchSurfaceCard(
            title: "Find a Gesture",
            subtitle: "Filter by gesture name or current command so you can jump straight to the binding you want.",
            symbol: "magnifyingglass",
            tint: .cyan
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    searchPlaceholder(for: device),
                    text: searchTextBinding(for: device)
                )
                .textFieldStyle(.roundedBorder)

                Text("Search matches gesture names and currently assigned commands, so you can jump straight to one mapping instead of scrolling through the whole profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func profileTitle(for set: ApplicationCommandSet) -> String {
        set.path.isEmpty ? set.application : "\(set.application) Override"
    }

    private func profileDescription(for set: ApplicationCommandSet) -> String {
        if set.path.isEmpty {
            return "Changes here apply when no app-specific override matches."
        }
        return set.path
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

    private func searchPlaceholder(for device: CommandDevice) -> String {
        switch device {
        case .trackpad:
            "Search trackpad gestures or commands"
        case .magicMouse:
            "Search Magic Mouse gestures or commands"
        case .recognition:
            "Search characters or recognition commands"
        }
    }

    private func liveDiagnostics(_ snapshot: CharacterRecognitionDiagnosticSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Snapshot")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Source")
                        .foregroundStyle(.secondary)
                    Text(snapshot.source.title)
                }
                GridRow {
                    Text("Phase")
                        .foregroundStyle(.secondary)
                    Text(snapshot.phase.title)
                }
                GridRow {
                    Text("Segments")
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.segmentCount)")
                }
                GridRow {
                    Text("Hint")
                        .foregroundStyle(.secondary)
                    Text(snapshot.hint ?? "None")
                }
                GridRow {
                    Text("Recognized")
                        .foregroundStyle(.secondary)
                    Text(snapshot.recognizedCharacter?.value ?? "Pending")
                }
                GridRow {
                    Text("Reason")
                        .foregroundStyle(.secondary)
                    Text(snapshot.reason ?? "None")
                }
                GridRow {
                    Text("Span")
                        .foregroundStyle(.secondary)
                    Text(spanDescription(snapshot))
                }
                GridRow {
                    Text("Updated")
                        .foregroundStyle(.secondary)
                    Text(snapshot.timestamp.formatted(date: .omitted, time: .standard))
                }
            }

            if !snapshot.candidates.isEmpty {
                Text("Top Candidates")
                    .font(.headline)

                Text(candidateLines(snapshot))
                    .font(.caption.monospaced())
            }
        }
    }

    private var recentDiagnostics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.headline)

            Text(recentSnapshotLines())
                .font(.caption.monospaced())
        }
    }

    private func spanDescription(_ snapshot: CharacterRecognitionDiagnosticSnapshot) -> String {
        guard let verticalSpan = snapshot.verticalSpan, let horizontalSpan = snapshot.horizontalSpan else {
            return "Not sampled"
        }

        return "\(verticalSpan.formatted(.number.precision(.fractionLength(3)))) x \(horizontalSpan.formatted(.number.precision(.fractionLength(3))))"
    }

    private func candidateLines(_ snapshot: CharacterRecognitionDiagnosticSnapshot) -> String {
        snapshot.candidates.map { candidate in
            let score = candidate.score.formatted(.number.precision(.fractionLength(2)))
            let progress = "\(candidate.matchedSegments)/\(candidate.totalSegments)"
            let completion = candidate.isComplete ? "complete" : "tracking"
            let geometry = candidate.isAcceptedByGeometry ? "accepted" : "geometry-filtered"
            return "\(candidate.value.padding(toLength: 8, withPad: " ", startingAt: 0)) score \(score)  segments \(progress)  \(completion)  \(geometry)"
        }
        .joined(separator: "\n")
    }

    private func recentSnapshotLines() -> String {
        appModel.characterRecognitionDiagnostics.recentSnapshots
            .prefix(5)
            .map { snapshot in
                let outcome = snapshot.recognizedCharacter?.value ?? snapshot.hint ?? "No Match"
                return "\(snapshot.timestamp.formatted(date: .omitted, time: .standard))  \(snapshot.source.title)  \(snapshot.phase.title)  \(outcome)"
            }
            .joined(separator: "\n")
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

    private func gestureEnabledBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<Bool> {
        Binding(
            get: { commandBinding.wrappedValue.isEnabled },
            set: { isEnabled in
                var command = commandBinding.wrappedValue
                command.isEnabled = isEnabled
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureCommandKindBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<GestureCommandKind> {
        Binding(
            get: { commandBinding.wrappedValue.commandKind },
            set: { kind in
                var command = commandBinding.wrappedValue
                switch kind {
                case .action:
                    command.isAction = true
                    command.command = CommandCatalog.supportedActionCommands.first(where: { $0 != "-" }) ?? "-"
                    command.openURL = nil
                    command.openFilePath = nil
                case .shortcut:
                    command.isAction = false
                    command.command = "Shortcut"
                    command.openURL = nil
                    command.openFilePath = nil
                case .openURL:
                    command.isAction = true
                    command.command = "Open URL"
                    command.openURL = command.openURL ?? ""
                    command.openFilePath = nil
                case .openFile:
                    command.isAction = true
                    command.command = "Open File"
                    command.openFilePath = command.openFilePath ?? ""
                    command.openURL = nil
                }
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureActionBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<String> {
        Binding(
            get: { commandBinding.wrappedValue.command },
            set: { action in
                var command = commandBinding.wrappedValue
                command.isAction = true
                command.command = action
                command.openURL = nil
                command.openFilePath = nil
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureKeyCodeBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<Int> {
        Binding(
            get: { commandBinding.wrappedValue.keyCode },
            set: { keyCode in
                var command = commandBinding.wrappedValue
                command.keyCode = max(0, keyCode)
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureModifierFlagsBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<Int> {
        Binding(
            get: { commandBinding.wrappedValue.modifierFlags },
            set: { modifierFlags in
                var command = commandBinding.wrappedValue
                command.modifierFlags = max(0, modifierFlags)
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureOpenURLBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<String> {
        Binding(
            get: { commandBinding.wrappedValue.openURL ?? "" },
            set: { url in
                var command = commandBinding.wrappedValue
                command.isAction = true
                command.command = "Open URL"
                command.openURL = url
                command.openFilePath = nil
                commandBinding.wrappedValue = command
            }
        )
    }

    private func gestureOpenFilePathBinding(_ commandBinding: Binding<GestureCommand>) -> Binding<String> {
        Binding(
            get: { commandBinding.wrappedValue.openFilePath ?? "" },
            set: { path in
                var command = commandBinding.wrappedValue
                command.isAction = true
                command.command = "Open File"
                command.openFilePath = path
                command.openURL = nil
                commandBinding.wrappedValue = command
            }
        )
    }
}
