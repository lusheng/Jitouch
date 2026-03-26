import XCTest

@testable import Jitouch

@MainActor
final class TrackpadFixFingerRecognizerTests: XCTestCase {
    func testRecognizesOneFixRightTap() {
        let recognizer = TrackpadFixFingerRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadOneFixTap(side: .right)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.oneFixOneTap(.right)])
    }

    func testRecognizesOneFixTwoSlideDown() {
        let recognizer = TrackpadFixFingerRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadOneFixTwoSlide(direction: .down)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.oneFixTwoSlide(.down)])
    }
}
