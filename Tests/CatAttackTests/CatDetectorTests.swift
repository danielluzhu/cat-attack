import XCTest
@testable import CatAttackCore

final class CatDetectorTests: XCTestCase {

    func testNormalTypingIsNotCat() {
        let detector = CatDetector()
        // "hello world" at ~80 ms per keystroke, each key released before the next.
        let keys: [Int64] = [4, 14, 37, 37, 31, 49, 13, 31, 15, 37, 2]
        var t = 0.0
        for key in keys {
            let verdict = detector.keyDown(key, at: t)
            XCTAssertFalse(verdict.isCat, "false positive: \(verdict.reason)")
            detector.keyUp(key)
            t += 0.08
        }
    }

    func testFastButSpreadTypingIsNotCat() {
        let detector = CatDetector()
        // Very fast burst, but spread across the keyboard like real hands: q p a / z
        let keys: [Int64] = [12, 35, 0, 44, 6]
        var t = 0.0
        for key in keys {
            let verdict = detector.keyDown(key, at: t)
            XCTAssertFalse(verdict.isCat, "false positive: \(verdict.reason)")
            detector.keyUp(key)
            t += 0.05
        }
    }

    func testManyHeldKeysIsCat() {
        let detector = CatDetector()
        // Four far-apart keys held simultaneously: q, p, z, /
        let keys: [Int64] = [12, 35, 6, 44]
        var verdict = DetectionVerdict.notCat
        for (i, key) in keys.enumerated() {
            verdict = detector.keyDown(key, at: Double(i) * 0.02)
        }
        XCTAssertTrue(verdict.isCat)
    }

    func testAdjacentHeldKeysIsCat() {
        let detector = CatDetector()
        // A paw landing on j, k, l — held together, physically adjacent.
        var verdict = DetectionVerdict.notCat
        for (i, key) in ([38, 40, 37] as [Int64]).enumerated() {
            verdict = detector.keyDown(key, at: Double(i) * 0.02)
        }
        XCTAssertTrue(verdict.isCat)
    }

    func testClusteredBurstIsCat() {
        let detector = CatDetector()
        // Five distinct neighboring keys (u i o j k) mashed within 300 ms,
        // each released immediately — a paw skittering across one region.
        let keys: [Int64] = [32, 34, 31, 38, 40]
        var t = 0.0
        var verdict = DetectionVerdict.notCat
        for key in keys {
            verdict = detector.keyDown(key, at: t)
            detector.keyUp(key)
            t += 0.05
        }
        XCTAssertTrue(verdict.isCat)
    }

    func testResetClearsState() {
        let detector = CatDetector()
        _ = detector.keyDown(38, at: 0)
        _ = detector.keyDown(40, at: 0.01)
        detector.reset()
        let verdict = detector.keyDown(37, at: 0.02)
        XCTAssertFalse(verdict.isCat)
    }
}
