import AppKit
import ApplicationServices
import CatAttackCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let lock = LockController()
    private var monitor: KeyboardMonitor!
    private var statusBar: StatusBarController!
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = KeyboardMonitor(lock: lock)
        applyDetectorOverrides()
        statusBar = StatusBarController(lock: lock, monitor: monitor)
        lock.onStateChange = { [weak self] in self?.statusBar.refresh() }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            monitor.start()
            statusBar.refresh()
        } else {
            // Wait for the user to grant Accessibility, then start the tap.
            permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self.permissionPollTimer = nil
                    self.monitor.start()
                    self.statusBar.refresh()
                }
            }
        }
    }

    /// Detection thresholds can be tuned via `defaults write` — see README.
    private func applyDetectorOverrides() {
        let defaults = UserDefaults.standard
        let detector = monitor.detector
        if let raw = defaults.string(forKey: "sensitivity"),
           let sensitivity = Sensitivity(rawValue: raw) {
            detector.apply(sensitivity)
        }
        if defaults.integer(forKey: "maxHeldKeys") > 0 {
            detector.maxHeldKeys = defaults.integer(forKey: "maxHeldKeys")
        }
        if defaults.integer(forKey: "burstCount") > 0 {
            detector.burstCount = defaults.integer(forKey: "burstCount")
        }
        if defaults.double(forKey: "burstWindowMs") > 0 {
            detector.burstWindow = defaults.double(forKey: "burstWindowMs") / 1000
        }
    }
}
