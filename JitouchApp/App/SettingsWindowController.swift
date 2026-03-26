import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private enum Layout {
        static let defaultContentSize = NSSize(width: 1520, height: 920)
        static let minimumContentSize = NSSize(width: 1440, height: 860)
    }

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
        window.setContentSize(Layout.defaultContentSize)
        window.contentMinSize = Layout.minimumContentSize
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: Layout.minimumContentSize)).size
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
