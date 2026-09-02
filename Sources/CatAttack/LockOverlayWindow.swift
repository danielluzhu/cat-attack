import AppKit

/// Full-attention floating panel shown while the keyboard is locked.
/// Purely informational: it never takes focus and has nothing to click, so a
/// cat on the trackpad cannot interact with it.
final class LockOverlayWindow: NSPanel {
    private let phrase: String
    private let progressLabel = NSTextField(labelWithString: "")

    init(phrase: String, autoUnlockSeconds: TimeInterval, reason: String) {
        self.phrase = phrase

        let size = NSSize(width: 480, height: 250)
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(
            x: screen.midX - size.width / 2,
            y: screen.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        super.init(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 20
        contentView = effect

        let title = NSTextField(labelWithString: "🙀  Cat detected on the keyboard!")
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let reasonLabel = NSTextField(labelWithString: reason)
        reasonLabel.font = .systemFont(ofSize: 13)
        reasonLabel.textColor = .secondaryLabelColor

        let instruction = NSTextField(labelWithString: "Keyboard, mouse and trackpad are locked. Type “\(phrase)” to unlock.")
        instruction.font = .systemFont(ofSize: 15)

        progressLabel.font = .monospacedSystemFont(ofSize: 26, weight: .semibold)
        updateProgress(matched: 0)

        let autoLabel = NSTextField(
            labelWithString: "Unlocks by itself after \(Int(autoUnlockSeconds)) s with no keyboard or mouse activity at all.")
        autoLabel.font = .systemFont(ofSize: 12)
        autoLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, reasonLabel, instruction, progressLabel, autoLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])
    }

    func updateProgress(matched: Int) {
        let chars = phrase.enumerated().map { index, char in
            index < matched ? String(char) : "_"
        }
        progressLabel.stringValue = chars.joined(separator: " ")
    }
}
