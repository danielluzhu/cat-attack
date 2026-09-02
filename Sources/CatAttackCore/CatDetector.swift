import Foundation

public struct DetectionVerdict {
    public let isCat: Bool
    public let reason: String
    /// Timestamp of the earliest key press that counted towards this verdict.
    /// Keystrokes delivered from here on are the cat's, so they can be undone.
    public let undoSince: TimeInterval

    public init(isCat: Bool, reason: String, undoSince: TimeInterval = 0) {
        self.isCat = isCat
        self.reason = reason
        self.undoSince = undoSince
    }

    public static let notCat = DetectionVerdict(isCat: false, reason: "")
}

public enum Sensitivity: String, CaseIterable {
    case low, normal, high
}

/// Heuristic detector for cat-on-keyboard input.
///
/// Signals, in order of confidence:
/// 1. Many keys held down at the same time (paws press whole regions).
/// 2. Several *physically adjacent* keys held at once (paw-sized press).
/// 3. A fast burst of distinct keys that are all clustered on the keyboard —
///    humans typing that fast spread their fingers across the whole board.
public final class CatDetector {
    /// Held keys at or above this count is a cat, regardless of position.
    public var maxHeldKeys = 5
    /// Held keys at or above this count is a cat if they are clustered.
    public var clusteredHeldKeys = 4
    /// Max pairwise distance (in key units) for held keys to count as one paw.
    public var heldClusterRadius = 2.2
    /// Distinct keys within `burstWindow` at or above this count is a cat if clustered.
    public var burstCount = 6
    public var burstWindow: TimeInterval = 0.25
    public var burstClusterRadius = 2.5
    /// Distinct keys within `burstWindow` at or above this count is a cat
    /// wherever they are: 7 keys in 250 ms is 28 keys/second, roughly triple
    /// what a fast human typist sustains, so only mashing reaches it.
    public var mashCount = 7

    // A hand swiped across the keys is fast enough to look like mashing, so
    // the rate rules ignore input that traces a swipe: a contiguous, mostly
    // straight, one-directional path. A paw cannot do that — its keys land in
    // whatever order the toes touch down, so the path doubles back on itself.
    /// Largest gap between consecutive keys that still counts as one drag.
    public var swipeMaxStep = 2.5
    /// How far the path must travel end to end, in key widths.
    public var swipeMinSpan = 3.0
    /// End-to-end distance divided by path length; 1.0 is a perfectly straight line.
    public var swipeStraightness = 0.6
    /// Keys needed before a path can be judged a swipe at all.
    public var swipeMinKeys = 4

    // A paw resting on the keys is told apart from typing by duration: rollover
    // overlaps keys for tens of milliseconds, a paw stays down for hundreds.
    // These rules run from a timer, so a cat that has settled and gone still
    // is caught even though it presses nothing new.
    /// How long keys must stay down together before they count as resting.
    public var sustainedHoldSeconds: TimeInterval = 0.3
    /// Clustered keys held that long are a paw.
    public var sustainedClusteredKeys = 3
    public var sustainedClusterRadius = 2.5
    /// Keys held that long anywhere are a cat lying across the keyboard.
    public var sustainedAnyKeys = 4

    public func apply(_ sensitivity: Sensitivity) {
        switch sensitivity {
        case .high:
            // Trigger-happy: fast rollover typing can hold 3 adjacent keys.
            maxHeldKeys = 4
            clusteredHeldKeys = 3
            burstCount = 5
            burstWindow = 0.30
            burstClusterRadius = 3.0
            mashCount = 6
            sustainedHoldSeconds = 0.25
            sustainedClusteredKeys = 3
        case .normal:
            maxHeldKeys = 5
            clusteredHeldKeys = 4
            burstCount = 6
            burstWindow = 0.25
            burstClusterRadius = 2.5
            mashCount = 7
            sustainedHoldSeconds = 0.3
            sustainedClusteredKeys = 3
        case .low:
            maxHeldKeys = 6
            clusteredHeldKeys = 5
            burstCount = 8
            burstWindow = 0.25
            burstClusterRadius = 2.2
            mashCount = 9
            sustainedHoldSeconds = 0.5
            sustainedClusteredKeys = 4
        }
    }

    private var held: [Int64: TimeInterval] = [:]
    private var recent: [(t: TimeInterval, key: Int64)] = []

    public init() {}

    public func keyUp(_ key: Int64) {
        held.removeValue(forKey: key)
    }

    public var heldKeys: Set<Int64> { Set(held.keys) }

    /// Reconciles held keys with the real key state, so a missed key-up cannot
    /// leave a phantom key held and a genuinely held key is never forgotten.
    public func syncHeld(isDown: (Int64) -> Bool) {
        for key in held.keys where !isDown(key) {
            held.removeValue(forKey: key)
        }
    }

    /// Re-checks the keys still down without a new press. Call periodically.
    public func evaluateHeld(at t: TimeInterval) -> DetectionVerdict {
        guard held.count >= sustainedClusteredKeys,
              let newest = held.values.max(),
              t - newest >= sustainedHoldSeconds
        else { return .notCat }

        let ms = Int((t - newest) * 1000)
        let since = held.values.min() ?? t

        if held.count >= sustainedAnyKeys {
            return DetectionVerdict(
                isCat: true,
                reason: "\(held.count) keys held down for \(ms) ms (cat lying on the keyboard)",
                undoSince: since)
        }

        let pos = held.keys.compactMap(KeyLayout.position(for:))
        if pos.count >= sustainedClusteredKeys, maxPairwiseDistance(pos) <= sustainedClusterRadius {
            return DetectionVerdict(
                isCat: true,
                reason: "\(held.count) neighboring keys held for \(ms) ms (paw resting on the keys)",
                undoSince: since)
        }
        return .notCat
    }

    public func reset() {
        held.removeAll()
        recent.removeAll()
    }

    public func keyDown(_ key: Int64, at t: TimeInterval) -> DetectionVerdict {
        held[key] = t
        recent.append((t: t, key: key))
        recent.removeAll { t - $0.t > burstWindow }

        let heldSince = held.values.min() ?? t
        let burstSince = recent.map(\.t).min() ?? t

        if held.count >= maxHeldKeys {
            return DetectionVerdict(
                isCat: true,
                reason: "\(held.count) keys held down at once",
                undoSince: heldSince)
        }

        if held.count >= clusteredHeldKeys {
            let pos = held.keys.compactMap(KeyLayout.position(for:))
            if pos.count >= clusteredHeldKeys, maxPairwiseDistance(pos) <= heldClusterRadius {
                return DetectionVerdict(
                    isCat: true,
                    reason: "\(held.count) neighboring keys held at once (paw-sized press)",
                    undoSince: heldSince)
            }
        }

        let uniqueRecent = Set(recent.map(\.key))

        // Rate alone cannot tell a swiped hand from a paw, so let a swipe pass.
        // The held-key rules above still apply: a paw resting on the keys is a
        // cat however it got there.
        if looksLikeSwipe(orderedRecentKeys()) {
            return .notCat
        }

        if uniqueRecent.count >= mashCount {
            let ms = Int(burstWindow * 1000)
            return DetectionVerdict(
                isCat: true,
                reason: "\(uniqueRecent.count) different keys in \(ms) ms (too fast to be typing)",
                undoSince: min(burstSince, heldSince))
        }

        if uniqueRecent.count >= burstCount {
            let pos = uniqueRecent.compactMap(KeyLayout.position(for:))
            if pos.count >= 3, maxPairwiseDistance(pos) <= burstClusterRadius {
                let ms = Int(burstWindow * 1000)
                return DetectionVerdict(
                    isCat: true,
                    reason: "\(uniqueRecent.count) clustered keys mashed within \(ms) ms",
                    undoSince: min(burstSince, heldSince))
            }
        }

        return .notCat
    }

    /// Recent keys in the order they were pressed, without consecutive repeats.
    private func orderedRecentKeys() -> [Int64] {
        var keys: [Int64] = []
        for entry in recent where keys.last != entry.key {
            keys.append(entry.key)
        }
        return keys
    }

    /// True when the keys trace a drag across the keyboard: every step lands on
    /// a neighbouring key, the path travels a real distance, and it keeps going
    /// one way instead of doubling back.
    func looksLikeSwipe(_ keys: [Int64]) -> Bool {
        let pts = keys.compactMap(KeyLayout.position(for:))
        guard pts.count >= swipeMinKeys, pts.count == keys.count else { return false }

        var pathLength = 0.0
        for i in 1..<pts.count {
            let step = distance(pts[i - 1], pts[i])
            // A jump to a distant key is not a drag; it is a leap.
            if step > swipeMaxStep { return false }
            pathLength += step
        }
        guard pathLength > 0 else { return false }

        let span = distance(pts[0], pts[pts.count - 1])
        return span >= swipeMinSpan && span / pathLength >= swipeStraightness
    }

    private func distance(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func maxPairwiseDistance(_ pts: [(x: Double, y: Double)]) -> Double {
        var maxDist = 0.0
        for i in 0..<pts.count {
            for j in (i + 1)..<pts.count {
                let dx = pts[i].x - pts[j].x
                let dy = pts[i].y - pts[j].y
                maxDist = max(maxDist, (dx * dx + dy * dy).squareRoot())
            }
        }
        return maxDist
    }
}
