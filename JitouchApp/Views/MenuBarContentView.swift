import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(JitouchAppModel.self) private var appModel
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(EventTapManager.self) private var eventTapManager
    @Environment(CommandExecutor.self) private var commandExecutor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appModel.settings.isEnabled ? "Jitouch is enabled" : "Jitouch is paused")
                .font(.headline)

            Text(
                appModel.accessibilityGranted
                    ? "Accessibility access is available."
                    : "Accessibility access is still required before gestures can drive apps."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(appModel.runtimeStatusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(appModel.settings.isEnabled ? "Turn Jitouch Off" : "Turn Jitouch On") {
                appModel.setEnabled(!appModel.settings.isEnabled)
            }

            SettingsLink {
                Label("Preferences…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Reload Legacy Settings") {
                appModel.refresh()
            }

            Button("Restart Runtime Services") {
                appModel.restartRuntimeServices()
            }

            Button(appModel.accessibilityGranted ? "Re-check Accessibility" : "Request Accessibility Access") {
                if appModel.accessibilityGranted {
                    appModel.restartEventTap()
                } else {
                    appModel.requestAccessibilityPermission()
                    appModel.refresh()
                }
            }

            Divider()

            LabeledContent("Trackpad Commands", value: "\(appModel.trackpadCommandCount)")
            LabeledContent("Magic Mouse Commands", value: "\(appModel.magicMouseCommandCount)")
            LabeledContent("Drawn Gestures", value: "\(appModel.recognitionCommandCount)")
            LabeledContent("Touch Devices", value: "\(deviceManager.totalDeviceCount)")
            LabeledContent("Event Tap", value: eventTapManager.isRunning ? "Running" : "Stopped")
            LabeledContent("Last Command", value: commandExecutor.lastExecutedCommandSummary)

            Divider()

            Button("Quit Jitouch") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(14)
        .frame(width: 320)
    }
}
