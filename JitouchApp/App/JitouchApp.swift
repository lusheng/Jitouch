import SwiftUI

@main
struct JitouchApp: App {
    @State private var appModel = JitouchAppModel()

    var body: some Scene {
        MenuBarExtra("Jitouch", systemImage: appModel.menuBarSymbolName) {
            MenuBarContentView()
                .environment(appModel)
                .environment(appModel.deviceManager)
                .environment(appModel.eventTapManager)
                .environment(appModel.commandExecutor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environment(appModel)
                .environment(appModel.deviceManager)
                .environment(appModel.eventTapManager)
                .environment(appModel.commandExecutor)
        }
    }
}
