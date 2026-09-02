import XCTest
@testable import CatAttackCore

/// A paw resting on the keys is told apart from typing by duration. These run
/// the timer-driven check that catches a cat which has settled and gone still.
final class RestingPawTests: XCTestCase {

    func testThreeAdjacentKeysHeldLongIsAPaw() {
        let detector = CatDetector()
        // j k l land within 40 ms and stay down.
        for (i, key) in ([38, 40, 37] as [Int64]).enumerated() {
            XCTAssertFalse(detector.keyDown(key, at: Double(i) * 0.02).isCat,
                           "three keys down briefly must not lock on the press itself")
        }
        XCTAssertFalse(detector.evaluateHeld(at: 0.15).isCat, "not yet resting")
        let verdict = detector.evaluateHeld(at: 0.5)
        XCTAssertTrue(verdict.isCat)
        XCTAssertEqual(verdict.undoSince, 0, accuracy: 0.001)
    }

    func testRolloverReleasedQuicklyIsNotAPaw() {
        let detector = CatDetector()
        // Fast typing overlaps three keys for ~50 ms, then releases them.
        for (i, key) in ([38, 40, 37] as [Int64]).enumerated() {
            _ = detector.keyDown(key, at: Double(i) * 0.02)
        }
        detector.keyUp(38)
        detector.keyUp(40)
        XCTAssertFalse(detector.evaluateHeld(at: 0.5).isCat)
    }

    func testFourSpreadKeysHeldLongIsACat() {
        let detector = CatDetector()
        // q, p, z, / — nowhere near each other, but all held: a cat lying across.
        for (i, key) in ([12, 35, 6, 44] as [Int64]).enumerated() {
            _ = detector.keyDown(key, at: Double(i) * 0.05)
        }
        XCTAssertFalse(detector.evaluateHeld(at: 0.2).isCat)
        XCTAssertTrue(detector.evaluateHeld(at: 0.6).isCat)
    }

    func testThreeSpreadKeysHeldIsNotACat() {
        let detector = CatDetector()
        // W + A + Space — a gaming grip: three keys, but not paw-sized.
        for (i, key) in ([13, 0, 49] as [Int64]).enumerated() {
            _ = detector.keyDown(key, at: Double(i) * 0.02)
        }
        XCTAssertFalse(detector.evaluateHeld(at: 2.0).isCat)
    }

    func testSlowSettlingCatIsStillCaught() {
        let detector = CatDetector()
        // A cat shifting its weight: adjacent keys pressed 20 s apart. The old
        // 15 s expiry forgot the first one; now nothing is forgotten until
        // the key actually comes up.
        _ = detector.keyDown(38, at: 0)
        _ = detector.keyDown(40, at: 20)
        _ = detector.keyDown(37, at: 40)
        XCTAssertTrue(detector.evaluateHeld(at: 41).isCat)
    }

    func testSyncDropsKeysThatAreReallyUp() {
        let detector = CatDetector()
        for (i, key) in ([38, 40, 37] as [Int64]).enumerated() {
            _ = detector.keyDown(key, at: Double(i) * 0.02)
        }
        // Hardware says only j is still down (the k and l key-ups were missed).
        detector.syncHeld { $0 == 38 }
        XCTAssertEqual(detector.heldKeys, [38])
        XCTAssertFalse(detector.evaluateHeld(at: 5).isCat)
    }
}
