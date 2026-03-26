import CoreGraphics
import XCTest

@testable import Jitouch

final class CharacterRecognitionEngineTests: XCTestCase {
    func testRecognizesLShapeStroke() {
        var engine = CharacterRecognitionEngine()

        for angle in TouchFrameFactory.characterLAngles {
            engine.advance(angle: angle)
        }

        let geometry = CharacterStrokeGeometry(
            start: CGPoint(x: 0, y: 1),
            end: CGPoint(x: 1, y: 0),
            top: 1,
            bottom: 0,
            left: 0,
            right: 1
        )

        XCTAssertEqual(engine.bestMatch(for: geometry)?.value, "L")
    }

    func testRecognizesSingleSegmentUpStroke() {
        var engine = CharacterRecognitionEngine()

        for angle in TouchFrameFactory.characterUpAngles {
            engine.advance(angle: angle)
        }

        let geometry = CharacterStrokeGeometry(
            start: CGPoint(x: 0.5, y: 0),
            end: CGPoint(x: 0.5, y: 1),
            top: 1,
            bottom: 0,
            left: 0.5,
            right: 0.5
        )

        XCTAssertEqual(engine.bestMatch(for: geometry)?.value, "Up")
    }
}
