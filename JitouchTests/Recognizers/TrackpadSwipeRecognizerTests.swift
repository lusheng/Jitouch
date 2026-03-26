import XCTest

@testable import Jitouch

@MainActor
final class TrackpadSwipeRecognizerTests: XCTestCase {
    func testRecognizesThreeFingerLeftSwipe() {
        let recognizer = TrackpadSwipeRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let events = TouchFrameFactory.trackpadThreeFingerSwipe(direction: .left)
            .flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.threeFingerSwipe(.left)])
    }

    func testRecognizesFourFingerUpSwipe() {
        let recognizer = TrackpadSwipeRecognizer()
        recognizer.updateSettings(CommandCatalog.defaultSettings)

        let start = [
            TouchFrameFactory.touch(id: 1, x: 0.22, y: 0.44, timestamp: 0),
            TouchFrameFactory.touch(id: 2, x: 0.36, y: 0.46, timestamp: 0),
            TouchFrameFactory.touch(id: 3, x: 0.50, y: 0.45, timestamp: 0),
            TouchFrameFactory.touch(id: 4, x: 0.64, y: 0.47, timestamp: 0),
        ]
        let moved = [
            TouchFrameFactory.touch(id: 1, x: 0.22, y: 0.60, timestamp: 0.05),
            TouchFrameFactory.touch(id: 2, x: 0.36, y: 0.62, timestamp: 0.05),
            TouchFrameFactory.touch(id: 3, x: 0.50, y: 0.61, timestamp: 0.05),
            TouchFrameFactory.touch(id: 4, x: 0.64, y: 0.63, timestamp: 0.05),
        ]

        let frames = [
            TouchFrameFactory.trackpadFrame(timestamp: 0, touches: start),
            TouchFrameFactory.trackpadFrame(timestamp: 0.05, touches: moved),
        ]

        let events = frames.flatMap(recognizer.processFrame)

        XCTAssertEqual(events, [.fourFingerSwipe(.up)])
    }
}
