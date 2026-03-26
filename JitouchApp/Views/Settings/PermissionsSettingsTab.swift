import SwiftUI

struct PermissionsSettingsTab: View {
    let accessibilityGranted: Bool
    let accessibilityStatusText: String
    let accessibilityGuidance: String
    let launchAtLoginStatus: LaunchAtLoginStatusSnapshot
    @Binding var launchAtLoginEnabled: Bool
    let onPromptForAccess: () -> Void
    let onOpenAccessibilitySettings: () -> Void
    let onOpenLoginItemsSettings: () -> Void

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.permissions.title,
            subtitle: JitouchSettingsPane.permissions.subtitle
        ) {
            accessibilityPermissionCard
            launchAtLoginCard
        }
    }

    private var accessibilityPermissionCard: some View {
        JitouchSurfaceCard(
            title: "Accessibility Permission",
            subtitle: "macOS must trust Jitouch before event taps, shortcuts, and AX window actions can work.",
            symbol: "lock.shield",
            tint: accessibilityGranted ? .green : .orange,
            accessory: {
                JitouchStatusBadge(
                    title: accessibilityStatusText,
                    tint: accessibilityGranted ? .green : .orange
                )
            }
        ) {
            Text(accessibilityGuidance)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Prompt for Access", action: onPromptForAccess)
                    .buttonStyle(.borderedProminent)

                Button("Open Accessibility Settings", action: onOpenAccessibilitySettings)
                    .buttonStyle(.bordered)
            }

            if !accessibilityGranted {
                Text("After macOS opens Privacy & Security, enable Jitouch in Accessibility and then come back here to restart services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var launchAtLoginCard: some View {
        JitouchSurfaceCard(
            title: "Launch at Login",
            subtitle: "Start the standalone app automatically after login using ServiceManagement.",
            symbol: "power.circle",
            tint: .teal,
            accessory: {
                JitouchStatusBadge(
                    title: launchAtLoginStatus.title,
                    tint: launchAtLoginStatus.isEnabled ? .green : .secondary
                )
            }
        ) {
            Toggle("Start Jitouch automatically after login", isOn: $launchAtLoginEnabled)

            Text(launchAtLoginStatus.detail)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Open Login Items Settings", action: onOpenLoginItemsSettings)
                    .buttonStyle(.bordered)

                if launchAtLoginStatus.requiresApproval {
                    Text("Approval is still pending in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text("Debug builds can still report unavailable or approval-needed states because `SMAppService` behaves best with a properly signed app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
