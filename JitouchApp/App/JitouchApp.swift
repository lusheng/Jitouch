import SwiftUI

@main
struct JitouchApp: App {
    @State private var appModel: JitouchAppModel
    private let settingsWindowController: SettingsWindowController

    init() {
        let model = JitouchAppModel()
        let settingsWindowController = SettingsWindowController(appModel: model)
        _appModel = State(initialValue: model)
        self.settingsWindowController = settingsWindowController
        model.installSettingsWindowPresenter {
            settingsWindowController.present()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            model.performLaunchSetupRevealIfNeeded()
        }
    }

    var body: some Scene {
        MenuBarExtra("Jitouch", systemImage: appModel.menuBarSymbolName) {
            MenuBarContentView()
                .environment(appModel)
                .environment(appModel.deviceManager)
                .environment(appModel.eventTapManager)
                .environment(appModel.commandExecutor)
        }
        .menuBarExtraStyle(.window)
    }
}
