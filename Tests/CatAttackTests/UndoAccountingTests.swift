import XCTest
@testable import CatAttackCore

/// The lock erases the characters that reached the document before detection
/// fired. These cover the core half of that: which keystrokes are implicated,
/// and which of them a backspace can actually undo.
final class UndoAccountingTests: XCTestCase {

    func testVerdictReportsWhenThePawLanded() {
        let detector = CatDetector()
        var t = 0.0
        // Human types "hel", pauses, then a paw lands on u/i/j/k.
        for key in [4, 14, 37] as [Int64] {
            _ = detector.keyDown(key, at: t)
            detector.keyUp(key)
            t += 0.15
        }
        t += 1.0
        let pawStart = t
        var verdict = DetectionVerdict.notCat
        for key in [32, 34, 38, 40] as [Int64] {
            verdict = detector.keyDown(key, at: t)
            if verdict.isCat { break }
            t += 0.02
        }
        XCTAssertTrue(verdict.isCat)
        XCTAssertEqual(verdict.undoSince, pawStart, accuracy: 0.001,
                       "undo must start at the paw, not at the human's typing")
    }

    func testUndoWindowExcludesEarlierHumanTyping() {
        let detector = CatDetector()
        var t = 0.0
        var delivered: [TimeInterval] = []
        for key in [4, 14, 37, 37, 31] as [Int64] {
            _ = detector.keyDown(key, at: t)
            delivered.append(t)
            detector.keyUp(key)
            t += 0.12
        }
        t += 0.8
        var verdict = DetectionVerdict.notCat
        for key in [12, 0, 6, 15, 44, 35, 50] as [Int64] {
            verdict = detector.keyDown(key, at: t)
            if verdict.isCat { break }
            delivered.append(t)
            detector.keyUp(key)
            t += 0.03
        }
        XCTAssertTrue(verdict.isCat)
        let toUndo = delivered.filter { $0 >= verdict.undoSince }.count
        XCTAssertEqual(toUndo, 6, "only the cat's delivered keystrokes are undone")
    }

    func testOnlyCharacterInsertingKeysCount() {
        XCTAssertTrue(KeyLayout.producesText(0))   // a
        XCTAssertTrue(KeyLayout.producesText(49))  // space
        XCTAssertFalse(KeyLayout.producesText(36)) // return
        XCTAssertFalse(KeyLayout.producesText(48)) // tab
        XCTAssertFalse(KeyLayout.producesText(51)) // delete
    }
}
