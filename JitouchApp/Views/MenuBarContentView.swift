import AppKit
import SwiftUI

struct MenuBarContentView: View {
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.launchAtLoginEnabled },
            set: { appModel.setLaunchAtLoginEnabled($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerCard

            if !appModel.accessibilityGranted {
                attentionCard(
                    title: "Accessibility Access Needed",
                    message: "Grant permission before Jitouch can drive windows and shortcuts.",
                    primaryTitle: "Open Access Settings",
                    primaryAction: {
                        appModel.openAccessibilitySystemSettings()
                    }
                )
            }

            if appModel.shouldShowSetupGuide {
                attentionCard(
                    title: "Guided Setup Available",
                    message: "Open the new setup guide for a cleaner walk through permissions, startup behavior, and device readiness.",
                    primaryTitle: "Open Setup Guide",
                    primaryAction: {
                        appModel.presentOnboarding()
                        appModel.openSettingsWindow()
                    }
                )
            }

            controlRow
            activeAppRoutingCard
            metricsGrid
            runtimeActions
            launchAtLoginCard
            activityCard

            Divider()

            Button("Quit Jitouch") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 380)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.17, green: 0.44, blue: 0.95),
                                    Color(red: 0.10, green: 0.72, blue: 0.64),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: appModel.menuBarSymbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Jitouch")
                            .font(.title3.weight(.semibold))

                        Spacer()

                        JitouchStatusBadge(
                            title: appModel.settings.isEnabled ? "Active" : "Paused",
                            tint: appModel.settings.isEnabled ? .green : .orange
                        )
                    }

                    Text(
                        appModel.settings.isEnabled
                            ? "Gesture engine is ready. Use the controls below for quick checks and maintenance."
                            : "Jitouch is paused. Re-enable it here when you want gestures back."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Toggle("Enable Jitouch", isOn: enabledBinding)
                .toggleStyle(.switch)
        }
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            Button(appModel.settings.isEnabled ? "Pause" : "Resume") {
                appModel.setEnabled(!appModel.settings.isEnabled)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            SettingsLink {
                Label("Preferences", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricTile(
                title: "Accessibility",
                value: appModel.accessibilityStatusText,
                symbol: appModel.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield",
                tint: appModel.accessibilityGranted ? .green : .orange
            )
            metricTile(
                title: "Event Tap",
                value: eventTapManager.isRunning ? "Running" : "Stopped",
                symbol: eventTapManager.isRunning ? "dot.radiowaves.left.and.right" : "slash.circle",
                tint: eventTapManager.isRunning ? .blue : .secondary
            )
            metricTile(
                title: "Touch Devices",
                value: "\(deviceManager.totalDeviceCount)",
                symbol: "hand.tap",
                tint: .blue
            )
            metricTile(
                title: "Mappings",
                value: "\(appModel.trackpadCommandCount + appModel.magicMouseCommandCount + appModel.recognitionCommandCount)",
                symbol: "square.grid.2x2",
                tint: .mint
            )
        }
    }

    private var activeAppRoutingCard: some View {
        JitouchSurfaceCard(
            title: "Active App Routing",
            subtitle: "Shows the last non-Jitouch frontmost app and the gesture profiles currently matched for it.",
            symbol: "app.badge.checkmark",
            tint: .mint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    applicationIconBadge(path: commandExecutor.activeApplicationDisplayPath)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commandExecutor.activeApplicationDisplayName)
                            .font(.subheadline.weight(.semibold))

                        Text(
                            commandExecutor.activeApplicationDisplayPath == nil
                                ? "Keeping the most recent external app in view while the menu bar panel is open."
                                : (commandExecutor.activeApplicationDisplayPath ?? "")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }

                    Spacer(minLength: 12)
                }

                routingRow(
                    title: "Trackpad",
                    preview: commandExecutor.activeProfilePreview(for: .trackpad),
                    isEnabled: appModel.settings.trackpadEnabled,
                    tint: .blue
                )

                routingRow(
                    title: "Magic Mouse",
                    preview: commandExecutor.activeProfilePreview(for: .magicMouse),
                    isEnabled: appModel.settings.magicMouseEnabled,
                    tint: .teal
                )
            }
        }
    }

    private var runtimeActions: some View {
        JitouchSurfaceCard(
            title: "Quick Actions",
            subtitle: "Maintenance actions for reloading preferences, restarting hooks, and handling Accessibility setup.",
            symbol: "bolt.circle",
            tint: .blue
        ) {
            HStack(spacing: 10) {
                Button("Reload Preferences") {
                    appModel.refresh()
                }
                .buttonStyle(.bordered)

                Button("Restart Services") {
                    appModel.restartRuntimeServices()
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button(appModel.accessibilityGranted ? "Re-check Access" : "Request Access") {
                    if appModel.accessibilityGranted {
                        appModel.restartEventTap()
                    } else {
                        appModel.requestAccessibilityPermission()
                        appModel.refresh()
                    }
                }
                .buttonStyle(.bordered)

                Button("Open Accessibility") {
                    appModel.openAccessibilitySystemSettings()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var launchAtLoginCard: some View {
        JitouchSurfaceCard(
            title: "Startup",
            subtitle: appModel.launchAtLoginStatus.detail,
            symbol: "power.circle",
            tint: .teal
        ) {
            Toggle("Launch Jitouch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
            Text(appModel.launchAtLoginStatus.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var activityCard: some View {
        JitouchSurfaceCard(
            title: "Activity",
            subtitle: "Latest runtime state from the Swift engine, command executor, and recognizers.",
            symbol: "waveform.path.ecg",
            tint: .purple
        ) {
            LabeledContent("Runtime", value: appModel.runtimeStatusSummary)
            LabeledContent("Last Command", value: commandExecutor.lastExecutedCommandSummary)
            LabeledContent("Last Gesture", value: appModel.lastRecognizedGestureSummary)
        }
    }

    private func attentionCard(
        title: String,
        message: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.headline)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricTile(
        title: String,
        value: String,
        symbol: String,
        tint: Color
    ) -> some View {
        JitouchMetricTile(
            title: title,
            value: value,
            symbol: symbol,
            tint: tint
        )
    }

    private func routingRow(
        title: String,
        preview: ActiveProfilePreview?,
        isEnabled: Bool,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                if !isEnabled {
                    JitouchStatusBadge(title: "Disabled", tint: .secondary)
                } else if preview?.isOverride == true {
                    JitouchStatusBadge(title: "Override", tint: tint)
                } else {
                    JitouchStatusBadge(title: "Default", tint: .secondary)
                }

                Spacer()
            }

            if let preview {
                Text(preview.profileTitle)
                    .font(.caption.weight(.semibold))

                Text(preview.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No profile available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func applicationIconBadge(path: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.mint.opacity(0.14))

            if let icon = applicationIcon(for: path) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(7)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.mint)
            }
        }
        .frame(width: 40, height: 40)
    }

    private func applicationIcon(for path: String?) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }

        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardizedPath) else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: standardizedPath)
        icon.size = NSSize(width: 36, height: 36)
        return icon
    }

    private var cardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor).opacity(0.96)
    }
}
