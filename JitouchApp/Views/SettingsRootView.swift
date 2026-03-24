import SwiftUI

struct SettingsRootView: View {
    @Environment(JitouchAppModel.self) private var appModel
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(EventTapManager.self) private var eventTapManager
    @Environment(CommandExecutor.self) private var commandExecutor

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.isEnabled },
            set: { appModel.setEnabled($0) }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                runtimeStatus
                generalSettings
                characterRecognitionSettings
                characterRecognitionCalibration
                commandCoverage
                deviceDiagnostics
                compatibilityNotes

                if let lastError = appModel.lastError {
                    GroupBox("Last Error") {
                        Text(lastError)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 760, minHeight: 620)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: appModel.menuBarSymbolName)
                .font(.system(size: 28, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Jitouch Modernization Preview")
                    .font(.title2.weight(.semibold))

                Text("This standalone SwiftUI app shell reads the legacy preference domain and prepares the repo for the pure Swift gesture engine.")
                    .foregroundStyle(.secondary)

                if let lastReloadDate = appModel.lastReloadDate {
                    Text("Last reloaded \(lastReloadDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runtimeStatus: some View {
        GroupBox("Runtime Status") {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    Text("Legacy Preferences")
                        .foregroundStyle(.secondary)
                    Text(appModel.legacyPreferencesFound ? "Found" : "Not Found")
                }

                GridRow {
                    Text("Accessibility")
                        .foregroundStyle(.secondary)
                    Text(appModel.accessibilityGranted ? "Granted" : "Needs Permission")
                }

                GridRow {
                    Text("Bundle ID")
                        .foregroundStyle(.secondary)
                    Text("com.jitouch.Jitouch")
                }

                GridRow {
                    Text("Touch Devices")
                        .foregroundStyle(.secondary)
                    Text("\(deviceManager.totalDeviceCount)")
                }

                GridRow {
                    Text("Event Tap")
                        .foregroundStyle(.secondary)
                    Text(eventTapManager.statusText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var generalSettings: some View {
        GroupBox("General") {
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
                    Button("Request Accessibility Access") {
                        appModel.requestAccessibilityPermission()
                        appModel.refresh()
                    }

                    Button("Reload Preferences from Disk") {
                        appModel.refresh()
                    }

                    Button("Restart Runtime Services") {
                        appModel.restartRuntimeServices()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var commandCoverage: some View {
        GroupBox("Command Coverage") {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var characterRecognitionSettings: some View {
        GroupBox("Character Recognition") {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var compatibilityNotes: some View {
        GroupBox("Compatibility Notes") {
            VStack(alignment: .leading, spacing: 8) {
                Text(appModel.menuBarVisibilityNote)
                Text("The old preference pane's `ShowIcon` toggle is still preserved in storage, but it is not applied yet so the standalone app does not disappear.")
                Text("Trackpad one-finger/two-finger character recognition and Magic Mouse drag-to-character are now running in Swift. Remaining work is mostly gesture feel tuning, extra overlays, and device-by-device calibration.")
                Text("Latest touch frame: \(deviceManager.lastEventDescription)")
                Text("Last gesture event: \(appModel.lastRecognizedGestureSummary)")
                Text("Last executed command: \(commandExecutor.lastExecutedCommandSummary)")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var characterRecognitionCalibration: some View {
        GroupBox("Calibration & Diagnostics") {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var deviceDiagnostics: some View {
        GroupBox("Connected Devices") {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
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
}
