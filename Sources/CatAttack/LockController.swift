import AppKit
import CatAttackCore

/// Lock state, unlock-phrase matching, auto-unlock timer, and the overlay.
final class LockController {
    private(set) var isLocked = false
    var onStateChange: (() -> Void)?

    let unlockPhrase: String
    let autoUnlockSeconds: TimeInterval

    private var typedBuffer = ""
    private var overlay: LockOverlayWindow?
    private var autoUnlockTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        let phrase = (defaults.string(forKey: "unlockPhrase") ?? "human").lowercased()
        unlockPhrase = phrase.isEmpty || !phrase.allSatisfy({ $0.isLetter }) ? "human" : phrase
        let seconds = defaults.double(forKey: "autoUnlockSeconds")
        autoUnlockSeconds = seconds > 0 ? seconds : 10
    }

    func lock(reason: String) {
        if isLocked {
            restartAutoUnlockTimer()
            return
        }
        isLocked = true
        typedBuffer = ""
        NSSound.beep()

        let window = LockOverlayWindow(
            phrase: unlockPhrase,
            autoUnlockSeconds: autoUnlockSeconds,
            reason: reason
        )
        window.onUnlockClicked = { [weak self] in self?.unlock() }
        window.orderFrontRegardless()
        overlay = window

        restartAutoUnlockTimer()
        onStateChange?()
    }

    func unlock() {
        guard isLocked else { return }
        isLocked = false
        typedBuffer = ""
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        overlay?.orderOut(nil)
        overlay = nil
        onStateChange?()
    }

    /// Called for every swallowed key-down while locked.
    func handleLockedKeyDown(keyCode: Int64) {
        restartAutoUnlockTimer()

        guard let letter = KeyLayout.letter(for: keyCode) else {
            typedBuffer = ""
            overlay?.updateProgress(matched: 0)
            return
        }
        typedBuffer.append(letter)
        if typedBuffer.count > unlockPhrase.count {
            typedBuffer.removeFirst(typedBuffer.count - unlockPhrase.count)
        }

        // Longest suffix of what was typed that is a prefix of the phrase,
        // so a stray "h" before "human" still unlocks.
        var matched = 0
        for length in stride(from: min(typedBuffer.count, unlockPhrase.count), through: 1, by: -1) {
            if typedBuffer.hasSuffix(String(unlockPhrase.prefix(length))) {
                matched = length
                break
            }
        }
        overlay?.updateProgress(matched: matched)

        if matched == unlockPhrase.count {
            unlock()
        }
    }

    private func restartAutoUnlockTimer() {
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = Timer.scheduledTimer(withTimeInterval: autoUnlockSeconds, repeats: false) { [weak self] _ in
            self?.unlock()
        }
    }
}
