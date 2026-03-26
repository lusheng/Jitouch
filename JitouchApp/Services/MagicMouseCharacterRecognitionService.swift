import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class MagicMouseCharacterRecognitionService {
    var onRecognizedCharacter: ((RecognizedCharacter) -> Void)?

    private var eventHandlerID: UUID?
    private let diagnostics: CharacterRecognitionDiagnosticsStore
    private let overlay = CharacterRecognitionOverlayController()

    init(diagnostics: CharacterRecognitionDiagnosticsStore) {
        self.diagnostics = diagnostics
    }

    func installEventTapHandler(on eventTapManager: EventTapManager) {
        if let eventHandlerID {
            eventTapManager.removeMouseEventHandler(eventHandlerID)
        }
        self.eventHandlerID = eventTapManager.addMouseEventHandler(jitouchMagicMouseCharacterRecognitionEventHandler)
        activeMagicMouseCharacterRecognitionService = self
    }

    func updateSettings(_ settings: JitouchSettings) {
        magicMouseCharacterRecognitionLock.lock()
        magicMouseCharacterRecognitionState.isEnabled = settings.isEnabled && settings.magicMouseEnabled && settings.magicMouseCharacterRecognitionEnabled
        magicMouseCharacterRecognitionState.button = MagicMouseCharacterRecognitionButton(rawValue: settings.characterRecognitionMouseButton) ?? .middle
        magicMouseCharacterRecognitionState.minimumPointTravelSquared = CGFloat(settings.magicMouseCharacterMinimumTravel)
        magicMouseCharacterRecognitionState.activationSegmentThreshold = max(2, settings.magicMouseCharacterActivationSegments)
        magicMouseCharacterRecognitionState.hintWaitTime = settings.characterRecognitionHintDelay
        magicMouseCharacterRecognitionState.session = nil
        magicMouseCharacterRecognitionLock.unlock()
        if !(settings.isEnabled && settings.magicMouseEnabled && settings.magicMouseCharacterRecognitionEnabled) {
            overlay.hide()
        }
    }

    func reset() {
        magicMouseCharacterRecognitionLock.lock()
        magicMouseCharacterRecognitionState.session = nil
        magicMouseCharacterRecognitionLock.unlock()
        overlay.hide()
    }

    fileprivate func deliver(_ character: RecognizedCharacter) {
        onRecognizedCharacter?(character)
    }

    fileprivate func beginOverlay(at screenPoint: CGPoint) {
        overlay.beginMagicMousePath(at: screenPoint)
    }

    fileprivate func updateOverlay(screenPoint: CGPoint, hint: String?, activated: Bool) {
        overlay.updateMagicMousePath(screenPoint: screenPoint, hint: hint, activated: activated)
    }

    fileprivate func hideOverlay() {
        overlay.hide()
    }

    fileprivate func reportSnapshot(
        phase: CharacterRecognitionPhase,
        session: MagicMouseCharacterRecognitionSession?,
        recognized: RecognizedCharacter? = nil,
        reason: String? = nil
    ) {
        guard let session else { return }
        let geometry = session.geometry
        diagnostics.record(
            CharacterRecognitionDiagnosticSnapshot(
                timestamp: .now,
                source: .magicMouse,
                phase: phase,
                segmentCount: session.segmentCount,
                hint: session.currentHint,
                recognizedCharacter: recognized,
                reason: reason,
                verticalSpan: geometry.verticalSpan,
                horizontalSpan: geometry.horizontalSpan,
                candidates: session.engine.debugCandidates(for: geometry)
            )
        )
    }
}

private enum MagicMouseCharacterRecognitionButton: Int {
    case middle = 0
    case right = 1

    var downType: CGEventType {
        switch self {
        case .middle:
            .otherMouseDown
        case .right:
            .rightMouseDown
        }
    }

    var upType: CGEventType {
        switch self {
        case .middle:
            .otherMouseUp
        case .right:
            .rightMouseUp
        }
    }

    var dragType: CGEventType {
        switch self {
        case .middle:
            .otherMouseDragged
        case .right:
            .rightMouseDragged
        }
    }

    var mouseButton: CGMouseButton {
        switch self {
        case .middle:
            .center
        case .right:
            .right
        }
    }

    var buttonNumber: Int64 {
        switch self {
        case .middle:
            2
        case .right:
            1
        }
    }
}

private struct MagicMouseCharacterRecognitionState {
    var isEnabled = false
    var button: MagicMouseCharacterRecognitionButton = .middle
    var minimumPointTravelSquared: CGFloat = 5
    var activationSegmentThreshold = 3
    var hintWaitTime: Double = 0.3
    var session: MagicMouseCharacterRecognitionSession?
}

private struct MagicMouseCharacterRecognitionSession {
    let minimumPointTravelSquared: CGFloat
    let activationSegmentThreshold: Int
    let hintWaitTime: Double
    let firstPoint: CGPoint
    let startScreenPoint: CGPoint
    var lastPoint: CGPoint
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
    var segmentCount = 0
    var engine = CharacterRecognitionEngine()
    private var pendingHintTimestamp: Double?
    private var displayedHint: String?

    var isActivated: Bool {
        segmentCount >= activationSegmentThreshold
    }

    init(
        startingAt point: CGPoint,
        screenPoint: CGPoint,
        minimumPointTravelSquared: CGFloat,
        activationSegmentThreshold: Int,
        hintWaitTime: Double
    ) {
        self.minimumPointTravelSquared = minimumPointTravelSquared
        self.activationSegmentThreshold = activationSegmentThreshold
        self.hintWaitTime = hintWaitTime
        firstPoint = point
        startScreenPoint = screenPoint
        lastPoint = point
        top = point.y
        bottom = point.y
        left = point.x
        right = point.x
    }

    mutating func advance(to point: CGPoint) {
        guard squaredDistance(from: lastPoint, to: point) > minimumPointTravelSquared else {
            return
        }

        top = max(top, point.y)
        bottom = min(bottom, point.y)
        left = min(left, point.x)
        right = max(right, point.x)

        let angle = atan2(point.y - lastPoint.y, point.x - lastPoint.x)
        engine.advance(angle: angle)
        lastPoint = point
        segmentCount += 1
        pendingHintTimestamp = CFAbsoluteTimeGetCurrent() + hintWaitTime
        displayedHint = nil
    }

    func finalize(at point: CGPoint) -> RecognizedCharacter? {
        guard isActivated else { return nil }

        let geometry = CharacterStrokeGeometry(start: firstPoint, end: point, top: top, bottom: bottom, left: left, right: right)
        return engine.bestMatch(for: geometry)
    }

    mutating func resolveHint() -> String? {
        if let pendingHintTimestamp, CFAbsoluteTimeGetCurrent() >= pendingHintTimestamp {
            displayedHint = engine.bestGuess(for: geometry)
            self.pendingHintTimestamp = nil
        }
        return displayedHint
    }

    var currentHint: String? {
        displayedHint
    }

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }

    var geometry: CharacterStrokeGeometry {
        CharacterStrokeGeometry(
            start: firstPoint,
            end: lastPoint,
            top: top,
            bottom: bottom,
            left: left,
            right: right
        )
    }
}

private enum MagicMouseCharacterRecognitionResolution {
    case passThrough
    case recognized(RecognizedCharacter)
    case ignored
}

private let magicMouseCharacterRecognitionLock = NSLock()
nonisolated(unsafe) private var magicMouseCharacterRecognitionState = MagicMouseCharacterRecognitionState()
nonisolated(unsafe) private var activeMagicMouseCharacterRecognitionService: MagicMouseCharacterRecognitionService?

private func jitouchMagicMouseCharacterRecognitionEventHandler(_ event: CGEvent, _ type: CGEventType) -> CGEvent? {
    if event.getIntegerValueField(.eventSourceUserData) == jitouchSyntheticMouseEventUserData {
        return event
    }

    magicMouseCharacterRecognitionLock.lock()
    guard magicMouseCharacterRecognitionState.isEnabled else {
        magicMouseCharacterRecognitionLock.unlock()
        return event
    }

    let button = magicMouseCharacterRecognitionState.button
    let location = event.location
    let recognitionPoint = CGPoint(x: location.x, y: -location.y)

    switch type {
    case button.downType:
        magicMouseCharacterRecognitionState.session = nil
        magicMouseCharacterRecognitionLock.unlock()
        Task { @MainActor in
            activeMagicMouseCharacterRecognitionService?.beginOverlay(at: location)
        }
        return nil

    case button.dragType:
        if magicMouseCharacterRecognitionState.session == nil {
            magicMouseCharacterRecognitionState.session = MagicMouseCharacterRecognitionSession(
                startingAt: recognitionPoint,
                screenPoint: location,
                minimumPointTravelSquared: magicMouseCharacterRecognitionState.minimumPointTravelSquared,
                activationSegmentThreshold: magicMouseCharacterRecognitionState.activationSegmentThreshold,
                hintWaitTime: magicMouseCharacterRecognitionState.hintWaitTime
            )
        } else {
            magicMouseCharacterRecognitionState.session?.advance(to: recognitionPoint)
        }
        let session = magicMouseCharacterRecognitionState.session
        let hint = magicMouseCharacterRecognitionState.session?.resolveHint()
        magicMouseCharacterRecognitionLock.unlock()
        if let session {
            Task { @MainActor in
                activeMagicMouseCharacterRecognitionService?.updateOverlay(
                    screenPoint: location,
                    hint: hint,
                    activated: session.isActivated
                )
                activeMagicMouseCharacterRecognitionService?.reportSnapshot(
                    phase: session.isActivated ? .active : .validating,
                    session: session,
                    reason: session.isActivated ? "Activation threshold reached" : "Collecting more segments"
                )
            }
        }
        return nil

    case button.upType:
        let sessionForDiagnostics = magicMouseCharacterRecognitionState.session
        let resolution: MagicMouseCharacterRecognitionResolution
        if let session = magicMouseCharacterRecognitionState.session {
            if session.isActivated {
                resolution = session.finalize(at: recognitionPoint).map(MagicMouseCharacterRecognitionResolution.recognized) ?? .ignored
            } else {
                resolution = .passThrough
            }
        } else {
            resolution = .passThrough
        }
        magicMouseCharacterRecognitionState.session = nil
        magicMouseCharacterRecognitionLock.unlock()

        switch resolution {
        case .passThrough:
            Task { @MainActor in
                activeMagicMouseCharacterRecognitionService?.hideOverlay()
                activeMagicMouseCharacterRecognitionService?.reportSnapshot(
                    phase: .ignored,
                    session: sessionForDiagnostics,
                    reason: "Mouse drag did not activate character recognition"
                )
            }
            replayMouseClick(button: button, at: location)
        case let .recognized(character):
            Task { @MainActor in
                activeMagicMouseCharacterRecognitionService?.hideOverlay()
                activeMagicMouseCharacterRecognitionService?.deliver(character)
                activeMagicMouseCharacterRecognitionService?.reportSnapshot(
                    phase: .recognized,
                    session: sessionForDiagnostics,
                    recognized: character
                )
            }
        case .ignored:
            Task { @MainActor in
                activeMagicMouseCharacterRecognitionService?.hideOverlay()
                activeMagicMouseCharacterRecognitionService?.reportSnapshot(
                    phase: .ignored,
                    session: sessionForDiagnostics,
                    reason: "No template scored above zero"
                )
            }
            break
        }
        return nil

    default:
        magicMouseCharacterRecognitionLock.unlock()
        return event
    }
}

private func replayMouseClick(button: MagicMouseCharacterRecognitionButton, at location: CGPoint) {
    postSyntheticMouseEvent(type: button.downType, button: button, location: location)
    postSyntheticMouseEvent(type: button.upType, button: button, location: location)
}

private func postSyntheticMouseEvent(
    type: CGEventType,
    button: MagicMouseCharacterRecognitionButton,
    location: CGPoint
) {
    let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: button.mouseButton)
    event?.setIntegerValueField(.mouseEventButtonNumber, value: button.buttonNumber)
    event?.setIntegerValueField(.eventSourceUserData, value: jitouchSyntheticMouseEventUserData)
    event?.post(tap: .cghidEventTap)
}
