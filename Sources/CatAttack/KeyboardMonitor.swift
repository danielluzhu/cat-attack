import AppKit
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
    private var watchdog: Timer?

    private(set) var isRunning = false
    var isPaused = false

    init(lock: LockController) {
        self.lock = lock
    }

    func start() {
        guard tap == nil else { return }

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
            NSLog("CatAttack: failed to create event tap (Accessibility permission missing?)")
            return
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true

        // macOS silently disables a tap it thinks is unresponsive; if that
        // happened while locked, typing the unlock phrase would go nowhere.
        // Revive the tap whenever it drops.
        let watchdogTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, let tap = self.tap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                NSLog("CatAttack: event tap was disabled — re-enabled by watchdog")
            }
        }
        RunLoop.main.add(watchdogTimer, forMode: .common)
        watchdog = watchdogTimer
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
