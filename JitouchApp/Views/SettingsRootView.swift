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

    private var characterRecognitionDistanceBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.characterRecognitionIndexRingDistance },
            set: { appModel.setCharacterRecognitionIndexRingDistance($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                runtimeStatus
                generalSettings
                characterRecognitionSettings
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
                Toggle("Enable Two-Finger Drawing", isOn: twoFingerDrawingEnabledBinding)
                    .disabled(!trackpadCharacterRecognitionEnabledBinding.wrappedValue)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Index / Ring Distance")
                        Spacer()
                        Text(characterRecognitionDistanceBinding.wrappedValue, format: .number.precision(.fractionLength(2)))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: characterRecognitionDistanceBinding, in: 0.18 ... 0.50)
                }

                Text("The current Swift migration supports two-finger trackpad drawing first. One-finger trackpad drawing and Magic Mouse character recognition are still pending.")
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
                Text("Trackpad two-finger character recognition is now running in Swift. One-finger trackpad drawing, Magic Mouse drawing, and overlay parity are still pending.")
                Text("Latest touch frame: \(deviceManager.lastEventDescription)")
                Text("Last gesture event: \(appModel.lastRecognizedGestureSummary)")
                Text("Last executed command: \(commandExecutor.lastExecutedCommandSummary)")
            }
            .foregroundStyle(.secondary)
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
}
