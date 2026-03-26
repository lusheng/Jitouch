import XCTest

@testable import Jitouch

@MainActor
final class MagicMouseRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerLeftSwipe() {
        let recognizer = MagicMouseRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.magicMouseThreeFingerSwipe(direction: .left)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.mmThreeFingerSwipe(.left)])
    }

    func testRecognizesPinchOut() {
        let recognizer = MagicMouseRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.magicMousePinch(direction: .outward)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.mmPinch(.outward)])
    }
}
