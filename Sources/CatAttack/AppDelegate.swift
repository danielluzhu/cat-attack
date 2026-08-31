import AppKit
import ApplicationServices
import CatAttackCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let lock = LockController()
    private var monitor: KeyboardMonitor!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = KeyboardMonitor(lock: lock)
        applyDetectorOverrides()
        statusBar = StatusBarController(lock: lock, monitor: monitor)
        lock.onStateChange = { [weak self] in self?.statusBar.refresh() }
        monitor.onStateChange = { [weak self] in self?.statusBar.refresh() }

        // Prompt once if needed; supervision then acquires the tap as soon as
        // permission exists and retries for as long as it does not.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        monitor.startSupervision()
        statusBar.refresh()
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
