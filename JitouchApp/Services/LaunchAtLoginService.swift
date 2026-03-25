import Foundation
import ServiceManagement

struct LaunchAtLoginStatusSnapshot: Sendable {
    let isEnabled: Bool
    let requiresApproval: Bool
    let title: String
    let detail: String
}

struct LaunchAtLoginService {
    private var service: SMAppService {
        SMAppService.mainApp
    }

    func status() -> LaunchAtLoginStatusSnapshot {
        snapshot(for: service.status)
    }

    func setEnabled(_ isEnabled: Bool) throws -> LaunchAtLoginStatusSnapshot {
        if isEnabled {
            try service.register()
        } else {
            try service.unregister()
        }
        return status()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func snapshot(for status: SMAppService.Status) -> LaunchAtLoginStatusSnapshot {
        switch status {
        case .enabled:
            LaunchAtLoginStatusSnapshot(
                isEnabled: true,
                requiresApproval: false,
                title: "Enabled",
                detail: "Jitouch is registered to launch when you log in."
            )
        case .requiresApproval:
            LaunchAtLoginStatusSnapshot(
                isEnabled: true,
                requiresApproval: true,
                title: "Needs Approval",
                detail: "macOS still needs approval in Login Items before Jitouch can auto-launch."
            )
        case .notFound:
            LaunchAtLoginStatusSnapshot(
                isEnabled: false,
                requiresApproval: false,
                title: "Unavailable",
                detail: "macOS could not find a valid login item for this build."
            )
        case .notRegistered:
            LaunchAtLoginStatusSnapshot(
                isEnabled: false,
                requiresApproval: false,
                title: "Disabled",
                detail: "Jitouch is not currently registered to launch at login."
            )
        @unknown default:
            LaunchAtLoginStatusSnapshot(
                isEnabled: false,
                requiresApproval: false,
                title: "Unknown",
                detail: "Login item status returned an unknown value."
            )
        }
    }
}
