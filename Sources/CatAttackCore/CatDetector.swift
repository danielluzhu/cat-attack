import Foundation

public struct DetectionVerdict {
    public let isCat: Bool
    public let reason: String

    public static let notCat = DetectionVerdict(isCat: false, reason: "")
}

/// Heuristic detector for cat-on-keyboard input.
///
/// Signals, in order of confidence:
/// 1. Many keys held down at the same time (paws press whole regions).
/// 2. Three or more *physically adjacent* keys held at once (paw-sized press).
/// 3. A fast burst of distinct keys that are all clustered on the keyboard —
///    humans typing that fast spread their fingers across the whole board.
public final class CatDetector {
    /// Held keys at or above this count is a cat, regardless of position.
    public var maxHeldKeys = 4
    /// Held keys at or above this count is a cat if they are clustered.
    public var clusteredHeldKeys = 3
    /// Max pairwise distance (in key units) for held keys to count as one paw.
    public var heldClusterRadius = 2.2
    /// Distinct keys within `burstWindow` at or above this count is a cat if clustered.
    public var burstCount = 5
    public var burstWindow: TimeInterval = 0.30
    public var burstClusterRadius = 3.0

    private var held: [Int64: TimeInterval] = [:]
    private var recent: [(t: TimeInterval, key: Int64)] = []

    public init() {}

    public func keyUp(_ key: Int64) {
        held.removeValue(forKey: key)
    }

    public func reset() {
        held.removeAll()
        recent.removeAll()
    }

    public func keyDown(_ key: Int64, at t: TimeInterval) -> DetectionVerdict {
        // Drop keys whose key-up we may have missed (app started mid-press, etc).
        held = held.filter { t - $0.value < 15 }
        held[key] = t
        recent.append((t: t, key: key))
        recent.removeAll { t - $0.t > burstWindow }

        if held.count >= maxHeldKeys {
            return DetectionVerdict(isCat: true, reason: "\(held.count) keys held down at once")
        }

        if held.count >= clusteredHeldKeys {
            let pos = held.keys.compactMap(KeyLayout.position(for:))
            if pos.count >= clusteredHeldKeys, maxPairwiseDistance(pos) <= heldClusterRadius {
                return DetectionVerdict(isCat: true, reason: "\(held.count) neighboring keys held at once (paw-sized press)")
            }
        }

        let uniqueRecent = Set(recent.map(\.key))
        if uniqueRecent.count >= burstCount {
            let pos = uniqueRecent.compactMap(KeyLayout.position(for:))
            if pos.count >= 3, maxPairwiseDistance(pos) <= burstClusterRadius {
                let ms = Int(burstWindow * 1000)
                return DetectionVerdict(isCat: true, reason: "\(uniqueRecent.count) clustered keys mashed within \(ms) ms")
            }
        }

        return .notCat
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
