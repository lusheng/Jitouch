import ApplicationServices
import Foundation
import Observation

enum EventTapError: LocalizedError {
    case accessibilityNotGranted
    case tapCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            "Accessibility permission is required before Jitouch can intercept mouse events."
        case .tapCreationFailed:
            "CGEventTapCreate returned nil."
        }
    }
}

@MainActor
@Observable
final class EventTapManager {
    private(set) var isRunning = false
    private(set) var observedEventCount = 0
    private(set) var recoveryCount = 0
    private(set) var lastObservedEventType: CGEventType?
    private(set) var lastError: String?

    var onMouseEvent: ((CGEvent, CGEventType) -> CGEvent?)? {
        didSet {
            activeMouseEventHandler = onMouseEvent
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var statusText: String {
        if isRunning {
            return "Running"
        }
        return lastError ?? "Stopped"
    }

    func start() throws {
        guard AXIsProcessTrusted() else {
            lastError = EventTapError.accessibilityNotGranted.localizedDescription
            throw EventTapError.accessibilityNotGranted
        }

        stop()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: jitouchEventTapCallback,
            userInfo: nil
        ) else {
            lastError = EventTapError.tapCreationFailed.localizedDescription
            throw EventTapError.tapCreationFailed
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource
        activeEventTapManager = self
        activeMouseEventHandler = onMouseEvent
        isRunning = true
        lastError = nil
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        isRunning = false
        activeMouseEventHandler = nil
        if activeEventTapManager === self {
            activeEventTapManager = nil
        }
    }

    func restart() {
        do {
            try start()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func recordObservedEvent(type: CGEventType) {
        lastObservedEventType = type
        observedEventCount += 1
    }

    func recoverIfNeeded(after type: CGEventType) {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        recoveryCount += 1
        lastObservedEventType = type
        lastError = nil
    }

    private var eventMask: CGEventMask {
        [
            CGEventType.scrollWheel,
            .mouseMoved,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .otherMouseDown,
            .otherMouseUp,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
        ].reduce(into: CGEventMask(0)) { mask, type in
            mask |= CGEventMask(1) << type.rawValue
        }
    }
}

nonisolated(unsafe) private var activeEventTapManager: EventTapManager?
nonisolated(unsafe) private var activeMouseEventHandler: ((CGEvent, CGEventType) -> CGEvent?)?

private func jitouchEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in
            activeEventTapManager?.recoverIfNeeded(after: type)
        }
        return Unmanaged.passUnretained(event)
    }

    Task { @MainActor in
        activeEventTapManager?.recordObservedEvent(type: type)
    }

    guard let forwardedEvent = activeMouseEventHandler?(event, type) else {
        return nil
    }

    return Unmanaged.passUnretained(forwardedEvent)
}
