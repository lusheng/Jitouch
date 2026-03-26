import CoreGraphics
import XCTest
@testable import Jitouch

final class MagicMouseCharacterRecognitionServiceTests: XCTestCase {
    func testOverlayCanvasFrameUsesUnionOfAllScreens() {
        let frame = magicMouseOverlayCanvasFrame(
            for: [
                CGRect(x: 0, y: 0, width: 1440, height: 900),
                CGRect(x: 1440, y: 120, width: 1728, height: 1117),
            ]
        )

        XCTAssertEqual(frame.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(frame.width, 3168, accuracy: 0.001)
        XCTAssertEqual(frame.height, 1237, accuracy: 0.001)
    }

    func testOverlayLocalPointMapsScreenPointIntoPanelSpace() {
        let point = magicMouseOverlayLocalPoint(
            screenPoint: CGPoint(x: 350, y: 300),
            panelFrame: CGRect(x: 200, y: 120, width: 1200, height: 900)
        )

        XCTAssertEqual(point.x, 150, accuracy: 0.001)
        XCTAssertEqual(point.y, 180, accuracy: 0.001)
    }

    func testOverlayLocalPointPreservesMovementDirection() {
        let panelFrame = CGRect(x: -600, y: 0, width: 2400, height: 1400)
        let startPoint = magicMouseOverlayLocalPoint(
            screenPoint: CGPoint(x: 320, y: 240),
            panelFrame: panelFrame
        )
        let movedPoint = magicMouseOverlayLocalPoint(
            screenPoint: CGPoint(x: 350, y: 300),
            panelFrame: panelFrame
        )

        XCTAssertEqual(movedPoint.x - startPoint.x, 30, accuracy: 0.001)
        XCTAssertEqual(movedPoint.y - startPoint.y, 60, accuracy: 0.001)
    }
}
