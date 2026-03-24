import AppKit
import Foundation
import IOKit
import Observation

struct ConnectedDevice: Identifiable, Hashable, Sendable {
    let id: String
    let familyID: Int
    let type: DeviceType
    var isRunning: Bool
    var registryName: String?

    var displayName: String {
        registryName ?? "\(type.rawValue.capitalized) family \(familyID)"
    }
}

@MainActor
@Observable
final class DeviceManager {
    private struct RegisteredDevice {
        let ref: MTDeviceRef
        let descriptor: ConnectedDevice
    }

    private(set) var trackpadDevices: [ConnectedDevice] = []
    private(set) var magicMouseDevices: [ConnectedDevice] = []
    private(set) var isRunning = false
    private(set) var lastRefreshDate: Date?
    private(set) var lastError: String?
    private(set) var lastEventDescription = "No touch frames yet"

    var trackpadHandler: ((TouchFrame) -> Void)? {
        didSet { activeTrackpadFrameHandler = trackpadHandler }
    }

    var mouseHandler: ((TouchFrame) -> Void)? {
        didSet { activeMouseFrameHandler = mouseHandler }
    }

    var totalDeviceCount: Int {
        trackpadDevices.count + magicMouseDevices.count
    }

    private var registeredDevices: [RegisteredDevice] = []
    private var deviceList: CFMutableArray?
    private var wakeObserver: NSObjectProtocol?

    private var notificationPort: IONotificationPortRef?
    private var notificationSource: CFRunLoopSource?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    func start(
        trackpadHandler: ((TouchFrame) -> Void)? = nil,
        mouseHandler: ((TouchFrame) -> Void)? = nil
    ) {
        self.trackpadHandler = trackpadHandler
        self.mouseHandler = mouseHandler

        guard !isRunning else {
            refreshDevicesNow()
            return
        }

        activeDeviceManager = self
        installWakeObserver()
        installHotPlugNotificationsIfNeeded()
        isRunning = true
        refreshDevicesNow()
    }

    func stop() {
        guard isRunning else { return }

        uninstallWakeObserver()
        uninstallHotPlugNotifications()
        stopRegisteredDevices()
        releaseDeviceList()
        activeTrackpadFrameHandler = nil
        activeMouseFrameHandler = nil
        activeDeviceManager = nil
        isRunning = false
        trackpadDevices = []
        magicMouseDevices = []
    }

    func restart() {
        stop()
        start(trackpadHandler: trackpadHandler, mouseHandler: mouseHandler)
    }

    func refreshDevicesNow() {
        guard isRunning else { return }

        stopRegisteredDevices()
        releaseDeviceList()

        guard let newDeviceList = MTDeviceCreateList()?.takeRetainedValue() else {
            lastError = "MTDeviceCreateList returned nil."
            trackpadDevices = []
            magicMouseDevices = []
            return
        }
        deviceList = newDeviceList

        let count = CFArrayGetCount(newDeviceList)
        var newTrackpads: [ConnectedDevice] = []
        var newMagicMice: [ConnectedDevice] = []

        for index in 0 ..< count {
            let rawDevice = CFArrayGetValueAtIndex(newDeviceList, index)
            let device = unsafeBitCast(rawDevice, to: MTDeviceRef.self)

            var familyID: Int32 = 0
            MTDeviceGetFamilyID(device, &familyID)
            let familyIDValue = Int(familyID)

            guard let deviceType = Self.classifyFamily(familyIDValue) else {
                continue
            }

            if deviceType == .trackpad {
                MTRegisterContactFrameCallback(device, jitouchTrackpadContactCallback)
            } else {
                MTRegisterContactFrameCallback(device, jitouchMagicMouseContactCallback)
            }
            MTDeviceStart(device, 0)

            let address = Self.deviceAddress(device)
            let descriptor = ConnectedDevice(
                id: address.map { String($0, radix: 16) } ?? UUID().uuidString,
                familyID: familyIDValue,
                type: deviceType,
                isRunning: MTDeviceIsRunning(device),
                registryName: nil
            )

            let registration = RegisteredDevice(ref: device, descriptor: descriptor)
            registeredDevices.append(registration)

            switch deviceType {
            case .trackpad:
                newTrackpads.append(descriptor)
            case .magicMouse:
                newMagicMice.append(descriptor)
            }
        }

        trackpadDevices = newTrackpads.sorted { $0.familyID < $1.familyID }
        magicMouseDevices = newMagicMice.sorted { $0.familyID < $1.familyID }
        lastRefreshDate = .now
        lastError = nil
    }

    func scheduleRescan(reason: String, attempt: Int = 0) {
        guard isRunning else { return }

        let delay = attempt == 0 ? 0.15 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.refreshDevicesNow()
            if self.totalDeviceCount == 0 && attempt < 2 {
                self.scheduleRescan(reason: reason, attempt: attempt + 1)
            }
        }
    }

    func recordTouchFrame(_ frame: TouchFrame) {
        lastEventDescription = "\(frame.deviceType.rawValue) \(frame.fingerCount) fingers @ \(frame.timestamp)"
    }

    nonisolated static func classifyFamily(_ familyID: Int) -> DeviceType? {
        if builtinTrackpadFamilies.contains(familyID) || magicTrackpadFamilies.contains(familyID) {
            return .trackpad
        }
        if magicMouseFamilies.contains(familyID) {
            return .magicMouse
        }
        if familyID >= minimumSupportedFamilyID {
            return .trackpad
        }
        return nil
    }

    private func stopRegisteredDevices() {
        for registration in registeredDevices {
            if registration.descriptor.type == .trackpad {
                MTUnregisterContactFrameCallback(registration.ref, jitouchTrackpadContactCallback)
            } else {
                MTUnregisterContactFrameCallback(registration.ref, jitouchMagicMouseContactCallback)
            }
            MTDeviceStop(registration.ref)
        }
        registeredDevices.removeAll()
    }

    private func installWakeObserver() {
        guard wakeObserver == nil else { return }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRescan(reason: "system wake")
            }
        }
    }

    private func uninstallWakeObserver() {
        guard let wakeObserver else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        self.wakeObserver = nil
    }

    private func installHotPlugNotificationsIfNeeded() {
        guard notificationPort == nil else { return }

        let port = IONotificationPortCreate(kIOMainPortDefault)
        notificationPort = port

        if let port, let runLoopSource = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            notificationSource = runLoopSource
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }

        guard let matchingDictionary = IOServiceNameMatching("AppleMultitouchDevice") else {
            lastError = "IOServiceNameMatching returned nil."
            return
        }

        IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchingDictionary,
            jitouchDeviceAddedNotification,
            nil,
            &addedIterator
        )
        drainIterator(addedIterator)

        guard let removedDictionary = IOServiceNameMatching("AppleMultitouchDevice") else {
            lastError = "IOServiceNameMatching returned nil for removal observer."
            return
        }
        IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            removedDictionary,
            jitouchDeviceRemovedNotification,
            nil,
            &removedIterator
        )
        drainIterator(removedIterator)
    }

    private func uninstallHotPlugNotifications() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let notificationSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), notificationSource, .defaultMode)
            self.notificationSource = nil
        }
        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
    }

    private func releaseDeviceList() {
        deviceList = nil
    }

    private static func deviceAddress(_ device: MTDeviceRef) -> UInt? {
        UInt(bitPattern: device)
    }

    private func drainIterator(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}

private let builtinTrackpadFamilies: Set<Int> = [98, 99, 100, 101, 102, 103, 104, 105, 113]
private let magicMouseFamilies: Set<Int> = [112]
private let magicTrackpadFamilies: Set<Int> = [128, 129, 130]
private let minimumSupportedFamilyID = 98

nonisolated(unsafe) private var activeDeviceManager: DeviceManager?
nonisolated(unsafe) private var activeTrackpadFrameHandler: ((TouchFrame) -> Void)?
nonisolated(unsafe) private var activeMouseFrameHandler: ((TouchFrame) -> Void)?

private func makeTouchFrame(
    device: MTDeviceRef,
    data: UnsafeMutablePointer<Finger>?,
    nFingers: Int,
    timestamp: Double
) -> TouchFrame? {
    guard let data else { return nil }

    var familyID: Int32 = 0
    MTDeviceGetFamilyID(device, &familyID)
    guard let type = DeviceManager.classifyFamily(Int(familyID)) else {
        return nil
    }

    let touches = UnsafeBufferPointer(start: data, count: nFingers).map(TouchPoint.init(finger:))
    return TouchFrame(touches: touches, timestamp: timestamp, deviceType: type)
}

private func jitouchTrackpadContactCallback(
    device: MTDeviceRef?,
    data: UnsafeMutablePointer<Finger>?,
    nFingers: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    guard
        let device,
        let touchFrame = makeTouchFrame(
            device: device,
            data: data,
            nFingers: Int(nFingers),
            timestamp: timestamp
        )
    else {
        return 0
    }

    Task { @MainActor in
        activeDeviceManager?.recordTouchFrame(touchFrame)
        activeTrackpadFrameHandler?(touchFrame)
    }
    return 0
}

private func jitouchMagicMouseContactCallback(
    device: MTDeviceRef?,
    data: UnsafeMutablePointer<Finger>?,
    nFingers: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    guard
        let device,
        let touchFrame = makeTouchFrame(
            device: device,
            data: data,
            nFingers: Int(nFingers),
            timestamp: timestamp
        )
    else {
        return 0
    }

    Task { @MainActor in
        activeDeviceManager?.recordTouchFrame(touchFrame)
        activeMouseFrameHandler?(touchFrame)
    }
    return 0
}

private func jitouchDeviceAddedNotification(_ refCon: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
    }
    Task { @MainActor in
        activeDeviceManager?.scheduleRescan(reason: "device added")
    }
}

private func jitouchDeviceRemovedNotification(_ refCon: UnsafeMutableRawPointer?, _ iterator: io_iterator_t) {
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
    }
    Task { @MainActor in
        activeDeviceManager?.scheduleRescan(reason: "device removed")
    }
}
