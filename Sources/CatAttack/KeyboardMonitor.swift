import AppKit
import ApplicationServices
import CoreGraphics
import CatAttackCore

/// Owns the CGEvent tap. While unlocked it feeds key events to the detector;
/// while locked it swallows key-downs (key-ups and modifiers pass through so
/// apps never see stuck keys) and forwards them to the lock controller so a
/// human can type the unlock phrase.
final class KeyboardMonitor {
    let detector = CatDetector()
    private let lock: LockController
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var supervisor: Timer?
    private var lastFailureLogged = ""

    private(set) var isRunning = false
    var isPaused = false
    /// Set when Accessibility is granted but the tap still cannot be created —
    /// usually a stale grant after the app binary was rebuilt.
    private(set) var trustedButTapFailed = false
    var onStateChange: (() -> Void)?

    init(lock: LockController) {
        self.lock = lock
    }

    /// Starts the tap and keeps it alive for the life of the app: retries while
    /// the tap is missing (permission not yet granted, or creation failed) and
    /// re-enables it if macOS ever disables it.
    func startSupervision() {
        attemptStart()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            self?.superviseTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        supervisor = timer
    }

    private func superviseTick() {
        guard let tap else {
            attemptStart()
            return
        }
        // macOS silently disables a tap it thinks is unresponsive; if that
        // happened while locked, typing the unlock phrase would go nowhere.
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
            NSLog("CatAttack: event tap was disabled — re-enabled by watchdog")
        }
    }

    private func logOnce(_ message: String) {
        guard lastFailureLogged != message else { return }
        lastFailureLogged = message
        NSLog("%@", message)
    }

    @discardableResult
    func attemptStart() -> Bool {
        guard tap == nil else { return true }

        guard AXIsProcessTrusted() else {
            trustedButTapFailed = false
            logOnce("CatAttack: waiting for Accessibility permission")
            onStateChange?()
            return false
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Accessibility is granted yet the tap was refused. This is what a
            // stale grant looks like after the app binary is rebuilt: macOS
            // still lists CatAttack as allowed, but the recorded code identity
            // no longer matches, so it denies the tap. Keep retrying so the app
            // recovers the moment the user re-grants, instead of sitting dead.
            trustedButTapFailed = true
            logOnce("CatAttack: Accessibility is granted but tapCreate failed — "
                + "stale permission for a rebuilt binary. Toggle CatAttack off "
                + "and on in System Settings > Privacy & Security > Accessibility.")
            onStateChange?()
            return false
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        trustedButTapFailed = false
        lastFailureLogged = ""
        NSLog("CatAttack: event tap active — watching for cats")
        onStateChange?()
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

            if lock.isLocked {
                if !isRepeat { lock.handleLockedKeyDown(keyCode: key) }
                return nil  // swallow: this is the "locked" part
            }
            if isPaused || isRepeat {
                return Unmanaged.passUnretained(event)
            }

            let verdict = detector.keyDown(key, at: ProcessInfo.processInfo.systemUptime)
            if verdict.isCat {
                detector.reset()
                lock.lock(reason: verdict.reason)
                return nil
            }
            return Unmanaged.passUnretained(event)

        case .keyUp:
            if !lock.isLocked && !isPaused {
                detector.keyUp(event.getIntegerValueField(.keyboardEventKeycode))
            }
            // Always deliver key-ups so apps don't end up with stuck keys.
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
