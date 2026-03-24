import Foundation

enum TrackpadCharacterRecognitionMode: Sendable {
    case oneFinger
    case twoFinger
}

@MainActor
final class TrackpadGestureContext {
    private var suppressNextFourFingerTap = false
    private var activeCharacterRecognitionMode: TrackpadCharacterRecognitionMode?

    func suppressFourFingerTapOnce() {
        suppressNextFourFingerTap = true
    }

    func consumeFourFingerTapSuppression() -> Bool {
        let shouldSuppress = suppressNextFourFingerTap
        suppressNextFourFingerTap = false
        return shouldSuppress
    }

    var isCharacterRecognitionActive: Bool {
        activeCharacterRecognitionMode != nil
    }

    var currentCharacterRecognitionMode: TrackpadCharacterRecognitionMode? {
        activeCharacterRecognitionMode
    }

    @discardableResult
    func beginCharacterRecognition(_ mode: TrackpadCharacterRecognitionMode) -> Bool {
        guard activeCharacterRecognitionMode == nil || activeCharacterRecognitionMode == mode else {
            return false
        }

        activeCharacterRecognitionMode = mode
        return true
    }

    func endCharacterRecognition(_ mode: TrackpadCharacterRecognitionMode? = nil) {
        guard let mode else {
            activeCharacterRecognitionMode = nil
            return
        }

        if activeCharacterRecognitionMode == mode {
            activeCharacterRecognitionMode = nil
        }
    }
}
