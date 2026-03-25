import SwiftUI

struct OnboardingFlowView: View {
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
        .frame(width: 920, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Setup Guide")
                    .font(.title2.weight(.semibold))

                Text("A guided pass through the minimum setup needed to make the standalone Swift app feel like home.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: appModel.onboardingProgressValue)
                .controlSize(.large)

            Text(appModel.onboardingProgressSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(OnboardingStep.allCases) { step in
                    Button {
                        selectedStep = step
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: step.symbolName)
                                .frame(width: 20)
                                .foregroundStyle(selectedStep == step ? .blue : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(step.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedStep == step ? Color.blue.opacity(0.10) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            JitouchSurfaceCard(
                title: "Core Checks",
                subtitle: "These are the signals that matter most before deep gesture tuning.",
                symbol: "checklist",
                tint: .green
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appModel.onboardingChecklistItems) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(item.isComplete ? .green : .orange)
                                .padding(.top, 1)

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
        }
        .padding(24)
        .frame(width: 290, alignment: .topLeading)
        .background(Color(nsColor: .underPageBackgroundColor))
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
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Welcome to the Standalone App",
                subtitle: "Jitouch has crossed the line from an old preference pane into a real menu bar app with a Swift runtime, editable profiles, and diagnostics."
            )

            JitouchSurfaceCard(
                title: "What Is Already Modernized",
                subtitle: "The heavy lifting from the old Objective-C codebase is now alive in Swift.",
                symbol: "sparkles",
                tint: .blue
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
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
                        detail: "Bindings, per-app overrides, and character mappings can be edited in the new UI.",
                        symbol: "slider.horizontal.3",
                        tint: .indigo
                    )
                    JitouchMetricTile(
                        title: "Diagnostics",
                        value: "Built In",
                        detail: "Recognition snapshots and device state are exposed without relying on old debug tooling.",
                        symbol: "waveform.path.ecg",
                        tint: .pink
                    )
                }
            }

            JitouchSurfaceCard(
                title: "What This Guide Does",
                subtitle: "A short run through the few things that still gate daily usability.",
                symbol: "flag.checkered",
                tint: .green
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    onboardingBullet("Grant Accessibility so input observation and AX window actions actually work.")
                    onboardingBullet("Decide whether Jitouch should start automatically after login.")
                    onboardingBullet("Confirm that your active input devices and profiles are turned on.")
                    onboardingBullet("Finish with a clear view of what is ready and what still needs real-hardware tuning.")
                }

                HStack(spacing: 12) {
                    Button("Open Overview Page") {
                        appModel.openSettingsPane(.overview)
                    }
                    .buttonStyle(.bordered)

                    Button("Jump to Permissions") {
                        appModel.openSettingsPane(.permissions)
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

                    Button("Re-check Runtime") {
                        appModel.refresh()
                        appModel.restartRuntimeServices()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Permissions Page") {
                        appModel.openSettingsPane(.permissions)
                    }
                    .buttonStyle(.bordered)
                }

                Text("After you enable Jitouch in Privacy & Security > Accessibility, come back here and re-check runtime state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                HStack(spacing: 12) {
                    Button("Open Login Items Settings") {
                        appModel.openLoginItemsSystemSettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Restart Runtime Services") {
                        appModel.restartRuntimeServices()
                    }
                    .buttonStyle(.bordered)

                    Button("Open Permissions Page") {
                        appModel.openSettingsPane(.permissions)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Debug builds can still show `Unavailable` or `Needs Approval` because macOS expects a properly signed app for the cleanest `SMAppService` path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var devicesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Devices And Profiles",
                subtitle: "Make sure the hardware you care about is visible and that at least one profile family is enabled."
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                JitouchMetricTile(
                    title: "Trackpads",
                    value: "\(appModel.deviceManager.trackpadDevices.count)",
                    detail: "\(appModel.trackpadCommandCount) imported mappings",
                    symbol: "rectangle.and.hand.point.up.left",
                    tint: .blue
                )
                JitouchMetricTile(
                    title: "Magic Mouse",
                    value: "\(appModel.deviceManager.magicMouseDevices.count)",
                    detail: "\(appModel.magicMouseCommandCount) imported mappings",
                    symbol: "mouse",
                    tint: .mint
                )
                JitouchMetricTile(
                    title: "Recognition",
                    value: "\(appModel.recognitionCommandCount)",
                    detail: "Character outputs ready to execute",
                    symbol: "character.cursor.ibeam",
                    tint: .purple
                )
            }

            JitouchSurfaceCard(
                title: "Next Tuning Pass",
                subtitle: "Once setup is complete, the remaining improvements are mostly about feel rather than missing architecture.",
                symbol: "scope",
                tint: .orange
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    onboardingBullet("Tune trackpad and Magic Mouse gesture thresholds on real hardware.")
                    onboardingBullet("Validate character-recognition accuracy with the built-in diagnostics pane.")
                    onboardingBullet("Refine Move / Resize and overlay behavior until it feels closer to the legacy app.")
                }

                HStack(spacing: 12) {
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
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader(
                title: "Finish Setup",
                subtitle: "You are one step away from turning this preview into a daily-use environment."
            )

            JitouchSurfaceCard(
                title: "Readiness Summary",
                subtitle: appModel.onboardingCoreRequirementsMet
                    ? "Core setup requirements are in place."
                    : "A few core requirements still need attention before the guide can be marked complete.",
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

            JitouchSurfaceCard(
                title: "Where To Go Next",
                subtitle: "Use the setup guide as a launchpad into the parts of the new app you actually want to tune.",
                symbol: "arrowshape.turn.up.right",
                tint: .blue
            ) {
                HStack(spacing: 12) {
                    Button("Open Overview") {
                        appModel.openSettingsPane(.overview)
                    }
                    .buttonStyle(.bordered)

                    Button("Open Diagnostics") {
                        appModel.openSettingsPane(.diagnostics)
                    }
                    .buttonStyle(.bordered)

                    Button("Open Trackpad") {
                        appModel.openSettingsPane(.trackpad)
                    }
                    .buttonStyle(.borderedProminent)
                }
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
        .padding(20)
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.semibold))

            Text(subtitle)
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
