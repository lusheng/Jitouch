import SwiftUI

struct DiagnosticsSettingsTab<CalibrationContent: View>: View {
    let eventTapStatusText: String
    let eventTapIsRunning: Bool
    let observedEventCount: Int
    let recoveryCount: Int
    let lastObservedEventType: String?
    let totalDeviceCount: Int
    let trackpadDevices: [ConnectedDevice]
    let magicMouseDevices: [ConnectedDevice]
    let lastRecognizedGestureSummary: String
    let lastExecutedCommandSummary: String
    let menuBarVisibilityNote: String
    let lastEventDescription: String
    let calibration: CalibrationContent

    init(
        eventTapStatusText: String,
        eventTapIsRunning: Bool,
        observedEventCount: Int,
        recoveryCount: Int,
        lastObservedEventType: String?,
        totalDeviceCount: Int,
        trackpadDevices: [ConnectedDevice],
        magicMouseDevices: [ConnectedDevice],
        lastRecognizedGestureSummary: String,
        lastExecutedCommandSummary: String,
        menuBarVisibilityNote: String,
        lastEventDescription: String,
        @ViewBuilder calibration: () -> CalibrationContent
    ) {
        self.eventTapStatusText = eventTapStatusText
        self.eventTapIsRunning = eventTapIsRunning
        self.observedEventCount = observedEventCount
        self.recoveryCount = recoveryCount
        self.lastObservedEventType = lastObservedEventType
        self.totalDeviceCount = totalDeviceCount
        self.trackpadDevices = trackpadDevices
        self.magicMouseDevices = magicMouseDevices
        self.lastRecognizedGestureSummary = lastRecognizedGestureSummary
        self.lastExecutedCommandSummary = lastExecutedCommandSummary
        self.menuBarVisibilityNote = menuBarVisibilityNote
        self.lastEventDescription = lastEventDescription
        self.calibration = calibration()
    }

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.diagnostics.title,
            subtitle: JitouchSettingsPane.diagnostics.subtitle
        ) {
            diagnosticsSummaryCard
            calibration
            connectedDevicesCard
            compatibilityNotesCard
        }
    }

    private var diagnosticsSummaryCard: some View {
        JitouchSurfaceCard(
            title: "Runtime Diagnostics",
            subtitle: "A compact read on the observability tools now built into the Swift rewrite.",
            symbol: "stethoscope",
            tint: .pink
        ) {
            SettingsMetricsGrid {
                JitouchMetricTile(
                    title: "Event Tap",
                    value: eventTapStatusText,
                    detail: "\(observedEventCount) observed / \(recoveryCount) recoveries",
                    symbol: eventTapIsRunning ? "dot.radiowaves.left.and.right" : "slash.circle",
                    tint: eventTapIsRunning ? .green : .orange
                )
                JitouchMetricTile(
                    title: "Detected Devices",
                    value: "\(totalDeviceCount)",
                    detail: "Trackpads \(trackpadDevices.count), Magic Mouse \(magicMouseDevices.count)",
                    symbol: "cpu",
                    tint: .blue
                )
                JitouchMetricTile(
                    title: "Recent Gesture",
                    value: lastRecognizedGestureSummary,
                    detail: lastExecutedCommandSummary,
                    symbol: "hand.tap",
                    tint: .indigo
                )
            }
        }
    }

    private var connectedDevicesCard: some View {
        JitouchSurfaceCard(
            title: "Connected Devices",
            subtitle: "Live device discovery and event-tap counters from the Swift runtime.",
            symbol: "cpu",
            tint: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DiagnosticsDeviceSection(title: "Trackpads", devices: trackpadDevices)
                DiagnosticsDeviceSection(title: "Magic Mouse", devices: magicMouseDevices)

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        Text("Observed Events")
                            .foregroundStyle(.secondary)
                        Text("\(observedEventCount)")
                    }
                    GridRow {
                        Text("Tap Recoveries")
                            .foregroundStyle(.secondary)
                        Text("\(recoveryCount)")
                    }
                    GridRow {
                        Text("Last Event Type")
                            .foregroundStyle(.secondary)
                        Text(lastObservedEventType ?? "None")
                    }
                }
            }
        }
    }

    private var compatibilityNotesCard: some View {
        JitouchSurfaceCard(
            title: "Compatibility Notes",
            subtitle: "A few deliberate differences remain while the old preference pane becomes a real standalone app.",
            symbol: "info.circle",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                DiagnosticsNoteRow(text: menuBarVisibilityNote)
                DiagnosticsNoteRow(text: "The old preference pane's `ShowIcon` toggle is still preserved in storage, but it is not applied yet so the standalone app does not disappear.")
                DiagnosticsNoteRow(text: "Trackpad one-finger/two-finger character recognition and Magic Mouse drag-to-character are now running in Swift. Remaining work is mostly gesture feel tuning, extra overlays, and device-by-device calibration.")
                DiagnosticsNoteRow(text: "Latest touch frame: \(lastEventDescription)")
                DiagnosticsNoteRow(text: "Last gesture event: \(lastRecognizedGestureSummary)")
                DiagnosticsNoteRow(text: "Last executed command: \(lastExecutedCommandSummary)")
            }
        }
    }
}

private struct DiagnosticsNoteRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DiagnosticsDeviceSection: View {
    let title: String
    let devices: [ConnectedDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if devices.isEmpty {
                SettingsSecondaryPlaceholderText(text: "No devices detected.")
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
}
