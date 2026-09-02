import AppKit
import CatAttackCore

/// Lock state, unlock-phrase matching, auto-unlock timer, and the overlay.
///
/// Only two things unlock: a human typing the phrase, or a long stretch with
/// no input of any kind, which means the cat has left. There is deliberately
/// nothing to click — a paw on the trackpad clicked its way out once.
final class LockController {
    private(set) var isLocked = false
    var onStateChange: (() -> Void)?

    let unlockPhrase: String
    let autoUnlockSeconds: TimeInterval

    private let matcher: UnlockPhraseMatcher
    private var overlay: LockOverlayWindow?
    private var toast: UnlockToastWindow?
    private var autoUnlockTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        let phrase = (defaults.string(forKey: "unlockPhrase") ?? "human").lowercased()
        unlockPhrase = phrase.isEmpty || !phrase.allSatisfy({ $0.isLetter }) ? "human" : phrase
        matcher = UnlockPhraseMatcher(phrase: unlockPhrase)
        let seconds = defaults.double(forKey: "autoUnlockSeconds")
        autoUnlockSeconds = seconds > 0 ? seconds : 60
    }

    func lock(reason: String) {
        if isLocked {
            restartAutoUnlockTimer()
            return
        }
        isLocked = true
        matcher.reset()
        restartAutoUnlockTimer()
        NSLog("CatAttack: LOCKED — \(reason)")

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
            window.orderFrontRegardless()
            self.overlay = window
        }
        onStateChange?()
    }

    func unlock(cause: String) {
        guard isLocked else { return }
        isLocked = false
        matcher.reset()
        NSLog("CatAttack: unlocked — \(cause)")
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        overlay?.orderOut(nil)
        overlay = nil
        onStateChange?()

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isLocked else { return }
            self.toast?.orderOut(nil)
            let toast = UnlockToastWindow(message: "Welcome back, human.")
            self.toast = toast
            toast.show(for: 2.5) { [weak self] in
                if self?.toast === toast { self?.toast = nil }
            }
        }
    }

    /// Called for every non-repeat key-down swallowed while locked.
    func handleLockedKeyDown(keyCode: Int64) {
        noteActivity()
        let matched = matcher.feed(keyCode: keyCode)
        overlay?.updateProgress(matched: matched)
        if matcher.isComplete {
            unlock(cause: "unlock phrase typed")
        }
    }

    /// Any input at all while locked — key repeats from a paw resting on a
    /// key, mouse motion from a cat on the trackpad — proves the cat is still
    /// here, so it pushes the auto-unlock back.
    func noteActivity() {
        guard isLocked else { return }
        restartAutoUnlockTimer()
    }

    private func restartAutoUnlockTimer() {
        autoUnlockTimer?.invalidate()
        // .common mode so the timer still fires while a menu is open.
        let timer = Timer(timeInterval: autoUnlockSeconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.unlock(cause: "no keyboard or mouse input for \(Int(self.autoUnlockSeconds)) s")
        }
        RunLoop.main.add(timer, forMode: .common)
        autoUnlockTimer = timer
    }
}
