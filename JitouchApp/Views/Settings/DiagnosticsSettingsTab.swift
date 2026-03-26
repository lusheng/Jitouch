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
    let trackpadCommandCount: Int
    let magicMouseCommandCount: Int
    let recognitionCommandCount: Int
    let lastError: String?
    let menuBarVisibilityNote: String
    let lastEventDescription: String
    let focusedSection: JitouchSettingsSectionAnchor?
    let navigationToken: UUID
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
        trackpadCommandCount: Int,
        magicMouseCommandCount: Int,
        recognitionCommandCount: Int,
        lastError: String?,
        menuBarVisibilityNote: String,
        lastEventDescription: String,
        focusedSection: JitouchSettingsSectionAnchor?,
        navigationToken: UUID,
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
        self.trackpadCommandCount = trackpadCommandCount
        self.magicMouseCommandCount = magicMouseCommandCount
        self.recognitionCommandCount = recognitionCommandCount
        self.lastError = lastError
        self.menuBarVisibilityNote = menuBarVisibilityNote
        self.lastEventDescription = lastEventDescription
        self.focusedSection = focusedSection
        self.navigationToken = navigationToken
        self.calibration = calibration()
    }

    var body: some View {
        ScrollViewReader { proxy in
            SettingsPageScaffold(
                title: JitouchSettingsPane.diagnostics.title,
                subtitle: JitouchSettingsPane.diagnostics.subtitle
            ) {
                diagnosticsSummaryCard
                recentActivityCard
                    .id(JitouchSettingsSectionAnchor.diagnosticsRecentActivity.rawValue)
                importedCoverageCard
                    .id(JitouchSettingsSectionAnchor.diagnosticsCoverage.rawValue)
                calibration
                connectedDevicesCard
                compatibilityNotesCard
                    .id(JitouchSettingsSectionAnchor.diagnosticsCompatibility.rawValue)
            }
            .onAppear {
                scrollIfNeeded(using: proxy)
            }
            .onChange(of: navigationToken) { _, _ in
                scrollIfNeeded(using: proxy)
            }
        }
    }

    private var diagnosticsSummaryCard: some View {
        JitouchSurfaceCard(
            title: "Runtime Diagnostics",
            subtitle: "Health, counters, and device visibility from the Swift runtime.",
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
                    title: "Last Event Type",
                    value: lastObservedEventType ?? "None",
                    detail: "Latest touch frame: \(lastEventDescription)",
                    symbol: "waveform.path.ecg",
                    tint: .indigo
                )
            }
        }
    }

    private var recentActivityCard: some View {
        JitouchSurfaceCard(
            title: "Recent Activity",
            subtitle: "The most recent command and gesture history has moved here so Overview can stay focused on controls.",
            symbol: "clock.arrow.circlepath",
            tint: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsTitledSummaryRow(
                    title: "Last gesture",
                    summary: lastRecognizedGestureSummary
                )
                SettingsTitledSummaryRow(
                    title: "Last command",
                    summary: lastExecutedCommandSummary
                )
                SettingsTitledSummaryRow(
                    title: "Latest touch frame",
                    summary: lastEventDescription
                )
                SettingsTitledSummaryRow(
                    title: "Last error",
                    summary: lastError ?? "No recent runtime error.",
                    summaryTint: lastError == nil ? .secondary : .red
                )
            }
        }
    }

    private var importedCoverageCard: some View {
        JitouchSurfaceCard(
            title: "Imported Coverage",
            subtitle: "Editable command data currently loaded from the legacy preferences domain.",
            symbol: "square.grid.2x2",
            tint: .mint
        ) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsLabelValueRow(label: "Trackpad", value: "\(trackpadCommandCount)")
                SettingsLabelValueRow(label: "Magic Mouse", value: "\(magicMouseCommandCount)")
                SettingsLabelValueRow(label: "Character Recognition", value: "\(recognitionCommandCount)")

                SettingsFootnoteText(
                    text: totalImportedMappingCount > 0
                        ? "\(totalImportedMappingCount) editable mappings are currently available in Swift."
                        : "No editable mappings are currently loaded."
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

                SettingsKeyValueGrid(items: connectedDeviceMetrics)
            }
        }
    }

    private var compatibilityNotesCard: some View {
        JitouchSurfaceCard(
            title: "Compatibility Notes",
            subtitle: "Intentional differences and remaining modernization notes for the standalone app.",
            symbol: "info.circle",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(compatibilityNotes, id: \.self) { note in
                    SettingsBulletNoteRow(text: note)
                }
            }
        }
    }

    private var totalImportedMappingCount: Int {
        trackpadCommandCount + magicMouseCommandCount + recognitionCommandCount
    }

    private var connectedDeviceMetrics: [SettingsKeyValueItem] {
        [
            SettingsKeyValueItem(label: "Observed Events", value: "\(observedEventCount)"),
            SettingsKeyValueItem(label: "Tap Recoveries", value: "\(recoveryCount)"),
            SettingsKeyValueItem(label: "Last Event Type", value: lastObservedEventType ?? "None"),
        ]
    }

    private var compatibilityNotes: [String] {
        [
            menuBarVisibilityNote,
            "The old preference pane's `ShowIcon` toggle is still preserved in storage, but it is not applied yet so the standalone app does not disappear.",
            "Trackpad one-finger/two-finger character recognition and Magic Mouse drag-to-character are now running in Swift. Remaining work is mostly gesture feel tuning, extra overlays, and device-by-device calibration.",
        ]
    }

    private func scrollIfNeeded(using proxy: ScrollViewProxy) {
        guard let focusedSection, handledAnchors.contains(focusedSection) else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(focusedSection.rawValue, anchor: .top)
            }
        }
    }

    private var handledAnchors: Set<JitouchSettingsSectionAnchor> {
        [
            .diagnosticsRecentActivity,
            .diagnosticsCoverage,
            .diagnosticsCompatibility,
        ]
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
                    SettingsLabelValueRow(
                        label: device.displayName,
                        value: "family \(device.familyID)"
                    )
                }
            }
        }
    }
}
