import XCTest
@testable import CatAttackCore

/// A walking cat plants each paw on two or three keys at once, lifts within a
/// fraction of a second, and steps again. Fingers never land two keys within
/// 20 ms of each other; a paw always does. That simultaneity is the signal.
final class PawStepTests: XCTestCase {

    /// Presses `keys` `gapMs` apart, holding each for `holdMs`, starting at `start`.
    @discardableResult
    private func press(_ detector: CatDetector, _ keys: [Int64], at start: TimeInterval,
                       gapMs: Double, holdMs: Double = 120) -> DetectionVerdict {
        var verdict = DetectionVerdict.notCat
        for (i, key) in keys.enumerated() {
            let t = start + Double(i) * gapMs / 1000
            let v = detector.keyDown(key, at: t)
            if v.isCat { verdict = v }
        }
        for key in keys { detector.keyUp(key) }
        return verdict
    }

    func testThreeKeysWithinTwentyMillisecondsIsAPaw() {
        let detector = CatDetector()
        // One paw landing on u i j — 8 ms apart.
        let verdict = press(detector, [32, 34, 38], at: 0, gapMs: 8)
        XCTAssertTrue(verdict.isCat)
    }

    func testTwoWalkingStepsIsACat() {
        let detector = CatDetector()
        // Step 1: paw on j k (10 ms apart). Step 2, 600 ms later: paw on e r.
        XCTAssertFalse(press(detector, [38, 40], at: 0, gapMs: 10).isCat, "one step alone is not enough")
        XCTAssertTrue(press(detector, [14, 15], at: 0.6, gapMs: 10).isCat)
    }

    func testOneStepThenOrdinaryTypingIsNotACat() {
        let detector = CatDetector()
        XCTAssertFalse(press(detector, [38, 40], at: 0, gapMs: 10).isCat)
        // Then a human types "hello" at 100 ms per key.
        var t = 0.5
        for key in [4, 14, 37, 37, 31] as [Int64] {
            XCTAssertFalse(detector.keyDown(key, at: t).isCat)
            detector.keyUp(key)
            t += 0.1
        }
    }

    func testFastRolloverIsNotAStep() {
        let detector = CatDetector()
        // "er" rolled 35 ms apart, twice in a second — fast typing, not paws.
        XCTAssertFalse(press(detector, [14, 15], at: 0, gapMs: 35).isCat)
        XCTAssertFalse(press(detector, [14, 15], at: 0.5, gapMs: 35).isCat)
    }

    func testSimultaneousButDistantKeysAreNotAStep() {
        let detector = CatDetector()
        // Two hands landing on q and p at the same instant, twice: a chord, not a paw.
        XCTAssertFalse(press(detector, [12, 35], at: 0, gapMs: 5).isCat)
        XCTAssertFalse(press(detector, [12, 35], at: 0.5, gapMs: 5).isCat)
    }

    func testStepsTooFarApartInTimeDoNotAccumulate() {
        let detector = CatDetector()
        XCTAssertFalse(press(detector, [38, 40], at: 0, gapMs: 10).isCat)
        XCTAssertFalse(press(detector, [14, 15], at: 10, gapMs: 10).isCat, "10 s later is a different event")
    }

    func testUndoStartsAtTheFirstStep() {
        let detector = CatDetector()
        press(detector, [38, 40], at: 1.0, gapMs: 10)
        let verdict = press(detector, [14, 15], at: 1.6, gapMs: 10)
        XCTAssertTrue(verdict.isCat)
        XCTAssertEqual(verdict.undoSince, 1.0, accuracy: 0.001)
    }
}
