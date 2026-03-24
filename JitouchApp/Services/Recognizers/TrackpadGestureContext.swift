import Foundation

@MainActor
final class TrackpadGestureContext {
    private var suppressNextFourFingerTap = false

    func suppressFourFingerTapOnce() {
        suppressNextFourFingerTap = true
    }

    func consumeFourFingerTapSuppression() -> Bool {
        let shouldSuppress = suppressNextFourFingerTap
        suppressNextFourFingerTap = false
        return shouldSuppress
    }
}
