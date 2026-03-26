import XCTest

@testable import Jitouch

@MainActor
final class TrackpadTabSwitchRecognizerTests: XCTestCase {
    func testRecognizesIndexToPinkySequenceAndSuppressesFourFingerTap() {
        let context = TrackpadGestureContext()
        let recognizer = TrackpadTabSwitchRecognizer(context: context)
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadTabSwitch(direction: .indexToPinky)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.tabSwitch(.indexToPinky)])
        XCTAssertTrue(context.consumeFourFingerTapSuppression())
        XCTAssertFalse(context.consumeFourFingerTapSuppression())
    }

    func testRecognizesPinkyToIndexSequence() {
        let context = TrackpadGestureContext()
        let recognizer = TrackpadTabSwitchRecognizer(context: context)
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadTabSwitch(direction: .pinkyToIndex)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.tabSwitch(.pinkyToIndex)])
    }
}
