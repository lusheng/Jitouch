import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let appModel: JitouchAppModel
    private var windowController: NSWindowController?

    init(appModel: JitouchAppModel) {
        self.appModel = appModel
    }

    func present() {
        let controller = windowController ?? makeWindowController()
        windowController = controller

        if let hostingController = controller.contentViewController as? NSHostingController<AnyView> {
            hostingController.rootView = AnyView(rootView)
        } else {
            controller.contentViewController = NSHostingController(rootView: AnyView(rootView))
        }

        guard let window = controller.window else { return }
        if !window.isVisible {
            window.center()
        }

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindowController() -> NSWindowController {
        let hostingController = NSHostingController(rootView: AnyView(rootView))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Jitouch Settings"
        window.identifier = NSUserInterfaceItemIdentifier("JitouchSettingsWindow")
        window.setContentSize(NSSize(width: 1160, height: 800))
        window.minSize = NSSize(width: 980, height: 720)
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        return NSWindowController(window: window)
    }

    private var rootView: some View {
        SettingsRootView()
            .environment(appModel)
            .environment(appModel.deviceManager)
            .environment(appModel.eventTapManager)
            .environment(appModel.commandExecutor)
    }
}
