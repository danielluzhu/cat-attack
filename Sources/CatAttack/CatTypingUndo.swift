import CoreGraphics
import Foundation

/// Erases the characters a cat managed to type before detection fired, by
/// posting that many backspaces to the frontmost app.
enum CatTypingUndo {
    /// Stamped on the backspaces we post so our own tap lets them through
    /// instead of swallowing them along with the cat's keys.
    static let syntheticMarker: Int64 = 0x4341_5421  // "CAT!"

    /// Never delete more than this, so a bad verdict cannot eat a document.
    static let maxKeystrokes = 25

    static func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == syntheticMarker
    }

    /// Posts `count` backspaces off the main thread, spaced slightly apart so
    /// apps that coalesce rapid input still process each one.
    static func eraseKeystrokes(count: Int) {
        let capped = min(count, maxKeystrokes)
        guard capped > 0 else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGEventSource(stateID: .privateState) else { return }
            let deleteKey: CGKeyCode = 51
            for _ in 0..<capped {
                guard
                    let down = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: true),
                    let up = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: false)
                else { return }
                for event in [down, up] {
                    event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
                    event.post(tap: .cghidEventTap)
                }
                Thread.sleep(forTimeInterval: 0.006)
            }
            NSLog("CatAttack: erased \(capped) keystroke(s) typed by the cat")
        }
    }
}
