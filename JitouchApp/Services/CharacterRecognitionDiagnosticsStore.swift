import Foundation
import Observation

enum CharacterRecognitionSource: String, Sendable {
    case trackpadOneFinger
    case trackpadTwoFinger
    case magicMouse

    var title: String {
        switch self {
        case .trackpadOneFinger:
            "Trackpad One-Finger"
        case .trackpadTwoFinger:
            "Trackpad Two-Finger"
        case .magicMouse:
            "Magic Mouse"
        }
    }
}

enum CharacterRecognitionPhase: String, Sendable {
    case primed
    case validating
    case active
    case recognized
    case cancelled
    case ignored

    var title: String {
        rawValue.capitalized
    }

    var isTerminal: Bool {
        switch self {
        case .recognized, .cancelled, .ignored:
            true
        default:
            false
        }
    }
}

struct CharacterRecognitionCandidateSnapshot: Identifiable, Sendable, Hashable {
    let value: String
    let score: Double
    let matchedSegments: Int
    let totalSegments: Int
    let isComplete: Bool
    let isAcceptedByGeometry: Bool

    var id: String { value }
}

struct CharacterRecognitionDiagnosticSnapshot: Identifiable, Sendable, Hashable {
    let id = UUID()
    let timestamp: Date
    let source: CharacterRecognitionSource
    let phase: CharacterRecognitionPhase
    let segmentCount: Int
    let hint: String?
    let recognizedCharacter: RecognizedCharacter?
    let reason: String?
    let verticalSpan: Double?
    let horizontalSpan: Double?
    let candidates: [CharacterRecognitionCandidateSnapshot]
}

@MainActor
@Observable
final class CharacterRecognitionDiagnosticsStore {
    var isEnabled = true
    private(set) var liveSnapshot: CharacterRecognitionDiagnosticSnapshot?
    private(set) var recentSnapshots: [CharacterRecognitionDiagnosticSnapshot] = []

    func configure(from settings: JitouchSettings) {
        isEnabled = settings.characterRecognitionDiagnosticsEnabled
        if !isEnabled {
            clear()
        }
    }

    func record(_ snapshot: CharacterRecognitionDiagnosticSnapshot) {
        guard isEnabled else { return }
        liveSnapshot = snapshot
        guard snapshot.phase.isTerminal else { return }

        recentSnapshots.insert(snapshot, at: 0)
        if recentSnapshots.count > 12 {
            recentSnapshots.removeLast(recentSnapshots.count - 12)
        }
    }

    func clear() {
        liveSnapshot = nil
        recentSnapshots.removeAll()
    }
}
