import CoreGraphics
import XCTest
@testable import Jitouch

final class MagicMouseCharacterRecognitionServiceTests: XCTestCase {
    func testOverlayRelativePointFlipsQuartzVerticalDeltaForDownwardMovement() {
        let relativePoint = magicMouseOverlayRelativePoint(
            startScreenPoint: CGPoint(x: 320, y: 240),
            currentScreenPoint: CGPoint(x: 350, y: 300)
        )

        XCTAssertEqual(relativePoint.x, 30, accuracy: 0.001)
        XCTAssertEqual(relativePoint.y, -60, accuracy: 0.001)
    }

    func testOverlayRelativePointKeepsUpwardMovementPositiveInOverlaySpace() {
        let relativePoint = magicMouseOverlayRelativePoint(
            startScreenPoint: CGPoint(x: 320, y: 240),
            currentScreenPoint: CGPoint(x: 280, y: 180)
        )

        XCTAssertEqual(relativePoint.x, -40, accuracy: 0.001)
        XCTAssertEqual(relativePoint.y, 60, accuracy: 0.001)
    }
}
