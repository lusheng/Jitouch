import AppKit
import ApplicationServices
import Carbon
import Foundation
import Observation

struct ResolvedGestureCommand {
    let event: GestureEvent
    let gestureName: String
    let device: CommandDevice
    let applicationName: String
    let command: GestureCommand
}

private struct ActiveApplicationContext {
    let name: String
    let path: String?
}

@MainActor
@Observable
final class CommandExecutor {
    private let keyboard = KeyboardSimulationService()
    private let workspace = NSWorkspace.shared
    private let moveResizeOverlay = MoveResizeOverlayController()
    private let commandFeedbackOverlay = CommandFeedbackOverlayController()

    private(set) var lastExecutedCommandSummary = "No commands executed yet"
    private(set) var lastResolutionSummary = "No gesture-command resolution yet"
    private(set) var lastError: String?

    private var savedWindowFrames: [pid_t: CGRect] = [:]
    private var moveResizeSession: MoveResizeSession?
    private var isThumbMiddleClickHeld = false
    private var mouseEventHandlerID: UUID?

    func installEventTapHandler(on eventTapManager: EventTapManager) {
        activeMoveResizeExecutor = self
        if let mouseEventHandlerID {
            eventTapManager.removeMouseEventHandler(mouseEventHandlerID)
        }
        mouseEventHandlerID = eventTapManager.addMouseEventHandler(jitouchCommandExecutorMouseEventHandler)
    }

    func cancelTransientState() {
        endMoveResize(summary: "Move / Resize Cancelled", clearError: false)
        releaseHeldMouseButtons()
    }

    func execute(event: GestureEvent, settings: JitouchSettings) {
        guard let resolution = resolve(event: event, settings: settings) else {
            lastResolutionSummary = "No mapping for \(event.debugName)"
            return
        }

        lastResolutionSummary = "\(resolution.gestureName) -> \(resolution.command.command) (\(resolution.applicationName))"

        switch event {
        case let .moveResize(phase), let .mmVShapeMoveResize(phase):
            if resolution.command.isAction, resolution.command.command == "Move / Resize" {
                handleMoveResize(phase)
                return
            }
            if case .began = phase {
                break
            }
            return
        case let .mmThumb(phase):
            if resolution.command.isAction, resolution.command.command == "Middle Click" {
                handleMagicMouseThumbMiddleClick(phase)
                return
            }
            if phase == .ended {
                return
            }
        default:
            break
        }

        if resolution.command.isAction {
            executeAction(resolution)
        } else {
            executeShortcut(resolution.command)
            lastExecutedCommandSummary = "Shortcut \(resolution.command.keyCode) for \(resolution.applicationName)"
            lastError = nil
        }
    }

    private func resolve(event: GestureEvent, settings: JitouchSettings) -> ResolvedGestureCommand? {
        guard
            let gestureName = event.legacyGestureName,
            let device = event.commandDevice
        else {
            return nil
        }

        let applicationContext = currentApplicationContext()
        let applicationName = applicationContext.name
        let candidates = candidateApplicationNames(for: applicationName)
        let commandSets = settings.commandSets[device, default: []]

        for appSet in matchingCommandSets(
            in: commandSets,
            candidates: candidates,
            activePath: applicationContext.path
        ) {
            if let command = appSet.gestures.first(where: { $0.gesture == gestureName && $0.isEnabled }) {
                return ResolvedGestureCommand(
                    event: event,
                    gestureName: gestureName,
                    device: device,
                    applicationName: applicationName,
                    command: command
                )
            }

            if let fallback = appSet.gestures.first(where: { $0.gesture == CommandCatalog.allUnassignedGesture && $0.isEnabled }) {
                return ResolvedGestureCommand(
                    event: event,
                    gestureName: gestureName,
                    device: device,
                    applicationName: applicationName,
                    command: fallback
                )
            }
        }

        return nil
    }

    private func executeAction(_ resolution: ResolvedGestureCommand) {
        let command = resolution.command.command

        switch command {
        case "-":
            lastExecutedCommandSummary = "Ignored placeholder action"
            lastError = nil
        case "Next Tab":
            keyboard.sendKeyCode(CGKeyCode(kVK_Tab), modifiers: [.maskControl])
            recordExecuted("Next Tab")
        case "Previous Tab":
            keyboard.sendKeyCode(CGKeyCode(kVK_Tab), modifiers: [.maskControl, .maskShift])
            recordExecuted("Previous Tab")
        case "Open Link in New Tab":
            commandClick(button: .left, flags: .maskCommand)
            recordExecuted("Open Link in New Tab")
        case "Full Screen":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_F), modifiers: [.maskCommand, .maskControl])
            recordExecuted("Full Screen")
        case "Open Recently Closed Tab":
            if resolution.applicationName == "Safari" {
                keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_Z), modifiers: [.maskCommand])
            } else {
                keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_T), modifiers: [.maskCommand, .maskShift])
            }
            recordExecuted("Open Recently Closed Tab")
        case "Close / Close Tab":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_W), modifiers: [.maskCommand])
            recordExecuted("Close / Close Tab")
        case "Quit":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_Q), modifiers: [.maskCommand])
            recordExecuted("Quit")
        case "Hide":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_H), modifiers: [.maskCommand])
            recordExecuted("Hide")
        case "Minimize":
            if minimizeFocusedWindow() {
                recordExecuted("Minimize")
            } else {
                recordFailed("Minimize", reason: "Unable to locate a focused window.")
            }
        case "Zoom":
            if zoomFocusedWindow() {
                recordExecuted("Zoom")
            } else {
                recordFailed("Zoom", reason: "Unable to press the focused window's zoom button.")
            }
        case "Un-Maximize":
            if restoreFocusedWindow() {
                recordExecuted("Un-Maximize")
            } else {
                recordFailed("Un-Maximize", reason: "No saved window frame is available yet.")
            }
        case "Maximize":
            if resizeFocusedWindow(mode: .fullscreen) {
                recordExecuted("Maximize")
            } else {
                recordFailed("Maximize", reason: "Unable to resize the focused window.")
            }
        case "Maximize Left":
            if resizeFocusedWindow(mode: .leftHalf) {
                recordExecuted("Maximize Left")
            } else {
                recordFailed("Maximize Left", reason: "Unable to resize the focused window.")
            }
        case "Maximize Right":
            if resizeFocusedWindow(mode: .rightHalf) {
                recordExecuted("Maximize Right")
            } else {
                recordFailed("Maximize Right", reason: "Unable to resize the focused window.")
            }
        case "Copy":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_C), modifiers: [.maskCommand])
            recordExecuted("Copy")
        case "Paste":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_V), modifiers: [.maskCommand])
            recordExecuted("Paste")
        case "New":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_N), modifiers: [.maskCommand])
            recordExecuted("New")
        case "New Tab":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_T), modifiers: [.maskCommand])
            recordExecuted("New Tab")
        case "Open":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_O), modifiers: [.maskCommand])
            recordExecuted("Open")
        case "Save":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_S), modifiers: [.maskCommand])
            recordExecuted("Save")
        case "Launch Finder":
            workspace.open(URL(fileURLWithPath: NSHomeDirectory()))
            recordExecuted("Launch Finder")
        case "Launch Browser":
            if launchBrowser() {
                recordExecuted("Launch Browser")
            } else {
                recordFailed("Launch Browser", reason: "Unable to open the default browser.")
            }
        case "Middle Click":
            commandClick(button: .center)
            recordExecuted("Middle Click")
        case "Show Desktop":
            CoreDockSendNotification("com.apple.showdesktop.awake" as CFString)
            recordExecuted("Show Desktop")
        case "Application Windows":
            CoreDockSendNotification("com.apple.expose.front.awake" as CFString)
            recordExecuted("Application Windows")
        case "Mission Control":
            CoreDockSendNotification("com.apple.expose.awake" as CFString)
            recordExecuted("Mission Control")
        case "Launchpad":
            CoreDockSendNotification("com.apple.launchpad.toggle" as CFString)
            recordExecuted("Launchpad")
        case "Left Click":
            commandClick(button: .left)
            recordExecuted("Left Click")
        case "Right Click":
            commandClick(button: .right)
            recordExecuted("Right Click")
        case "Refresh":
            keyboard.sendKeyCode(CGKeyCode(kVK_ANSI_R), modifiers: [.maskCommand])
            recordExecuted("Refresh")
        case "Scroll to Top":
            keyboard.sendKeyCode(CGKeyCode(kVK_Home))
            recordExecuted("Scroll to Top")
        case "Scroll to Bottom":
            keyboard.sendKeyCode(CGKeyCode(kVK_End))
            recordExecuted("Scroll to Bottom")
        case "Application Switcher":
            CoreDockSendNotification("com.apple.appswitcher.awake" as CFString)
            recordExecuted("Application Switcher")
        case "Play / Pause":
            keyboard.sendSpecialKey(NX_KEYTYPE_PLAY)
            recordExecuted("Play / Pause")
        case "Next":
            keyboard.sendSpecialKey(NX_KEYTYPE_NEXT)
            recordExecuted("Next")
        case "Previous":
            keyboard.sendSpecialKey(NX_KEYTYPE_PREVIOUS)
            recordExecuted("Previous")
        case "Volume Up":
            keyboard.sendSpecialKey(NX_KEYTYPE_SOUND_UP)
            recordExecuted("Volume Up")
        case "Volume Down":
            keyboard.sendSpecialKey(NX_KEYTYPE_SOUND_DOWN)
            recordExecuted("Volume Down")
        case "Brightness Up":
            keyboard.sendSpecialKey(NX_KEYTYPE_BRIGHTNESS_UP)
            recordExecuted("Brightness Up")
        case "Brightness Down":
            keyboard.sendSpecialKey(NX_KEYTYPE_BRIGHTNESS_DOWN)
            recordExecuted("Brightness Down")
        default:
            if let openFilePath = resolution.command.openFilePath {
                if openFile(at: openFilePath) {
                    recordExecuted("Open File")
                }
            } else if let openURL = resolution.command.openURL, let url = URL(string: openURL) {
                if workspace.open(url) {
                    recordExecuted("Open URL")
                } else {
                    recordFailed("Open URL", reason: "Unable to open \(openURL)")
                }
            } else {
                recordFailed(command, reason: "Action is not implemented yet.")
            }
        }
    }

    private func executeShortcut(_ command: GestureCommand) {
        keyboard.sendKeyCode(
            CGKeyCode(command.keyCode),
            modifiers: CGEventFlags(rawValue: UInt64(command.modifierFlags))
        )
    }

    private func currentApplicationContext() -> ActiveApplicationContext {
        let application = workspace.frontmostApplication
        return ActiveApplicationContext(
            name: application?.localizedName ?? "All Applications",
            path: standardizedApplicationPath(application?.bundleURL)
        )
    }

    private func candidateApplicationNames(for applicationName: String) -> [String] {
        let aliases: [String: String] = [
            "Google Chrome": "Chrome",
            "Microsoft Word": "Word",
        ]

        var names = [applicationName]
        if let alias = aliases[applicationName] {
            names.append(alias)
        }
        names.append("All Applications")
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private func matchingCommandSets(
        in commandSets: [ApplicationCommandSet],
        candidates: [String],
        activePath: String?
    ) -> [ApplicationCommandSet] {
        var results: [ApplicationCommandSet] = []

        if let activePath {
            results.append(contentsOf: commandSets.filter {
                standardizedApplicationPath($0.path) == activePath
            })
        }

        for candidate in candidates where candidate != "All Applications" {
            results.append(contentsOf: commandSets.filter {
                $0.application == candidate &&
                (
                    $0.path.isEmpty ||
                    standardizedApplicationPath($0.path) == activePath
                )
            })
        }

        results.append(contentsOf: commandSets.filter { $0.application == "All Applications" })

        var uniqueResults: [ApplicationCommandSet] = []
        var seenIDs = Set<String>()
        for set in results where seenIDs.insert(set.id).inserted {
            uniqueResults.append(set)
        }
        return uniqueResults
    }

    private func standardizedApplicationPath(_ url: URL?) -> String? {
        url?.standardizedFileURL.path
    }

    private func standardizedApplicationPath(_ path: String) -> String? {
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL.path
    }

    private func commandClick(button: CGMouseButton, flags: CGEventFlags = []) {
        postMouseButton(button: button, flags: flags, isDown: true)
        postMouseButton(button: button, flags: flags, isDown: false)
    }

    private func postMouseButton(button: CGMouseButton, flags: CGEventFlags = [], isDown: Bool) {
        let location = currentMouseLocation()

        let eventType: CGEventType
        let buttonNumber: Int64

        switch button {
        case .left:
            eventType = isDown ? .leftMouseDown : .leftMouseUp
            buttonNumber = 0
        case .right:
            eventType = isDown ? .rightMouseDown : .rightMouseUp
            buttonNumber = 1
        default:
            eventType = isDown ? .otherMouseDown : .otherMouseUp
            buttonNumber = 2
        }

        let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: location, mouseButton: button)
        event?.flags = flags
        event?.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
        event?.setIntegerValueField(.eventSourceUserData, value: jitouchSyntheticMouseEventUserData)
        event?.post(tap: .cghidEventTap)
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func launchBrowser() -> Bool {
        guard let markerURL = URL(string: "https://jitouch.app/") else {
            return false
        }
        return workspace.open(markerURL)
    }

    private func openFile(at path: String) -> Bool {
        let standardizedPath = NSString(string: path).expandingTildeInPath
        if FileManager.default.fileExists(atPath: standardizedPath) {
            return workspace.open(URL(fileURLWithPath: standardizedPath))
        } else {
            recordFailed("Open File", reason: "File does not exist: \(standardizedPath)")
            return false
        }
    }

    private func focusedApplication() -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            "AXFocusedApplication" as CFString,
            &value
        )
        guard result == .success else { return nil }
        return axElement(from: value)
    }

    private func focusedWindow() -> AXUIElement? {
        guard let application = focusedApplication() else { return nil }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            application,
            "AXFocusedWindow" as CFString,
            &value
        )
        guard result == .success else { return nil }
        return axElement(from: value)
    }

    private func minimizeFocusedWindow() -> Bool {
        guard let window = focusedWindow() else { return false }
        return AXUIElementSetAttributeValue(window, "AXMinimized" as CFString, kCFBooleanTrue) == .success
    }

    private func zoomFocusedWindow() -> Bool {
        guard let window = focusedWindow() else { return false }

        var zoomButtonValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXZoomButton" as CFString, &zoomButtonValue)
        guard result == .success, let zoomButton = axElement(from: zoomButtonValue) else { return false }
        return AXUIElementPerformAction(zoomButton, "AXPress" as CFString) == .success
    }

    private func resizeFocusedWindow(mode: WindowResizeMode) -> Bool {
        guard
            let window = focusedWindow(),
            let currentFrame = windowFrame(for: window),
            let targetFrame = targetFrame(for: mode)
        else {
            return false
        }

        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        savedWindowFrames[pid] = currentFrame
        return setWindowFrame(targetFrame, for: window)
    }

    private func restoreFocusedWindow() -> Bool {
        guard let window = focusedWindow() else { return false }
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        guard let savedFrame = savedWindowFrames[pid] else { return false }
        savedWindowFrames.removeValue(forKey: pid)
        return setWindowFrame(savedFrame, for: window)
    }

    private func windowFrame(for window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(window, "AXPosition" as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(window, "AXSize" as CFString, &sizeValue) == .success,
            let positionAXValue = axValue(from: positionValue, expectedType: .cgPoint),
            let sizeAXValue = axValue(from: sizeValue, expectedType: .cgSize)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionAXValue, .cgPoint, &position),
            AXValueGetValue(sizeAXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func setWindowFrame(_ frame: CGRect, for window: AXUIElement) -> Bool {
        var origin = frame.origin
        var size = frame.size

        guard
            let originValue = AXValueCreate(.cgPoint, &origin),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }

        let setPosition = AXUIElementSetAttributeValue(window, "AXPosition" as CFString, originValue)
        let setSize = AXUIElementSetAttributeValue(window, "AXSize" as CFString, sizeValue)
        return setPosition == .success && setSize == .success
    }

    private func handleMoveResize(_ phase: MoveResizePhase) {
        switch phase {
        case let .began(mode):
            if startMoveResize(mode: mode) {
                recordExecuted(mode == .move ? "Move Window Mode" : "Resize Window Mode")
            } else {
                recordFailed("Move / Resize", reason: "Unable to find a movable window under the mouse pointer.")
            }
        case .changed:
            guard moveResizeSession != nil else { return }
            if !updateMoveResize() {
                endMoveResize(summary: "Move / Resize Failed", clearError: false)
                recordFailed("Move / Resize", reason: "Window move/resize update failed.")
            }
        case .ended:
            guard moveResizeSession != nil else { return }
            endMoveResize(summary: "Move / Resize Ended", clearError: true)
            recordExecuted("Move / Resize Ended")
        }
    }

    private func startMoveResize(mode: MoveResizeMode) -> Bool {
        let baseMouseLocation = currentMouseLocation()
        let window = moveResizeSession?.window ?? windowUnderMouse() ?? focusedWindow()

        guard
            let window,
            let frame = windowFrame(for: window)
        else {
            return false
        }

        _ = AXUIElementPerformAction(window, "AXRaise" as CFString)
        moveResizeSession = MoveResizeSession(
            window: window,
            mode: mode,
            baseMouseLocation: baseMouseLocation,
            initialFrame: frame
        )
        setMoveResizeInterception(active: true)
        moveResizeOverlay.show(mode: mode, at: baseMouseLocation)
        return true
    }

    private func updateMoveResize() -> Bool {
        guard let session = moveResizeSession else { return false }

        let mouseLocation = currentMouseLocation()
        let deltaX = mouseLocation.x - session.baseMouseLocation.x
        let deltaY = mouseLocation.y - session.baseMouseLocation.y

        let targetFrame: CGRect
        switch session.mode {
        case .move:
            targetFrame = CGRect(
                origin: CGPoint(
                    x: session.initialFrame.origin.x + deltaX,
                    y: session.initialFrame.origin.y + deltaY
                ),
                size: session.initialFrame.size
            )
        case .resize:
            targetFrame = CGRect(
                origin: session.initialFrame.origin,
                size: CGSize(
                    width: max(160, session.initialFrame.size.width + deltaX),
                    height: max(120, session.initialFrame.size.height + deltaY)
                )
            )
        }

        moveResizeOverlay.update(mode: session.mode, at: mouseLocation)
        return setWindowFrame(targetFrame, for: session.window)
    }

    private func endMoveResize(summary: String?, clearError: Bool) {
        moveResizeSession = nil
        setMoveResizeInterception(active: false)
        moveResizeOverlay.hide()
        if let summary {
            lastExecutedCommandSummary = summary
        }
        if clearError {
            lastError = nil
        }
    }

    fileprivate func cancelMoveResizeFromMouseEvent() {
        guard moveResizeSession != nil else { return }
        endMoveResize(summary: "Move / Resize Cancelled", clearError: true)
    }

    private func handleMagicMouseThumbMiddleClick(_ phase: ThumbPhase) {
        switch phase {
        case .began:
            guard !isThumbMiddleClickHeld else { return }
            isThumbMiddleClickHeld = true
            postMouseButton(button: .center, isDown: true)
            recordExecuted("Thumb Middle Click Down")
        case .ended:
            guard isThumbMiddleClickHeld else { return }
            isThumbMiddleClickHeld = false
            postMouseButton(button: .center, isDown: false)
            recordExecuted("Thumb Middle Click Up")
        }
    }

    private func releaseHeldMouseButtons() {
        if isThumbMiddleClickHeld {
            isThumbMiddleClickHeld = false
            postMouseButton(button: .center, isDown: false)
        }
    }

    private func windowUnderMouse() -> AXUIElement? {
        let mouseLocation = currentMouseLocation()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(mouseLocation.x),
            Float(mouseLocation.y),
            &element
        )

        guard result == .success, let element else { return nil }
        return windowElement(containing: element)
    }

    private func windowElement(containing element: AXUIElement) -> AXUIElement? {
        if axStringAttribute("AXRole", of: element) == "AXWindow" {
            return element
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXWindow" as CFString, &value)
        guard result == .success else { return nil }
        return axElement(from: value)
    }

    private func axElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value as AnyObject, to: AXUIElement.self)
    }

    private func axValue(from value: CFTypeRef?, expectedType: AXValueType) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }

        let axValue = unsafeDowncast(value as AnyObject, to: AXValue.self)
        guard AXValueGetType(axValue) == expectedType else { return nil }
        return axValue
    }

    private func axStringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard
            result == .success,
            let value,
            CFGetTypeID(value) == CFStringGetTypeID()
        else {
            return nil
        }
        return value as? String
    }

    private func targetFrame(for mode: WindowResizeMode) -> CGRect? {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return nil }

        switch mode {
        case .fullscreen:
            return screenFrame
        case .leftHalf:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: screenFrame.midX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
        }
    }

    private func recordExecuted(_ action: String) {
        lastExecutedCommandSummary = action
        lastError = nil
        if shouldShowFeedback(for: action) {
            commandFeedbackOverlay.showSuccess(title: action)
        }
    }

    private func recordFailed(_ action: String, reason: String) {
        lastExecutedCommandSummary = action
        lastError = reason
        commandFeedbackOverlay.showFailure(title: action, detail: reason)
    }

    private func shouldShowFeedback(for action: String) -> Bool {
        switch action {
        case "Ignored placeholder action", "Thumb Middle Click Down", "Thumb Middle Click Up":
            false
        default:
            true
        }
    }
}

private enum WindowResizeMode {
    case fullscreen
    case leftHalf
    case rightHalf
}

private struct MoveResizeSession {
    let window: AXUIElement
    let mode: MoveResizeMode
    let baseMouseLocation: CGPoint
    let initialFrame: CGRect
}

nonisolated(unsafe) private var activeMoveResizeExecutor: CommandExecutor?
private let moveResizeInterceptionLock = NSLock()
nonisolated(unsafe) private var moveResizeInterceptionState = MoveResizeInterceptionState()

private struct MoveResizeInterceptionState {
    var isActive = false
    var swallowNextMouseUp = false
}

private func setMoveResizeInterception(active: Bool) {
    moveResizeInterceptionLock.lock()
    moveResizeInterceptionState.isActive = active
    if !active {
        moveResizeInterceptionState.swallowNextMouseUp = false
    }
    moveResizeInterceptionLock.unlock()
}

private func jitouchCommandExecutorMouseEventHandler(_ event: CGEvent, _ type: CGEventType) -> CGEvent? {
    moveResizeInterceptionLock.lock()
    let isActive = moveResizeInterceptionState.isActive
    let swallowNextMouseUp = moveResizeInterceptionState.swallowNextMouseUp

    switch type {
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
        if isActive {
            moveResizeInterceptionState.isActive = false
            moveResizeInterceptionState.swallowNextMouseUp = true
            moveResizeInterceptionLock.unlock()
            Task { @MainActor in
                activeMoveResizeExecutor?.cancelMoveResizeFromMouseEvent()
            }
            return nil
        }
    case .leftMouseUp, .rightMouseUp, .otherMouseUp:
        if swallowNextMouseUp {
            moveResizeInterceptionState.swallowNextMouseUp = false
            moveResizeInterceptionLock.unlock()
            return nil
        }
    default:
        break
    }

    moveResizeInterceptionLock.unlock()
    return event
}

extension GestureEvent {
    var commandDevice: CommandDevice? {
        switch self {
        case .mmOneFixOneTap, .mmTwoFingerSlide, .mmTwoFixOneSlide, .mmThumb, .mmPinch, .mmThreeFingerSwipe, .mmMiddleClick, .mmVShapeMoveResize:
            .magicMouse
        case .characterRecognized:
            .recognition
        default:
            .trackpad
        }
    }

    var legacyGestureName: String? {
        switch self {
        case .threeFingerTap:
            "Three-Finger Tap"
        case let .threeFingerSwipe(direction):
            "Three-Swipe-\(direction.legacyAxisName)"
        case .fourFingerTap:
            "Four-Finger Tap"
        case let .fourFingerSwipe(direction):
            "Four-Swipe-\(direction.legacyAxisName)"
        case let .oneFixOneTap(side):
            side == .left ? "One-Fix Left-Tap" : "One-Fix Right-Tap"
        case let .oneFixTwoSlide(direction):
            "One-Fix Two-Slide-\(direction.legacyAxisName)"
        case let .oneFixPressTwoSlide(direction):
            "One-Fix-Press Two-Slide-\(direction.legacyAxisName)"
        case .twoFixIndexDoubleTap:
            "Two-Fix Index-Double-Tap"
        case .twoFixMiddleDoubleTap:
            "Two-Fix Middle-Double-Tap"
        case .twoFixRingDoubleTap:
            "Two-Fix Ring-Double-Tap"
        case let .twoFixOneSlide(direction):
            "Two-Fix One-Slide-\(direction.legacyAxisName)"
        case let .threeFingerPinch(direction):
            direction == .outward ? "Three-Finger Pinch-Out" : "Three-Finger Pinch-In"
        case .moveResize:
            "One-Fix One-Slide"
        case let .tabSwitch(direction):
            direction == .pinkyToIndex ? "Pinky-To-Index" : "Index-To-Pinky"
        case let .characterRecognized(character):
            character.value
        case let .mmOneFixOneTap(kind):
            switch kind {
            case .middleFixIndexNear:
                "Middle-Fix Index-Near-Tap"
            case .middleFixIndexFar:
                "Middle-Fix Index-Far-Tap"
            case .indexFixMiddleNear:
                "Index-Fix Middle-Near-Tap"
            case .indexFixMiddleFar:
                "Index-Fix Middle-Far-Tap"
            }
        case let .mmTwoFingerSlide(kind):
            switch kind {
            case .middleFixIndexSlideOut:
                "Middle-Fix Index-Slide-Out"
            case .middleFixIndexSlideIn:
                "Middle-Fix Index-Slide-In"
            case .indexFixMiddleSlideIn:
                "Index-Fix Middle-Slide-In"
            case .indexFixMiddleSlideOut:
                "Index-Fix Middle-Slide-Out"
            }
        case let .mmTwoFixOneSlide(direction):
            "Two-Fix One-Slide-\(direction.legacyAxisName)"
        case .mmThumb:
            "Thumb"
        case let .mmPinch(direction):
            direction == .outward ? "Pinch Out" : "Pinch In"
        case let .mmThreeFingerSwipe(direction):
            "Three-Swipe-\(direction.legacyAxisName)"
        case .mmMiddleClick:
            "Middle Click"
        case .mmVShapeMoveResize:
            "V-Shape"
        }
    }

    var debugName: String {
        legacyGestureName ?? String(describing: self)
    }
}

private extension Direction {
    var legacyAxisName: String {
        switch self {
        case .left:
            "Left"
        case .right:
            "Right"
        case .up:
            "Up"
        case .down:
            "Down"
        }
    }
}
