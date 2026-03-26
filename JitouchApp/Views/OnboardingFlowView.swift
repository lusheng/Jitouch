import SwiftUI

struct OnboardingFlowView: View {
    private enum Layout {
        static let windowSize = CGSize(width: 1120, height: 720)
        static let sidebarWidth: CGFloat = 348
    }

    @Environment(JitouchAppModel.self) private var appModel

    @State private var selectedStep: OnboardingStep = .welcome

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.launchAtLoginEnabled },
            set: { appModel.setLaunchAtLoginEnabled($0) }
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

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                detail
                Divider()
                footer
            }
        }
        .frame(width: Layout.windowSize.width, height: Layout.windowSize.height)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.988, blue: 0.994),
                    Color.white,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup Guide")
                    .font(.title2.weight(.semibold))

                Text("A focused pass through the few macOS checks and runtime controls that still matter before daily use.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            onboardingProgressPanel

            VStack(alignment: .leading, spacing: 10) {
                ForEach(OnboardingStep.allCases) { step in
                    stepRow(for: step)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(width: Layout.sidebarWidth, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.956, green: 0.966, blue: 0.982),
                    Color(red: 0.970, green: 0.975, blue: 0.985),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var onboardingProgressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                SettingsCardStatusBadge(
                    title: appModel.onboardingProgressSummary,
                    tint: appModel.onboardingCoreRequirementsMet ? .green : .orange
                )
            }

            ProgressView(value: appModel.onboardingProgressValue)
                .tint(.accentColor)

            Text("Complete the essential checks, then jump into Trackpad, Magic Mouse, or Diagnostics from the main settings window.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private func stepRow(for step: OnboardingStep) -> some View {
        let isSelected = selectedStep == step

        return Button {
            selectedStep = step
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.84))

                    Image(systemName: step.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(0.72))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(step.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.96) : Color.white.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedStep {
                case .welcome:
                    welcomeStep
                case .accessibility:
                    accessibilityStep
                case .startup:
                    startupStep
                case .devices:
                    devicesStep
                case .finish:
                    finishStep
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Welcome to the Standalone App",
                subtitle: "The Swift rewrite is already capable enough for real use. This guide only covers the pieces that still gate smooth daily use."
            )

            JitouchSurfaceCard(
                title: "Already In Place",
                subtitle: "The biggest modernization work is already behind you.",
                symbol: "sparkles",
                tint: .blue
            ) {
                SettingsMetricsGrid(minimumWidth: 220, spacing: 14) {
                    JitouchMetricTile(
                        title: "Gesture Runtime",
                        value: "Swift",
                        detail: "Trackpad and Magic Mouse recognizers now run in the standalone app.",
                        symbol: "hand.tap",
                        tint: .blue
                    )
                    JitouchMetricTile(
                        title: "Profile Editing",
                        value: "Live",
                        detail: "Bindings, overrides, and character mappings can be edited in the new UI.",
                        symbol: "slider.horizontal.3",
                        tint: .indigo
                    )
                    JitouchMetricTile(
                        title: "Diagnostics",
                        value: "Built In",
                        detail: "Event tap counters, recent activity, and device state are already visible.",
                        symbol: "waveform.path.ecg",
                        tint: .pink
                    )
                }
            }

            JitouchSurfaceCard(
                title: "What This Guide Covers",
                subtitle: "A quick pass through the remaining setup gates, not a full product tour.",
                symbol: "flag.checkered",
                tint: .green
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    onboardingBullet("Grant Accessibility so Jitouch can observe input and drive AX actions.")
                    onboardingBullet("Choose whether it should come online automatically after login.")
                    onboardingBullet("Confirm the device families you care about are enabled and visible.")
                }

                SettingsActionRow {
                    Button("Open Overview") {
                        appModel.openSettingsPane(.overview, section: .overviewGeneralControls)
                    }
                    .buttonStyle(.bordered)

                    Button("Open Diagnostics") {
                        appModel.openSettingsPane(.diagnostics, section: .diagnosticsRecentActivity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Accessibility Is The Main Gate",
                subtitle: "Without Accessibility trust, Jitouch cannot reliably observe global input, send shortcuts, or move windows."
            )

            JitouchSurfaceCard(
                title: "Current Status",
                subtitle: appModel.accessibilityGuidance,
                symbol: appModel.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield",
                tint: appModel.accessibilityGranted ? .green : .orange,
                accessory: {
                    JitouchStatusBadge(
                        title: appModel.accessibilityStatusText,
                        tint: appModel.accessibilityGranted ? .green : .orange
                    )
                }
            ) {
                SettingsActionRow {
                    Button("Prompt for Access") {
                        appModel.requestAccessibilityPermission()
                        appModel.refresh()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Accessibility Settings") {
                        appModel.openAccessibilitySystemSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Overview Section") {
                        appModel.openSettingsPane(.overview, section: .overviewPermissions)
                    }
                    .buttonStyle(.bordered)
                }

                SettingsFootnoteText(
                    text: "After enabling Jitouch in Privacy & Security > Accessibility, come back and restart the runtime if needed."
                )
            }
        }
    }

    private var startupStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Startup Behavior",
                subtitle: "Decide whether Jitouch should quietly come online whenever you log in."
            )

            JitouchSurfaceCard(
                title: "Launch At Login",
                subtitle: appModel.launchAtLoginStatus.detail,
                symbol: "power.circle",
                tint: .teal,
                accessory: {
                    JitouchStatusBadge(
                        title: appModel.launchAtLoginStatus.title,
                        tint: appModel.launchAtLoginStatus.isEnabled ? .green : .secondary
                    )
                }
            ) {
                Toggle("Start Jitouch automatically after login", isOn: launchAtLoginBinding)

                SettingsActionRow {
                    Button("Open Login Items Settings") {
                        appModel.openLoginItemsSystemSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Overview Section") {
                        appModel.openSettingsPane(.overview, section: .overviewPermissions)
                    }
                    .buttonStyle(.borderedProminent)
                }

                SettingsFootnoteText(
                    text: "Debug builds can still show `Unavailable` or `Needs Approval` because macOS expects a properly signed app for the cleanest `SMAppService` path."
                )
            }
        }
    }

    private var devicesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Devices And Profiles",
                subtitle: "Make sure the hardware you care about is visible and that the relevant profile families are turned on."
            )

            JitouchSurfaceCard(
                title: "Profile Families",
                subtitle: "These toggles decide which gesture surfaces stay active in the runtime.",
                symbol: "switch.2",
                tint: .indigo
            ) {
                Toggle("Enable Trackpad Profiles", isOn: trackpadEnabledBinding)
                Toggle("Enable Magic Mouse Profiles", isOn: magicMouseEnabledBinding)
            }

            SettingsMetricsGrid(minimumWidth: 220, spacing: 14) {
                JitouchMetricTile(
                    title: "Trackpads",
                    value: "\(appModel.deviceManager.trackpadDevices.count)",
                    detail: "\(appModel.trackpadCommandCount) editable mappings",
                    symbol: "rectangle.and.hand.point.up.left",
                    tint: .blue
                )
                JitouchMetricTile(
                    title: "Magic Mouse",
                    value: "\(appModel.deviceManager.magicMouseDevices.count)",
                    detail: "\(appModel.magicMouseCommandCount) editable mappings",
                    symbol: "mouse",
                    tint: .mint
                )
                JitouchMetricTile(
                    title: "Recognition",
                    value: "\(appModel.recognitionCommandCount)",
                    detail: "Character outputs ready to edit",
                    symbol: "character.cursor.ibeam",
                    tint: .purple
                )
            }

            SettingsActionRow {
                Button("Open Trackpad Page") {
                    appModel.openSettingsPane(.trackpad)
                }
                .buttonStyle(.bordered)

                Button("Open Magic Mouse Page") {
                    appModel.openSettingsPane(.magicMouse)
                }
                .buttonStyle(.bordered)

                Button("Open Recognition Page") {
                    appModel.openSettingsPane(.recognition)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Finish Setup",
                subtitle: "Use the guide as a launchpad, then do the fine-tuning in Overview, Diagnostics, and the device pages."
            )

            JitouchSurfaceCard(
                title: "Readiness Summary",
                subtitle: appModel.onboardingCoreRequirementsMet
                    ? "Core setup requirements are in place."
                    : "A few essentials still need attention before you mark setup complete.",
                symbol: appModel.onboardingCoreRequirementsMet ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: appModel.onboardingCoreRequirementsMet ? .green : .orange
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appModel.onboardingChecklistItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(item.isComplete ? .green : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            SettingsActionRow {
                Button("Open Overview") {
                    appModel.openSettingsPane(.overview, section: .overviewGeneralControls)
                }
                .buttonStyle(.bordered)

                Button("Open Diagnostics") {
                    appModel.openSettingsPane(.diagnostics, section: .diagnosticsRecentActivity)
                }
                .buttonStyle(.bordered)

                Button("Open Trackpad") {
                    appModel.openSettingsPane(.trackpad)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Finish Later") {
                appModel.dismissOnboarding()
            }
            .buttonStyle(.bordered)

            Spacer()

            if selectedStep != OnboardingStep.allCases.first {
                Button("Back") {
                    selectedStep = previousStep(from: selectedStep)
                }
                .buttonStyle(.bordered)
            }

            if selectedStep == .finish {
                Button("Mark Setup Complete") {
                    appModel.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appModel.onboardingCoreRequirementsMet)
            } else {
                Button("Continue") {
                    selectedStep = nextStep(from: selectedStep)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.72))
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.semibold))

            Text(subtitle)
                .font(.title3.weight(.regular))
                .foregroundStyle(.secondary)
        }
    }

    private func onboardingBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    private func nextStep(from step: OnboardingStep) -> OnboardingStep {
        OnboardingStep(rawValue: min(step.rawValue + 1, OnboardingStep.allCases.count - 1)) ?? .finish
    }

    private func previousStep(from step: OnboardingStep) -> OnboardingStep {
        OnboardingStep(rawValue: max(step.rawValue - 1, 0)) ?? .welcome
    }
}
