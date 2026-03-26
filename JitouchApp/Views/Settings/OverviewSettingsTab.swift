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
    let lastReloadDate: Date?
    @Binding var jitouchEnabled: Bool
    @Binding var launchAtLoginEnabled: Bool
    @Binding var trackpadEnabled: Bool
    @Binding var magicMouseEnabled: Bool
    @Binding var clickSpeed: Double
    @Binding var sensitivity: Double
    let focusedSection: JitouchSettingsSectionAnchor?
    let navigationToken: UUID
    let onOpenSetupGuide: () -> Void
    let onResetSetupStatus: () -> Void
    let onPromptForAccess: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onOpenLoginItemsSettings: () -> Void
    let onRefreshPreferences: () -> Void
    let onRestartRuntime: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            SettingsPageScaffold(
                title: JitouchSettingsPane.overview.title,
                subtitle: JitouchSettingsPane.overview.subtitle
            ) {
                overviewHeroCard
                generalSettingsCard
                    .id(JitouchSettingsSectionAnchor.overviewGeneralControls.rawValue)
                permissionsAndStartupCard
                    .id(JitouchSettingsSectionAnchor.overviewPermissions.rawValue)
                quickActionsCard
                    .id(JitouchSettingsSectionAnchor.overviewQuickActions.rawValue)
                setupGuideCard
                    .id(JitouchSettingsSectionAnchor.overviewSetupGuide.rawValue)
            }
            .onAppear {
                scrollIfNeeded(using: proxy)
            }
            .onChange(of: navigationToken) { _, _ in
                scrollIfNeeded(using: proxy)
            }
        }
    }

    private var overviewHeroCard: some View {
        JitouchSurfaceCard(
            title: isEnabled ? "Gesture Engine Ready" : "Jitouch Is Paused",
            subtitle: "Use Overview for the controls that matter most day to day. Detailed runtime history and migration notes live in Diagnostics.",
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
            }
        }
    }

    private var permissionsAndStartupCard: some View {
        JitouchSurfaceCard(
            title: "Accessibility & Startup",
            subtitle: "Handle the two macOS integrations that decide whether Jitouch can work reliably and appear when you need it.",
            symbol: "lock.shield",
            tint: accessibilityGranted ? .green : .orange,
            accessory: {
                SettingsCardStatusBadge(
                    title: accessibilityGranted ? "Accessibility Ready" : "Needs Permission",
                    tint: accessibilityGranted ? .green : .orange
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsStatusListRow(
                    title: "Accessibility Permission",
                    detail: accessibilityGuidance,
                    systemImage: accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield",
                    tint: accessibilityGranted ? .green : .orange,
                    actionTitle: accessibilityGranted ? nil : "Prompt for Access",
                    action: accessibilityGranted ? nil : onPromptForAccess
                )

                SettingsActionRow {
                    Button("Open Accessibility Settings", action: onOpenAccessibilitySettings)
                        .buttonStyle(.bordered)

                    if !accessibilityGranted {
                        Button("Restart Runtime", action: onRestartRuntime)
                            .buttonStyle(.borderedProminent)
                    }
                }

                Divider()

                Toggle("Start Jitouch automatically after login", isOn: $launchAtLoginEnabled)

                SettingsLabelValueRow(
                    label: "Launch at Login",
                    value: launchAtLoginStatus.title,
                    valueTint: launchAtLoginStatus.isEnabled ? .green : .secondary
                )

                SettingsSecondaryPlaceholderText(text: launchAtLoginStatus.detail)

                SettingsActionMessageRow {
                    Button("Open Login Items Settings", action: onOpenLoginItemsSettings)
                        .buttonStyle(.bordered)
                } message: {
                    if launchAtLoginStatus.requiresApproval {
                        SettingsFootnoteText(
                            text: "Approval is still pending in System Settings.",
                            tint: .orange
                        )
                    }
                }
            }
        }
    }

    private var quickActionsCard: some View {
        JitouchSurfaceCard(
            title: "Quick Actions",
            subtitle: "Recovery and maintenance controls that you may need when macOS permissions or runtime state change.",
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

    private var setupGuideCard: some View {
        JitouchSurfaceCard(
            title: "Setup Guide",
            subtitle: hasCompletedOnboarding
                ? "Replay the guide any time if you want a quick readiness check."
                : "Walk through permissions, startup behavior, and device readiness in one focused pass.",
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

            if !onboardingCoreRequirementsMet {
                SettingsFootnoteText(
                    text: "Accessibility and runtime readiness still deserve a quick pass before deep gesture tuning."
                )
            }
        }
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
            .overviewGeneralControls,
            .overviewPermissions,
            .overviewQuickActions,
            .overviewSetupGuide,
        ]
    }
}
