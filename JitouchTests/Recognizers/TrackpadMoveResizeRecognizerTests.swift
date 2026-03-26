import XCTest

@testable import Jitouch

@MainActor
final class TrackpadMoveResizeRecognizerTests: XCTestCase {
    func testRecognizesMoveSessionAndEndsAfterRelease() {
        let recognizer = TrackpadMoveResizeRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadMoveResizeSession(mode: .move)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(
            events,
            [
                .moveResize(.began(.move)),
                .moveResize(.changed(mode: .move, dx: 0.52, dy: 0.32)),
                .moveResize(.ended),
            ]
        )
    }

    func testRecognizesResizeSessionAndEndsAfterRelease() {
        let recognizer = TrackpadMoveResizeRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadMoveResizeSession(mode: .resize)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(
            events,
            [
                .moveResize(.began(.resize)),
                .moveResize(.changed(mode: .resize, dx: 0.33, dy: 0.69)),
                .moveResize(.ended),
            ]
        )
    }
}
