import SwiftUI

struct DeviceSettingsTab<
    RuleWorkspaceContent: View
>: View {
    let device: CommandDevice
    let title: String
    let subtitle: String
    let mappingCount: Int
    let connectedDeviceCount: Int
    @Binding var isProfilesEnabled: Bool
    let ruleWorkspace: RuleWorkspaceContent

    init(
        device: CommandDevice,
        title: String,
        subtitle: String,
        mappingCount: Int,
        connectedDeviceCount: Int,
        isProfilesEnabled: Binding<Bool>,
        @ViewBuilder ruleWorkspace: () -> RuleWorkspaceContent
    ) {
        self.device = device
        self.title = title
        self.subtitle = subtitle
        self.mappingCount = mappingCount
        self.connectedDeviceCount = connectedDeviceCount
        self._isProfilesEnabled = isProfilesEnabled
        self.ruleWorkspace = ruleWorkspace()
    }

    var body: some View {
        SettingsPageScaffold(title: title, subtitle: subtitle) {
            summaryCard
            ruleWorkspace
        }
    }

    private var summaryCard: some View {
        JitouchSurfaceCard(
            title: summaryTitle,
            subtitle: summarySubtitle,
            symbol: summarySymbol,
            tint: summaryTint
        ) {
            Toggle("Enable \(device.title) Profiles", isOn: $isProfilesEnabled)

            SettingsMetricsGrid {
                JitouchMetricTile(
                    title: "Mappings",
                    value: "\(mappingCount)",
                    detail: "Loaded from the legacy command store and editable in-place.",
                    symbol: "square.grid.2x2",
                    tint: summaryTint
                )
                JitouchMetricTile(
                    title: "Connected Devices",
                    value: "\(connectedDeviceCount)",
                    detail: connectedDeviceCount == 0
                        ? "No matching device detected right now."
                        : "Hardware is visible to the runtime.",
                    symbol: "dot.radiowaves.left.and.right",
                    tint: connectedDeviceCount == 0 ? .orange : .green
                )
            }
        }
    }

    private var summaryTitle: String {
        device == .trackpad ? "Trackpad Runtime" : "Magic Mouse Runtime"
    }

    private var summarySubtitle: String {
        switch device {
        case .trackpad:
            "Trackpad tap, swipe, fix-finger, pinch, move/resize, tab switch, and drawing recognition now live in the standalone app."
        case .magicMouse:
            "Magic Mouse taps, swipes, slides, thumb gestures, V-shape, pinch, and drag recognition now live in the standalone app."
        case .recognition:
            "Recognition profiles are handled in their own page."
        }
    }

    private var summarySymbol: String {
        device == .trackpad ? "rectangle.and.hand.point.up.left" : "mouse"
    }

    private var summaryTint: Color {
        device == .trackpad ? .blue : .mint
    }
}
