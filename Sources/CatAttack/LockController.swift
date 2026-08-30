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
        restartAutoUnlockTimer()

        // Swallowing must engage instantly, but window creation is too slow
        // for the event tap callback we are called from — if the callback
        // stalls, macOS disables the tap and the lock can neither hold nor
        // be typed away. Defer all UI to the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isLocked, self.overlay == nil else { return }
            NSSound.beep()
            let window = LockOverlayWindow(
                phrase: self.unlockPhrase,
                autoUnlockSeconds: self.autoUnlockSeconds,
                reason: reason
            )
            window.onUnlockClicked = { [weak self] in self?.unlock() }
            window.orderFrontRegardless()
            self.overlay = window
        }
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
        // .common mode so the timer still fires while a menu is open.
        let timer = Timer(timeInterval: autoUnlockSeconds, repeats: false) { [weak self] _ in
            self?.unlock()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoUnlockTimer = timer
    }
}
