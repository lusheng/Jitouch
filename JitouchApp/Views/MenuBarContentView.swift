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

    private let panelWidth: CGFloat = 356

    var body: some View {
        ZStack {
            panelBackground

            VStack(alignment: .leading, spacing: 12) {
                topPanel

                if !appModel.accessibilityGranted {
                    compactNoticeCard(
                        title: "Accessibility Required",
                        message: "Grant access before Jitouch can run shortcuts and window actions.",
                        symbol: "lock.shield",
                        tint: .orange,
                        actionTitle: "Open Settings"
                    ) {
                        appModel.openAccessibilitySystemSettings()
                    }
                } else if appModel.shouldShowSetupGuide {
                    compactNoticeCard(
                        title: "Setup Guide Ready",
                        message: "Open the guided setup if you want a quick readiness pass.",
                        symbol: "figure.walk.motion",
                        tint: .blue,
                        actionTitle: "Open Guide"
                    ) {
                        appModel.presentOnboarding()
                        appModel.openSettingsWindowFromMenuBar()
                    }
                }

                focusedAppCard
                runtimeCard
                actionPanel
                footerBar
            }
            .padding(14)
        }
        .frame(width: panelWidth, alignment: .topLeading)
    }

    private var topPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    HStack(alignment: .firstTextBaseline) {
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
                            ? "Ready for daily use."
                            : "Paused until you enable it again."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Toggle("Enable Jitouch", isOn: enabledBinding)
                    .toggleStyle(.switch)

                Spacer(minLength: 8)

                Button(appModel.settings.isEnabled ? "Pause" : "Resume") {
                    appModel.setEnabled(!appModel.settings.isEnabled)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var focusedAppCard: some View {
        JitouchSurfaceCard(
            title: "Focused App",
            subtitle: "The last non-Jitouch app Jitouch will route gestures against.",
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
                                ? "Keeping the most recent external app in view while the panel is open."
                                : (commandExecutor.activeApplicationDisplayPath ?? "")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    }

                    Spacer(minLength: 12)
                }

                HStack(spacing: 10) {
                    routingMetric(
                        title: "Trackpad",
                        preview: commandExecutor.activeProfilePreview(for: .trackpad),
                        isEnabled: appModel.settings.trackpadEnabled,
                        tint: .blue
                    )

                    routingMetric(
                        title: "Magic Mouse",
                        preview: commandExecutor.activeProfilePreview(for: .magicMouse),
                        isEnabled: appModel.settings.magicMouseEnabled,
                        tint: .teal
                    )
                }
            }
        }
    }

    private var runtimeCard: some View {
        JitouchSurfaceCard(
            title: "Runtime Snapshot",
            subtitle: "A compact read on health, device visibility, and recent activity.",
            symbol: "waveform.path.ecg",
            tint: .blue
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                JitouchInlineMetric(
                    label: "Accessibility",
                    value: appModel.accessibilityStatusText,
                    tint: appModel.accessibilityGranted ? .green : .orange
                )
                JitouchInlineMetric(
                    label: "Event Tap",
                    value: eventTapManager.isRunning ? "Running" : "Stopped",
                    tint: eventTapManager.isRunning ? .blue : .secondary
                )
                JitouchInlineMetric(
                    label: "Devices",
                    value: "\(deviceManager.totalDeviceCount)",
                    tint: .mint
                )
                JitouchInlineMetric(
                    label: "Mappings",
                    value: "\(appModel.trackpadCommandCount + appModel.magicMouseCommandCount + appModel.recognitionCommandCount)",
                    tint: .purple
                )
            }

            Divider()

            compactInfoRow(title: "Last Command", value: commandExecutor.lastExecutedCommandSummary)
            compactInfoRow(title: "Last Gesture", value: appModel.lastRecognizedGestureSummary)
        }
    }

    private var actionPanel: some View {
        JitouchSurfaceCard(
            title: "Actions",
            subtitle: "Only the controls you’re likely to need from the menu bar.",
            symbol: "bolt.circle",
            tint: .indigo
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                compactActionButton(title: "Open Settings", symbol: "slider.horizontal.3") {
                    appModel.openSettingsWindowFromMenuBar()
                }

                compactActionButton(title: "Restart Runtime", symbol: "arrow.clockwise.circle") {
                    appModel.restartRuntimeServices()
                }

                compactActionButton(
                    title: appModel.accessibilityGranted ? "Open Accessibility" : "Grant Accessibility",
                    symbol: appModel.accessibilityGranted ? "lock.open" : "lock.shield"
                ) {
                    if appModel.accessibilityGranted {
                        appModel.openAccessibilitySystemSettings()
                    } else {
                        appModel.requestAccessibilityPermission()
                        appModel.refresh()
                    }
                }

                compactActionButton(title: "Reload Preferences", symbol: "tray.and.arrow.down") {
                    appModel.refresh()
                }
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appModel.launchAtLoginStatus.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(appModel.runtimeStatusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func compactNoticeCard(
        title: String,
        message: String,
        symbol: String,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        JitouchSurfaceCard(
            title: title,
            subtitle: message,
            symbol: symbol,
            tint: tint
        ) {
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
    }

    private func routingMetric(
        title: String,
        preview: ActiveProfilePreview?,
        isEnabled: Bool,
        tint: Color
    ) -> some View {
        let value: String
        let effectiveTint: Color

        if !isEnabled {
            value = "Disabled"
            effectiveTint = .secondary
        } else if let preview, preview.isOverride {
            value = preview.profileApplication
            effectiveTint = tint
        } else if preview != nil {
            value = "All Applications"
            effectiveTint = .secondary
        } else {
            value = "Unavailable"
            effectiveTint = .secondary
        }

        return JitouchInlineMetric(
            label: title,
            value: value,
            tint: effectiveTint
        )
    }

    private func compactInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    private func compactActionButton(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.983, green: 0.986, blue: 0.992),
                        Color(red: 0.971, green: 0.976, blue: 0.986),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.045), lineWidth: 1)
            )
    }
}
