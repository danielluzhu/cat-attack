import AppKit
import CatAttackCore

/// Lock state, unlock-phrase matching, auto-unlock timer, and the overlay.
final class LockController {
    private(set) var isLocked = false
    var onStateChange: (() -> Void)?

    let unlockPhrase: String
    let autoUnlockSeconds: TimeInterval

    private let matcher: UnlockPhraseMatcher
    private var overlay: LockOverlayWindow?
    private var autoUnlockTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        let phrase = (defaults.string(forKey: "unlockPhrase") ?? "human").lowercased()
        unlockPhrase = phrase.isEmpty || !phrase.allSatisfy({ $0.isLetter }) ? "human" : phrase
        matcher = UnlockPhraseMatcher(phrase: unlockPhrase)
        let seconds = defaults.double(forKey: "autoUnlockSeconds")
        autoUnlockSeconds = seconds > 0 ? seconds : 10
    }

    func lock(reason: String) {
        if isLocked {
            restartAutoUnlockTimer()
            return
        }
        isLocked = true
        matcher.reset()
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
        matcher.reset()
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        overlay?.orderOut(nil)
        overlay = nil
        onStateChange?()
    }

    /// Called for every swallowed key-down while locked.
    func handleLockedKeyDown(keyCode: Int64) {
        restartAutoUnlockTimer()
        let matched = matcher.feed(keyCode: keyCode)
        overlay?.updateProgress(matched: matched)
        if matcher.isComplete {
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
