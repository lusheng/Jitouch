import SwiftUI

struct OverviewSettingsTab: View {
    let isEnabled: Bool
    let menuBarSymbolName: String
    let isRuntimeReady: Bool
    let deviceCount: Int
    let focusedApplicationName: String
    let hasCompletedOnboarding: Bool
    let onboardingProgressSummary: String
    let onboardingCoreRequirementsMet: Bool
    let accessibilityGranted: Bool
    let accessibilityStatusText: String
    let accessibilityGuidance: String
    let launchAtLoginStatus: LaunchAtLoginStatusSnapshot
    let trackpadDeviceCount: Int
    let magicMouseDeviceCount: Int
    let lastExecutedCommandSummary: String
    let lastRecognizedGestureSummary: String
    let lastReloadDate: Date?
    let trackpadCommandCount: Int
    let magicMouseCommandCount: Int
    let recognitionCommandCount: Int
    let trackpadCommands: [ApplicationCommandSet]
    let magicMouseCommands: [ApplicationCommandSet]
    let recognitionCommands: [ApplicationCommandSet]
    let lastError: String?
    @Binding var jitouchEnabled: Bool
    @Binding var trackpadEnabled: Bool
    @Binding var magicMouseEnabled: Bool
    @Binding var clickSpeed: Double
    @Binding var sensitivity: Double
    let onOpenSetupGuide: () -> Void
    let onResetSetupStatus: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onRefreshPreferences: () -> Void
    let onRestartRuntime: () -> Void

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.overview.title,
            subtitle: JitouchSettingsPane.overview.subtitle
        ) {
            overviewHeroCard
            overviewMetrics
            quickActionsCard
            onboardingGuideCard
            setupChecklist
            generalSettingsCard
            importedCoverageCard

            if let lastError, !lastError.isEmpty {
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

    private var overviewHeroCard: some View {
        JitouchSurfaceCard(
            title: isEnabled ? "Gesture Engine Ready" : "Jitouch Is Paused",
            subtitle: "The standalone Swift app now owns device hooks, event taps, editable profiles, and recognition diagnostics. What remains is mostly real-world tuning.",
            symbol: menuBarSymbolName,
            tint: isEnabled ? .green : .orange,
            accessory: {
                SettingsCardStatusBadge(
                    title: isEnabled ? "Active" : "Paused",
                    tint: isEnabled ? .green : .orange
                )
            }
        ) {
            HStack(spacing: 14) {
                JitouchInlineMetric(
                    label: "Runtime",
                    value: isRuntimeReady ? "Ready" : "Needs Attention",
                    tint: isRuntimeReady ? .green : .orange
                )
                JitouchInlineMetric(
                    label: "Devices",
                    value: "\(deviceCount)",
                    tint: .mint
                )
                JitouchInlineMetric(
                    label: "Focused App",
                    value: focusedApplicationName,
                    tint: .blue
                )
            }
        }
    }

    private var onboardingGuideCard: some View {
        JitouchSurfaceCard(
            title: "Setup Guide",
            subtitle: hasCompletedOnboarding
                ? "Reopen the guide any time if you want a quick readiness pass."
                : "Walk through permissions, startup behavior, and device readiness in one place.",
            symbol: "figure.walk.motion",
            tint: hasCompletedOnboarding ? .blue : .green,
            accessory: {
                SettingsCardStatusBadge(
                    title: onboardingProgressSummary,
                    tint: onboardingCoreRequirementsMet ? .green : .orange
                )
            }
        ) {
            SettingsActionRow {
                Button(hasCompletedOnboarding ? "Replay Setup Guide" : "Open Setup Guide", action: onOpenSetupGuide)
                    .buttonStyle(.borderedProminent)

                if hasCompletedOnboarding {
                    Button("Reset Setup Status", action: onResetSetupStatus)
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var overviewMetrics: some View {
        SettingsMetricsGrid(minimumWidth: 180, spacing: 14) {
            JitouchMetricTile(
                title: "Accessibility",
                value: accessibilityStatusText,
                detail: accessibilityGuidance,
                symbol: accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield",
                tint: accessibilityGranted ? .green : .orange
            )
            JitouchMetricTile(
                title: "Launch at Login",
                value: launchAtLoginStatus.title,
                detail: launchAtLoginStatus.detail,
                symbol: "power.circle",
                tint: .blue
            )
            JitouchMetricTile(
                title: "Touch Devices",
                value: "\(deviceCount)",
                detail: "Trackpads: \(trackpadDeviceCount)  Magic Mouse: \(magicMouseDeviceCount)",
                symbol: "hand.tap",
                tint: .mint
            )
            JitouchMetricTile(
                title: "Last Command",
                value: lastExecutedCommandSummary,
                detail: lastRecognizedGestureSummary,
                symbol: "sparkles",
                tint: .purple
            )
        }
    }

    private var setupChecklist: some View {
        JitouchSurfaceCard(
            title: "Setup Checklist",
            subtitle: "The refactor is far enough along to use like a real utility app. These are the remaining readiness checks before serious tuning.",
            symbol: "checklist",
            tint: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OverviewChecklistRow(
                    title: "Accessibility permission",
                    detail: accessibilityGranted
                        ? "Granted. Event taps and AX window control can run."
                        : "Still blocked. Jitouch cannot intercept input or move windows until macOS trust is granted.",
                    isComplete: accessibilityGranted,
                    actionTitle: accessibilityGranted ? nil : "Open Settings",
                    action: accessibilityGranted ? nil : onOpenAccessibilitySettings
                )
                OverviewChecklistRow(
                    title: "Event tap",
                    detail: isRuntimeReady
                        ? "Running and ready to observe system input."
                        : "Stopped or unavailable. Restart runtime services after fixing permissions.",
                    isComplete: isRuntimeReady,
                    actionTitle: isRuntimeReady ? nil : "Restart Services",
                    action: isRuntimeReady ? nil : onRestartRuntime
                )
                OverviewChecklistRow(
                    title: "Touch devices",
                    detail: deviceCount > 0
                        ? "\(deviceCount) device(s) detected for gesture input."
                        : "No compatible device is currently visible to the runtime.",
                    isComplete: deviceCount > 0
                )
                OverviewChecklistRow(
                    title: "Imported mappings",
                    detail: importedMappingCount > 0
                        ? "Legacy mappings are available to edit and execute."
                        : "No gesture bindings are loaded yet, so the app has nothing useful to run.",
                    isComplete: importedMappingCount > 0
                )
            }
        }
    }

    private var quickActionsCard: some View {
        JitouchSurfaceCard(
            title: "Quick Actions",
            subtitle: "The most useful recovery and maintenance controls, without digging through multiple pages.",
            symbol: "bolt.circle",
            tint: .blue
        ) {
            SettingsActionRow {
                Button("Reload Preferences", action: onRefreshPreferences)
                    .buttonStyle(.bordered)

                Button("Restart Runtime", action: onRestartRuntime)
                    .buttonStyle(.borderedProminent)

                Button("Open Accessibility", action: onOpenAccessibilitySettings)
                    .buttonStyle(.bordered)
            }

            if let lastReloadDate {
                SettingsFootnoteText(
                    text: "Last refreshed \(lastReloadDate.formatted(date: .abbreviated, time: .shortened))"
                )
            }
        }
    }

    private var generalSettingsCard: some View {
        JitouchSurfaceCard(
            title: "General Controls",
            subtitle: "Master switches and feel settings that affect the entire runtime.",
            symbol: "slider.horizontal.3",
            tint: .indigo
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Jitouch", isOn: $jitouchEnabled)
                Toggle("Enable Trackpad Profiles", isOn: $trackpadEnabled)
                Toggle("Enable Magic Mouse Profiles", isOn: $magicMouseEnabled)

                SettingsSliderControlRow(
                    title: "Click Speed",
                    value: $clickSpeed,
                    in: 0.05 ... 0.60,
                    valueText: clickSpeed.formatted(.number.precision(.fractionLength(2)))
                )

                SettingsSliderControlRow(
                    title: "Sensitivity",
                    value: $sensitivity,
                    in: 1.0 ... 8.0,
                    valueText: sensitivity.formatted(.number.precision(.fractionLength(2)))
                )

                SettingsActionRow {
                    Button("Reload Preferences from Disk", action: onRefreshPreferences)
                    Button("Restart Runtime Services", action: onRestartRuntime)
                }
            }
        }
    }

    private var importedCoverageCard: some View {
        JitouchSurfaceCard(
            title: "Imported Coverage",
            subtitle: "A quick read on how much of the old preference domain has already been pulled into editable Swift models.",
            symbol: "square.grid.2x2",
            tint: .mint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OverviewCoverageRow(title: "Trackpad", count: trackpadCommandCount)
                OverviewCoverageRow(title: "Magic Mouse", count: magicMouseCommandCount)
                OverviewCoverageRow(title: "Character Recognition", count: recognitionCommandCount)

                Divider()

                Text("Imported legacy profiles")
                    .font(.headline)

                OverviewCommandSampleView(device: .trackpad, sets: trackpadCommands)
                OverviewCommandSampleView(device: .magicMouse, sets: magicMouseCommands)
                OverviewCommandSampleView(device: .recognition, sets: recognitionCommands)
            }
        }
    }

    private var importedMappingCount: Int {
        trackpadCommandCount + magicMouseCommandCount + recognitionCommandCount
    }
}

private struct OverviewChecklistRow: View {
    let title: String
    let detail: String
    let isComplete: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        detail: String,
        isComplete: Bool,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        SettingsStatusListRow(
            title: title,
            detail: detail,
            systemImage: isComplete ? "checkmark.circle.fill" : "circle.dashed",
            tint: isComplete ? .green : .orange,
            actionTitle: actionTitle,
            action: action
        )
    }
}

private struct OverviewCoverageRow: View {
    let title: String
    let count: Int

    var body: some View {
        SettingsLabelValueRow(label: title, value: "\(count)")
    }
}

private struct OverviewCommandSampleView: View {
    let device: CommandDevice
    let sets: [ApplicationCommandSet]

    var body: some View {
        SettingsTitledSummaryRow(
            title: device.title,
            summary: previewSummary
        )
    }

    private var previewSummary: String {
        if let firstSet = sets.first {
            let preview = firstSet.gestures.prefix(3).map { "\($0.gesture) -> \($0.command)" }.joined(separator: " • ")
            return preview.isEmpty ? "No commands imported." : preview
        }

        return "No commands imported."
    }
}
