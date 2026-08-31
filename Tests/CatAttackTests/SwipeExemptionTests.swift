import XCTest
@testable import CatAttackCore

/// Swiping a hand across the keys is fast enough to look like mashing, so the
/// rate rules exempt input that traces a drag. A paw cannot trace one: its keys
/// land in whatever order the toes touch down, so the path doubles back.
final class SwipeExemptionTests: XCTestCase {

    /// Presses each key and releases it immediately, 30 ms apart.
    private func swipe(_ keys: [Int64], gapMs: Double = 30) -> DetectionVerdict {
        let detector = CatDetector()
        var t = 0.0
        for key in keys {
            let verdict = detector.keyDown(key, at: t)
            if verdict.isCat { return verdict }
            detector.keyUp(key)
            t += gapMs / 1000
        }
        return .notCat
    }

    func testHomeRowSwipeIsNotACat() {
        // a s d f g h j k l
        XCTAssertFalse(swipe([0, 1, 2, 3, 5, 4, 38, 40, 37]).isCat)
    }

    func testReverseSwipeIsNotACat() {
        XCTAssertFalse(swipe([37, 40, 38, 4, 5, 3, 2, 1, 0]).isCat)
    }

    func testTopRowSwipeIsNotACat() {
        // q w e r t y u i o p
        XCTAssertFalse(swipe([12, 13, 14, 15, 17, 16, 32, 34, 31, 35]).isCat)
    }

    func testDiagonalSwipeIsNotACat() {
        // z a q w e r — up the left edge then across
        XCTAssertFalse(swipe([6, 0, 12, 13, 14, 15]).isCat)
    }

    func testJumpingAcrossTheBoardIsStillACat() {
        // j k l ; then a leap back to h g f ' — steps too large to be a drag
        XCTAssertTrue(swipe([38, 40, 37, 41, 4, 5, 3, 39]).isCat)
    }

    func testPawSkitterIsStillACat() {
        // u i o j k l — contiguous, but travels too little to be a swipe
        XCTAssertTrue(swipe([32, 34, 31, 38, 40, 37]).isCat)
    }

    func testHeldPawPressIgnoresTheSwipeExemption() {
        // Keys held down together are a cat however the paw arrived.
        let detector = CatDetector()
        var verdict = DetectionVerdict.notCat
        for (i, key) in ([32, 34, 38, 40] as [Int64]).enumerated() {
            verdict = detector.keyDown(key, at: Double(i) * 0.02)
        }
        XCTAssertTrue(verdict.isCat)
    }

    func testSwipeGeometryDirectly() {
        let detector = CatDetector()
        XCTAssertTrue(detector.looksLikeSwipe([0, 1, 2, 3, 5]))      // a s d f g
        XCTAssertFalse(detector.looksLikeSwipe([32, 34, 38, 40]))    // u i j k — too little travel
        XCTAssertFalse(detector.looksLikeSwipe([0, 44, 12, 35]))     // a / q p — leaps
    }
}
