import AppKit
import CatAttackCore

final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let lock: LockController
    private let monitor: KeyboardMonitor

    init(lock: LockController, monitor: KeyboardMonitor) {
        self.lock = lock
        self.monitor = monitor
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        refresh()
    }

    func refresh() {
        if lock.isLocked {
            item.button?.title = "🙀"
        } else if !monitor.isRunning {
            item.button?.title = "⚠️"
        } else if monitor.isPaused {
            item.button?.title = "💤"
        } else {
            item.button?.title = "🐾"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status: String
        if lock.isLocked {
            status = "Keyboard is LOCKED"
        } else if monitor.trustedButTapFailed {
            status = "Permission is stale — re-grant to activate"
        } else if !monitor.isRunning {
            status = "Waiting for Accessibility permission…"
        } else if monitor.isPaused {
            status = "Detection paused"
        } else {
            status = "Watching for cats"
        }
        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        if lock.isLocked {
            menu.addItem(makeItem("Unlock keyboard", #selector(unlockNow)))
        } else if monitor.isRunning {
            menu.addItem(makeItem("Lock keyboard now", #selector(lockNow)))
            let pause = makeItem(
                monitor.isPaused ? "Resume cat detection" : "Pause cat detection",
                #selector(togglePause))
            menu.addItem(pause)
            menu.addItem(makeSensitivityMenu())
        } else {
            if monitor.trustedButTapFailed {
                let hint = NSMenuItem(
                    title: "Turn CatAttack off, then on again in the list.",
                    action: nil, keyEquivalent: "")
                hint.isEnabled = false
                menu.addItem(hint)
            }
            menu.addItem(makeItem("Open Accessibility Settings…", #selector(openAccessibilitySettings)))
        }

        menu.addItem(.separator())
        let info = NSMenuItem(
            title: "Unlock phrase: “\(lock.unlockPhrase)”  ·  auto-unlock \(Int(lock.autoUnlockSeconds)) s",
            action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit CatAttack", #selector(quit), key: "q"))
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func makeSensitivityMenu() -> NSMenuItem {
        let current = UserDefaults.standard.string(forKey: "sensitivity")
            .flatMap(Sensitivity.init(rawValue:)) ?? .normal
        let submenu = NSMenu()
        let titles: [(Sensitivity, String)] = [
            (.low, "Low — lock only on obvious cats"),
            (.normal, "Normal"),
            (.high, "High — lock eagerly"),
        ]
        for (sensitivity, title) in titles {
            let item = makeItem(title, #selector(setSensitivity(_:)))
            item.representedObject = sensitivity.rawValue
            item.state = sensitivity == current ? .on : .off
            submenu.addItem(item)
        }
        let parent = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    @objc private func setSensitivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let sensitivity = Sensitivity(rawValue: raw) else { return }
        UserDefaults.standard.set(raw, forKey: "sensitivity")
        monitor.detector.apply(sensitivity)
        monitor.detector.reset()
    }

    @objc private func lockNow() {
        lock.lock(reason: "Locked manually from the menu bar")
        refresh()
    }

    @objc private func unlockNow() {
        lock.unlock(cause: "menu bar")
        refresh()
    }

    @objc private func togglePause() {
        monitor.isPaused.toggle()
        monitor.detector.reset()
        refresh()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
