import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class TrackpadCharacterRecognizer: GestureRecognizer {
    var isEnabled = false

    private var baseMinimumPointTravelSquared: CGFloat = 0.0002
    private var minimumPointTravelSquared: CGFloat = 0.0002
    private var startingFingerDistance: CGFloat = 0.33
    private let maximumFingerDistance: CGFloat = 0.65
    private let maximumVerticalOffset: CGFloat = 0.6
    private let minimumTouchHeight: CGFloat = 0.14
    private let minimumFingerTravelSquared: CGFloat = 0.003
    private let distanceStabilityThreshold: CGFloat = 0.13
    private var minimumValidatedSegments = 5
    private var hintWaitTime: Double = 0.3

    private let context: TrackpadGestureContext
    private let diagnostics: CharacterRecognitionDiagnosticsStore
    private let overlay = CharacterRecognitionOverlayController()
    private var session: TrackpadCharacterSession?

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

        if let currentMode = context.currentCharacterRecognitionMode, currentMode != .twoFinger {
            reset()
            return []
        }

        let touches = frame.activeTouches
        if var currentSession = session {
            let events = update(session: &currentSession, with: touches, timestamp: frame.timestamp)
            session = currentSession.isActive ? currentSession : nil
            if session == nil {
                context.endCharacterRecognition(.twoFinger)
            }
            return events
        }

        guard !context.isCharacterRecognitionActive, shouldStartRecognition(with: touches) else {
            return []
        }

        guard context.beginCharacterRecognition(.twoFinger) else {
            return []
        }

        session = TrackpadCharacterSession(touches: touches)
        reportSnapshot(phase: .primed, session: session, reason: "Waiting for validation threshold")
        overlay.prepareTrackpadPath(at: session?.firstNormalizedPoint ?? .zero)
        return []
    }

    func reset() {
        session = nil
        context.endCharacterRecognition(.twoFinger)
        overlay.hide()
    }

    func updateSettings(_ settings: JitouchSettings) {
        isEnabled = settings.trackpadEnabled && settings.trackpadCharacterRecognitionEnabled && settings.twoFingerDrawingEnabled
        startingFingerDistance = CGFloat(settings.characterRecognitionIndexRingDistance)
        hintWaitTime = settings.characterRecognitionHintDelay
        minimumValidatedSegments = max(2, settings.trackpadCharacterValidationSegments)
        baseMinimumPointTravelSquared = CGFloat(settings.trackpadCharacterMinimumTravel)

        let scale = max(0.7, min(1.3, CGFloat(4.6666 / max(settings.sensitivity, 1.0))))
        minimumPointTravelSquared = baseMinimumPointTravelSquared * scale
    }

    private func shouldStartRecognition(with touches: [TouchPoint]) -> Bool {
        guard touches.count == 2 else { return false }
        guard !CGEventSource.buttonState(.hidSystemState, button: .left) else { return false }

        let sorted = touches.sorted { $0.position.x < $1.position.x }
        let horizontalDistance = sorted[1].position.x - sorted[0].position.x
        let verticalDistance = abs(sorted[1].position.y - sorted[0].position.y)

        guard
            horizontalDistance > startingFingerDistance,
            horizontalDistance < maximumFingerDistance,
            verticalDistance < maximumVerticalOffset,
            sorted.allSatisfy({ $0.position.y > minimumTouchHeight }),
            !looksLikePalmPose(sorted)
        else {
            return false
        }

        return true
    }

    private func update(
        session: inout TrackpadCharacterSession,
        with touches: [TouchPoint],
        timestamp: Double
    ) -> [GestureEvent] {
        guard touches.count == 2 else {
            return finish(session: &session, cancelled: touches.count == 3)
        }

        let ids = Set(touches.map(\.id))
        guard ids == session.touchIDs else {
            session.isActive = false
            reportSnapshot(phase: .cancelled, session: session, reason: "Touch identifiers changed")
            overlay.hide()
            return []
        }

        let midpoint = center(of: touches)
        let hint = session.resolveHint(at: timestamp)
        guard squaredDistance(session.lastPoint, midpoint) > minimumPointTravelSquared else {
            if session.engine.isCancelled {
                session.isActive = false
                reportSnapshot(phase: .cancelled, session: session, reason: "Candidate scores diverged too far")
                overlay.hide()
            } else if session.isValidated {
                overlay.updateTrackpadPath(midpoint, hint: hint)
                reportSnapshot(phase: .active, session: session)
            }
            return []
        }

        let angle = atan2(midpoint.y - session.lastPoint.y, midpoint.x - session.lastPoint.x)
        session.engine.advance(angle: angle)
        session.lastPoint = midpoint
        session.expandBounds(with: midpoint)
        session.segmentCount += 1
        session.queueHintRefresh(after: timestamp + hintWaitTime)

        if !session.isValidated, session.segmentCount >= minimumValidatedSegments {
            let sortedInitialTouches = session.initialTouchMap.values.sorted { $0.x < $1.x }
            let startDistanceSquared = squaredDistance(sortedInitialTouches[0], sortedInitialTouches[1])
            let currentDistanceSquared = squaredDistance(touches[0].position, touches[1].position)
            let finger0Travel = squaredDistance(session.initialTouchMap[touches[0].id] ?? touches[0].position, touches[0].position)
            let finger1Travel = squaredDistance(session.initialTouchMap[touches[1].id] ?? touches[1].position, touches[1].position)

            if
                finger0Travel > minimumFingerTravelSquared,
                finger1Travel > minimumFingerTravelSquared,
                abs(startDistanceSquared - currentDistanceSquared) < distanceStabilityThreshold
            {
                session.isValidated = true
                reportSnapshot(phase: .active, session: session, reason: "Validation passed")
                overlay.reveal()
            } else {
                session.isActive = false
                reportSnapshot(phase: .cancelled, session: session, reason: "Validation gate failed")
                overlay.hide()
                return []
            }
        }

        if session.engine.isCancelled {
            session.isActive = false
            reportSnapshot(phase: .cancelled, session: session, reason: "Engine cancelled recognition")
            overlay.hide()
            return []
        }

        reportSnapshot(phase: session.isValidated ? .active : .validating, session: session)
        overlay.updateTrackpadPath(midpoint, hint: session.resolveHint(at: timestamp))
        return []
    }

    private func finish(session: inout TrackpadCharacterSession, cancelled: Bool) -> [GestureEvent] {
        defer { session.isActive = false }
        defer { overlay.hide() }

        guard !cancelled, session.isValidated else {
            let reason = cancelled ? "Recognition cancelled by extra fingers" : "Gesture ended before validation completed"
            reportSnapshot(phase: .ignored, session: session, reason: reason)
            return []
        }

        guard let character = session.engine.bestMatch(for: session.geometry) else {
            reportSnapshot(phase: .ignored, session: session, reason: "No template scored above zero")
            return []
        }

        reportSnapshot(phase: .recognized, session: session, recognized: character)
        return [.characterRecognized(character)]
    }

    private func looksLikePalmPose(_ touches: [TouchPoint]) -> Bool {
        guard touches.count == 2 else { return false }
        let left = touches[0]
        let right = touches[1]

        return
            left.majorAxis >= 11 &&
            right.majorAxis >= 11 &&
            right.angle > Float.pi / 2 &&
            left.angle < Float.pi / 2 &&
            (right.angle - left.angle) > 0.5
    }

    private func center(of touches: [TouchPoint]) -> CGPoint {
        let sum = touches.reduce(CGPoint.zero) { partial, touch in
            CGPoint(x: partial.x + touch.position.x, y: partial.y + touch.position.y)
        }
        return CGPoint(x: sum.x / CGFloat(touches.count), y: sum.y / CGFloat(touches.count))
    }

    private func squaredDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }

    private func reportSnapshot(
        phase: CharacterRecognitionPhase,
        session: TrackpadCharacterSession?,
        recognized: RecognizedCharacter? = nil,
        reason: String? = nil
    ) {
        guard let session else { return }
        let geometry = session.geometry
        diagnostics.record(
            CharacterRecognitionDiagnosticSnapshot(
                timestamp: .now,
                source: .trackpadTwoFinger,
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

private struct TrackpadCharacterSession {
    let touchIDs: Set<Int>
    let initialTouchMap: [Int: CGPoint]
    let firstPoint: CGPoint
    let firstNormalizedPoint: CGPoint
    var lastPoint: CGPoint
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat
    var segmentCount = 0
    var isValidated = false
    var isActive = true
    var engine = CharacterRecognitionEngine()
    private var pendingHintTimestamp: Double?
    private var displayedHint: String?

    init(touches: [TouchPoint]) {
        let firstPoint = CGPoint(
            x: (touches[0].position.x + touches[1].position.x) / 2,
            y: (touches[0].position.y + touches[1].position.y) / 2
        )

        self.touchIDs = Set(touches.map(\.id))
        self.initialTouchMap = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0.position) })
        self.firstPoint = firstPoint
        self.firstNormalizedPoint = firstPoint
        self.lastPoint = firstPoint
        self.top = firstPoint.y
        self.bottom = firstPoint.y
        self.left = firstPoint.x
        self.right = firstPoint.x
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

    mutating func expandBounds(with point: CGPoint) {
        top = max(top, point.y)
        bottom = min(bottom, point.y)
        left = min(left, point.x)
        right = max(right, point.x)
    }

    var currentHint: String? {
        displayedHint
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
