import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class TrackpadOneFingerCharacterRecognizer: GestureRecognizer {
    var isEnabled = false

    private let context: TrackpadGestureContext
    private let diagnostics: CharacterRecognitionDiagnosticsStore
    private let overlay = CharacterRecognitionOverlayController()

    private var minimumPointTravelSquared: CGFloat = 0.0002
    private let maximumFingerDistance: CGFloat = 0.65
    private let maximumVerticalOffset: CGFloat = 0.5
    private let stagedFingerDriftThreshold: CGFloat = 0.001
    private let offscreenCursorLocation = CGPoint(x: 10_000, y: 10_000)
    private var hintWaitTime: Double = 0.3

    private var state = TrackpadOneFingerCharacterState.idle
    private var indexRingDistance: CGFloat = 0.33
    private var clickSpeed: Double = 0.25
    private var touchSizeThreshold: Float = 0.45

    init(context: TrackpadGestureContext, diagnostics: CharacterRecognitionDiagnosticsStore) {
        self.context = context
        self.diagnostics = diagnostics
    }

    func processFrame(_ frame: TouchFrame) -> [GestureEvent] {
        guard frame.deviceType == .trackpad else { return [] }

        if !isEnabled {
            reset()
            return []
        }

        if let currentMode = context.currentCharacterRecognitionMode, currentMode != .oneFinger {
            reset()
            return []
        }

        let touches = frame.activeTouches

        switch state {
        case .idle:
            if touches.count == 1 {
                state = .arming(fixedTouchID: touches[0].id)
            }
            return []

        case let .arming(fixedTouchID):
            return advanceArmingState(
                touches: touches,
                timestamp: frame.timestamp,
                fixedTouchID: fixedTouchID
            )

        case let .awaitingRelease(session):
            return advanceAwaitingReleaseState(
                touches: touches,
                timestamp: frame.timestamp,
                session: session
            )

        case let .drawing(session):
            return advanceDrawingState(
                touches: touches,
                timestamp: frame.timestamp,
                session: session
            )
        }
    }

    func reset() {
        if case let .drawing(session) = state {
            restoreMouse(to: session.originalMouseLocation)
        }
        state = .idle
        context.endCharacterRecognition(.oneFinger)
        overlay.hide()
    }

    func updateSettings(_ settings: JitouchSettings) {
        isEnabled = settings.trackpadEnabled && settings.trackpadCharacterRecognitionEnabled && settings.oneFingerDrawingEnabled
        indexRingDistance = CGFloat(settings.characterRecognitionIndexRingDistance)
        clickSpeed = settings.clickSpeed
        touchSizeThreshold = Float(settings.sensitivity / 10.0)
        hintWaitTime = settings.characterRecognitionHintDelay
        let scale = max(0.7, min(1.3, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        minimumPointTravelSquared = CGFloat(settings.trackpadCharacterMinimumTravel) * scale
    }

    private func advanceArmingState(
        touches: [TouchPoint],
        timestamp: Double,
        fixedTouchID: Int
    ) -> [GestureEvent] {
        switch touches.count {
        case 1:
            state = .arming(fixedTouchID: touches[0].id)
        case 2:
            guard shouldStageTwoFingerPose(touches, fixedTouchID: fixedTouchID) else {
                state = .idle
                return []
            }

            let stagedSession = TrackpadOneFingerStagingSession(
                fixedTouchID: fixedTouchID,
                stagedAt: timestamp,
                anchorPositions: Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
            )
            state = .awaitingRelease(stagedSession)
            diagnostics.record(
                CharacterRecognitionDiagnosticSnapshot(
                    timestamp: .now,
                    source: .trackpadOneFinger,
                    phase: .primed,
                    segmentCount: 0,
                    hint: nil,
                    recognizedCharacter: nil,
                    reason: "Waiting for the anchor finger to lift",
                    verticalSpan: nil,
                    horizontalSpan: nil,
                    candidates: []
                )
            )
        default:
            state = .idle
        }
        return []
    }

    private func advanceAwaitingReleaseState(
        touches: [TouchPoint],
        timestamp: Double,
        session: TrackpadOneFingerStagingSession
    ) -> [GestureEvent] {
        if let currentMode = context.currentCharacterRecognitionMode, currentMode != .oneFinger {
            state = .idle
            return []
        }

        switch touches.count {
        case 1:
            guard timestamp - session.stagedAt <= clickSpeed else {
                state = .idle
                return []
            }

            guard context.beginCharacterRecognition(.oneFinger) else {
                state = .idle
                return []
            }

            let touch = touches[0]
            let drawingSession = TrackpadOneFingerDrawingSession(
                firstPoint: touch.position,
                lastPoint: touch.position,
                top: touch.position.y,
                bottom: touch.position.y,
                left: touch.position.x,
                right: touch.position.x,
                touchID: touch.id,
                originalMouseLocation: currentMouseLocation()
            )
            overlay.beginTrackpadPath(at: touch.position)
            parkMouseOffscreen()
            state = .drawing(drawingSession)
            reportSnapshot(phase: .active, session: drawingSession, reason: "Drawing started")
        case 2:
            guard isStagedPoseStable(touches, anchorPositions: session.anchorPositions) else {
                diagnostics.record(
                    CharacterRecognitionDiagnosticSnapshot(
                        timestamp: .now,
                        source: .trackpadOneFinger,
                        phase: .cancelled,
                        segmentCount: 0,
                        hint: nil,
                        recognizedCharacter: nil,
                        reason: "Two-finger staging pose drifted too far",
                        verticalSpan: nil,
                        horizontalSpan: nil,
                        candidates: []
                    )
                )
                state = .idle
                return []
            }
        default:
            state = .idle
        }

        return []
    }

    private func advanceDrawingState(
        touches: [TouchPoint],
        timestamp: Double,
        session: TrackpadOneFingerDrawingSession
    ) -> [GestureEvent] {
        var session = session

        guard touches.count == 1, touches[0].id == session.touchID else {
            resetAfterDrawing(originalMouseLocation: session.originalMouseLocation)

            guard touches.isEmpty else {
                reportSnapshot(phase: .cancelled, session: session, reason: "Touch identifiers changed during drawing")
                return []
            }

            guard let character = session.engine.bestMatch(for: session.geometry) else {
                reportSnapshot(phase: .ignored, session: session, reason: "No template scored above zero")
                return []
            }

            reportSnapshot(phase: .recognized, session: session, recognized: character)
            return [.characterRecognized(character)]
        }

        let touch = touches[0]
        let hint = session.resolveHint(at: timestamp)

        if squaredDistance(session.lastPoint, touch.position) > minimumPointTravelSquared {
            let angle = atan2(touch.position.y - session.lastPoint.y, touch.position.x - session.lastPoint.x)
            session.engine.advance(angle: angle)
            session.lastPoint = touch.position
            session.expandBounds(with: touch.position)
            session.segmentCount += 1
            session.queueHintRefresh(after: timestamp + hintWaitTime)
            overlay.updateTrackpadPath(touch.position, hint: session.resolveHint(at: timestamp))
        } else {
            overlay.updateTrackpadPath(touch.position, hint: hint)
        }

        parkMouseOffscreen()

        if session.engine.isCancelled {
            reportSnapshot(phase: .cancelled, session: session, reason: "Engine cancelled recognition")
            resetAfterDrawing(originalMouseLocation: session.originalMouseLocation)
            return []
        }

        reportSnapshot(phase: .active, session: session)
        state = .drawing(session)
        return []
    }

    private func resetAfterDrawing(originalMouseLocation: CGPoint) {
        restoreMouse(to: originalMouseLocation)
        state = .idle
        context.endCharacterRecognition(.oneFinger)
        overlay.hide()
    }

    private func shouldStageTwoFingerPose(_ touches: [TouchPoint], fixedTouchID: Int) -> Bool {
        guard touches.count == 2 else { return false }
        guard !CGEventSource.buttonState(.hidSystemState, button: .left) else { return false }

        let sorted = touches.sorted { $0.position.x < $1.position.x }
        let horizontalDistance = abs(sorted[1].position.x - sorted[0].position.x)
        let verticalDistance = abs(sorted[1].position.y - sorted[0].position.y)

        guard
            horizontalDistance > indexRingDistance,
            horizontalDistance < maximumFingerDistance,
            verticalDistance < maximumVerticalOffset
        else {
            return false
        }

        return touches.allSatisfy { touch in
            touch.id == fixedTouchID || touch.size > touchSizeThreshold
        }
    }

    private func isStagedPoseStable(
        _ touches: [TouchPoint],
        anchorPositions: [Int: CGPoint]
    ) -> Bool {
        for touch in touches {
            let anchor = anchorPositions[touch.id] ?? touch.position
            if squaredDistance(anchor, touch.position) > stagedFingerDriftThreshold {
                return false
            }
        }
        return true
    }

    private func squaredDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }

    private func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func parkMouseOffscreen() {
        postSyntheticMouseMove(to: offscreenCursorLocation)
    }

    private func restoreMouse(to location: CGPoint) {
        postSyntheticMouseMove(to: location)
    }

    private func postSyntheticMouseMove(to location: CGPoint) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: location,
            mouseButton: .left
        )
        event?.setIntegerValueField(.eventSourceUserData, value: jitouchSyntheticMouseEventUserData)
        event?.post(tap: .cghidEventTap)
    }

    private func reportSnapshot(
        phase: CharacterRecognitionPhase,
        session: TrackpadOneFingerDrawingSession,
        recognized: RecognizedCharacter? = nil,
        reason: String? = nil
    ) {
        let geometry = session.geometry
        diagnostics.record(
            CharacterRecognitionDiagnosticSnapshot(
                timestamp: .now,
                source: .trackpadOneFinger,
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

private enum TrackpadOneFingerCharacterState {
    case idle
    case arming(fixedTouchID: Int)
    case awaitingRelease(TrackpadOneFingerStagingSession)
    case drawing(TrackpadOneFingerDrawingSession)
}

private struct TrackpadOneFingerStagingSession {
    let fixedTouchID: Int
    let stagedAt: Double
    let anchorPositions: [Int: CGPoint]
}

private struct TrackpadOneFingerDrawingSession {
    let firstPoint: CGPoint
    var lastPoint: CGPoint
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
    let touchID: Int
    let originalMouseLocation: CGPoint
    var engine = CharacterRecognitionEngine()
    var segmentCount = 0
    private var pendingHintTimestamp: Double?
    private var displayedHint: String?

    init(
        firstPoint: CGPoint,
        lastPoint: CGPoint,
        top: CGFloat,
        bottom: CGFloat,
        left: CGFloat,
        right: CGFloat,
        touchID: Int,
        originalMouseLocation: CGPoint
    ) {
        self.firstPoint = firstPoint
        self.lastPoint = lastPoint
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.touchID = touchID
        self.originalMouseLocation = originalMouseLocation
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

    mutating func expandBounds(with point: CGPoint) {
        top = max(top, point.y)
        bottom = min(bottom, point.y)
        left = min(left, point.x)
        right = max(right, point.x)
    }

    mutating func queueHintRefresh(after timestamp: Double) {
        pendingHintTimestamp = timestamp
        displayedHint = nil
    }

    mutating func resolveHint(at timestamp: Double) -> String? {
        if let pendingHintTimestamp, timestamp >= pendingHintTimestamp {
            displayedHint = engine.bestGuess(for: geometry)
            self.pendingHintTimestamp = nil
        }
        return displayedHint
    }

    var currentHint: String? {
        displayedHint
    }
}
