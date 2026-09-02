import AppKit
import ApplicationServices
import CoreGraphics
import CatAttackCore

/// Owns the CGEvent tap. While unlocked it feeds key events to the detector;
/// while locked it swallows key-downs (key-ups and modifiers pass through so
/// apps never see stuck keys) and forwards them to the lock controller so a
/// human can type the unlock phrase. Mouse, scroll and trackpad gestures are
/// swallowed too while locked — a cat that cannot type can still click.
final class KeyboardMonitor {
    let detector = CatDetector()

    /// Pointer and trackpad event types, by raw value: the CGEventType cases
    /// for buttons, motion, drags and scrolling, plus the AppKit gesture types
    /// (rotate 18, begin/end gesture 19–20, gesture 29, magnify 30, swipe 31,
    /// smart magnify 32) that also travel through the tap.
    private static let pointerEventTypes: Set<UInt32> = Set(
        [
            CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved, .leftMouseDragged,
            .rightMouseDragged, .otherMouseDragged, .scrollWheel,
        ].map(\.rawValue) + [18, 19, 20, 29, 30, 31, 32]
    )
    private let lock: LockController
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var supervisor: Timer?
    private var pawTimer: Timer?
    private var lastFailureLogged = ""

    private(set) var isRunning = false
    var isPaused = false
    /// Undo the cat's typing on lock. Off via `defaults write ... undoCatTyping -bool false`.
    var undoCatTyping = true
    /// Text-producing key-downs we let through, kept so they can be undone.
    private var delivered: [TimeInterval] = []
    /// Log every key event with a relative timestamp, to see what a real cat
    /// produces. On via `defaults write ... traceKeys -bool true`.
    var traceKeys = false
    private var traceOrigin: TimeInterval = 0
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

        // A paw that has settled presses nothing new, so no key event would
        // ever re-run the detector. Re-check the held keys on a timer instead.
        let paw = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pawTick()
        }
        RunLoop.main.add(paw, forMode: .common)
        pawTimer = paw
    }

    /// The real state of a key, straight from the HID system. Keeps the
    /// detector's idea of what is held honest even if a key-up was missed.
    private func keyIsDown(_ key: Int64) -> Bool {
        CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(key))
    }

    private func pawTick() {
        guard isRunning, !isPaused, !lock.isLocked, !detector.heldKeys.isEmpty else { return }
        detector.syncHeld(isDown: keyIsDown)
        let verdict = detector.evaluateHeld(at: ProcessInfo.processInfo.systemUptime)
        if verdict.isCat {
            engageLock(verdict)
        }
    }

    private func engageLock(_ verdict: DetectionVerdict) {
        detector.reset()
        // Everything delivered since the paw landed was the cat's.
        let catKeystrokes = delivered.filter { $0 >= verdict.undoSince }.count
        delivered.removeAll()
        lock.lock(reason: verdict.reason)
        if undoCatTyping {
            CatTypingUndo.eraseKeystrokes(count: catKeystrokes)
        }
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

        var mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        for raw in Self.pointerEventTypes {
            mask |= CGEventMask(1) << CGEventMask(raw)
        }

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

    private func trace(_ type: CGEventType, _ event: CGEvent) {
        guard traceKeys, type == .keyDown || type == .keyUp else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if traceOrigin == 0 || now - traceOrigin > 5 { traceOrigin = now }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let repeatFlag = event.getIntegerValueField(.keyboardEventAutorepeat) != 0 ? " repeat" : ""
        let name = KeyLayout.letter(for: key).map(String.init) ?? "#\(key)"
        NSLog("CatAttack trace: +%6.0fms %@ %@%@ held=%d",
              (now - traceOrigin) * 1000, type == .keyDown ? "DOWN" : "UP  ", name, repeatFlag,
              detector.heldKeys.count)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Our own undo backspaces must reach the app untouched, even while
        // locked, and must not be mistaken for a cat.
        if CatTypingUndo.isSynthetic(event) {
            return Unmanaged.passUnretained(event)
        }
        trace(type, event)

        if Self.pointerEventTypes.contains(type.rawValue) {
            guard lock.isLocked else { return Unmanaged.passUnretained(event) }
            // A cat on the trackpad is a cat still here, and gets no clicks.
            lock.noteActivity()
            return nil
        }

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            let key = event.getIntegerValueField(.keyboardEventKeycode)
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

            if lock.isLocked {
                if isRepeat {
                    // A paw resting on a key repeats it; that is the cat still
                    // being here, so it must keep the auto-unlock at bay.
                    lock.noteActivity()
                } else {
                    lock.handleLockedKeyDown(keyCode: key)
                }
                return nil  // swallow: this is the "locked" part
            }
            if isPaused || isRepeat {
                return Unmanaged.passUnretained(event)
            }

            let now = ProcessInfo.processInfo.systemUptime
            detector.syncHeld(isDown: keyIsDown)
            let verdict = detector.keyDown(key, at: now)
            if verdict.isCat {
                engageLock(verdict)
                return nil
            }

            if KeyLayout.producesText(key) {
                delivered.append(now)
                delivered.removeAll { now - $0 > 10 }
            }
            return Unmanaged.passUnretained(event)

        case .keyUp:
            if lock.isLocked {
                lock.noteActivity()
            } else if !isPaused {
                detector.keyUp(event.getIntegerValueField(.keyboardEventKeycode))
            }
            // Always deliver key-ups so apps don't end up with stuck keys.
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            // Modifiers pass through so nothing sticks, but a cat leaning on
            // Shift is still a cat present.
            lock.noteActivity()
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
