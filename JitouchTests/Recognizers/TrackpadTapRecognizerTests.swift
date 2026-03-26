import XCTest

@testable import Jitouch

@MainActor
final class TrackpadTapRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerTap() {
        let recognizer = TrackpadTapRecognizer(context: TrackpadGestureContext())
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadThreeFingerTap()
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.threeFingerTap])
    }

    func testSuppressesFourFingerTapWhenContextRequestsIt() {
        let context = TrackpadGestureContext()
        context.suppressFourFingerTapOnce()

        let recognizer = TrackpadTapRecognizer(context: context)
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadFourFingerTap()
            .flatMap(recognizer.processFrame)

        XCTAssertTrue(events.isEmpty)
    }
}
