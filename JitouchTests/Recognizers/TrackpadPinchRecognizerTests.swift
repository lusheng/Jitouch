import XCTest

@testable import Jitouch

@MainActor
final class TrackpadPinchRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerPinchOut() {
        let recognizer = TrackpadPinchRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadThreeFingerPinch(direction: .outward)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.threeFingerPinch(.outward)])
    }

    func testDoesNotRepeatSamePinchDirectionWithoutReset() {
        var settings = CommandCatalog.defaultSettings
        settings.sensitivity = 10

        let recognizer = TrackpadPinchRecognizer()
        recognizer.updateSettings(settings)

        let frames = TouchFrameFactory.trackpadThreeFingerPinch(direction: .outward) + [
            TouchFrameFactory.trackpadFrame(
                timestamp: 0.10,
                touches: [
                    TouchFrameFactory.touch(id: 1, x: 0.00, y: 0.50, timestamp: 0.10),
                    TouchFrameFactory.touch(id: 2, x: 0.50, y: 0.50, timestamp: 0.10),
                    TouchFrameFactory.touch(id: 3, x: 1.00, y: 0.50, timestamp: 0.10),
                ]
            ),
        ]

        let events = frames.flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.threeFingerPinch(.outward)])
    }
}
