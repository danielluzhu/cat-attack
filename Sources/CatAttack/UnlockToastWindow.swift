import AppKit

/// Small self-dismissing popup confirming the keyboard is live again.
final class UnlockToastWindow: NSPanel {
    override var canBecomeKey: Bool { false }

    init(message: String) {
        let size = NSSize(width: 340, height: 110)
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
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        contentView = effect

        let title = NSTextField(labelWithString: "✅  Keyboard unlocked")
        title.font = .systemFont(ofSize: 18, weight: .bold)
        let subtitle = NSTextField(labelWithString: message)
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])
    }

    /// Shows the toast, then fades it out after `duration` seconds.
    /// Completion runs once the toast is gone so the owner can drop it.
    func show(for duration: TimeInterval, completion: @escaping () -> Void) {
        alphaValue = 1
        orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else {
                completion()
                return
            }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
                completion()
            })
        }
    }
}
