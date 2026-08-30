import XCTest
@testable import CatAttackCore

final class UnlockPhraseMatcherTests: XCTestCase {
    // keycodes: h=4 u=32 m=46 a=0 n=45

    func testTypingPhraseUnlocks() {
        let m = UnlockPhraseMatcher(phrase: "human")
        for key in [4, 32, 46, 0, 45] as [Int64] { m.feed(keyCode: key) }
        XCTAssertTrue(m.isComplete)
    }

    func testStrayLettersBeforePhraseStillUnlocks() {
        let m = UnlockPhraseMatcher(phrase: "human")
        // "hhuman" — a false start, then the phrase
        for key in [4, 4, 32, 46, 0, 45] as [Int64] { m.feed(keyCode: key) }
        XCTAssertTrue(m.isComplete)
    }

    func testCatMashThenPhraseUnlocks() {
        let m = UnlockPhraseMatcher(phrase: "human")
        for key in [38, 40, 37, 41, 49, 36] as [Int64] { m.feed(keyCode: key) }
        XCTAssertFalse(m.isComplete)
        for key in [4, 32, 46, 0, 45] as [Int64] { m.feed(keyCode: key) }
        XCTAssertTrue(m.isComplete)
    }

    func testNonLetterKeyResetsProgress() {
        let m = UnlockPhraseMatcher(phrase: "human")
        for key in [4, 32, 46] as [Int64] { m.feed(keyCode: key) }
        XCTAssertEqual(m.matchedCount, 3)
        m.feed(keyCode: 49)  // space
        XCTAssertEqual(m.matchedCount, 0)
        for key in [4, 32, 46, 0, 45] as [Int64] { m.feed(keyCode: key) }
        XCTAssertTrue(m.isComplete)
    }

    func testProgressReportsPartialMatch() {
        let m = UnlockPhraseMatcher(phrase: "human")
        XCTAssertEqual(m.feed(keyCode: 4), 1)   // h
        XCTAssertEqual(m.feed(keyCode: 32), 2)  // u
        XCTAssertEqual(m.feed(keyCode: 7), 0)   // x — wrong letter
        XCTAssertEqual(m.feed(keyCode: 4), 1)   // h starts over
    }

    func testResetClearsProgress() {
        let m = UnlockPhraseMatcher(phrase: "human")
        for key in [4, 32, 46, 0] as [Int64] { m.feed(keyCode: key) }
        m.reset()
        m.feed(keyCode: 45)  // "n" alone must not complete
        XCTAssertFalse(m.isComplete)
        XCTAssertEqual(m.matchedCount, 0)
    }
}
