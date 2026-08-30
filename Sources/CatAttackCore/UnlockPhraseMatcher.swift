import Foundation

/// Matches a stream of swallowed keycodes against the unlock phrase.
/// Any non-letter key resets progress, so a cat cannot stumble into it.
public final class UnlockPhraseMatcher {
    public let phrase: String
    public private(set) var matchedCount = 0
    private var buffer = ""

    public init(phrase: String) {
        self.phrase = phrase.lowercased()
    }

    public var isComplete: Bool {
        matchedCount == phrase.count && !phrase.isEmpty
    }

    public func reset() {
        buffer = ""
        matchedCount = 0
    }

    /// Feed one key-down; returns how many characters of the phrase are
    /// currently matched (the longest suffix of what was typed that is a
    /// prefix of the phrase, so a stray "h" before "human" still unlocks).
    @discardableResult
    public func feed(keyCode: Int64) -> Int {
        guard let letter = KeyLayout.letter(for: keyCode) else {
            reset()
            return 0
        }
        buffer.append(letter)
        if buffer.count > phrase.count {
            buffer.removeFirst(buffer.count - phrase.count)
        }
        matchedCount = 0
        for length in stride(from: min(buffer.count, phrase.count), through: 1, by: -1)
        where buffer.hasSuffix(String(phrase.prefix(length))) {
            matchedCount = length
            break
        }
        return matchedCount
    }
}
