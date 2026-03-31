import AppKit

final class OverlayPanelController {
    private enum OverlayTheme {
        case light
        case dark
    }

    private let panel: NSPanel
    private let visualEffectView: NSVisualEffectView
    private let waveformView: WaveformView
    private let textField: NSTextField
    private var labelWidthConstraint: NSLayoutConstraint
    private var themeObserver: NSObjectProtocol?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        visualEffectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 28
        visualEffectView.layer?.masksToBounds = true

        waveformView = WaveformView(frame: .zero)
        waveformView.translatesAutoresizingMaskIntoConstraints = false

        textField = NSTextField(labelWithString: "请讲话…")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        textField.textColor = .white
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1

        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = content
        content.wantsLayer = true

        content.addSubview(visualEffectView)
        visualEffectView.addSubview(waveformView)
        visualEffectView.addSubview(textField)

        labelWidthConstraint = textField.widthAnchor.constraint(equalToConstant: 160)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: content.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            waveformView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 14),
            waveformView.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),

            textField.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            labelWidthConstraint
        ])

        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
        applyTheme()
    }

    deinit {
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
        }
    }

    func show(text: String) {
        applyTheme()
        updateText(text, animated: false)
        layoutPanelToBottomCenter()

        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        panel.contentView?.wantsLayer = true
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.92
        spring.toValue = 1.0
        spring.damping = 13
        spring.stiffness = 220
        spring.mass = 0.9
        spring.initialVelocity = 8
        spring.duration = 0.35
        panel.contentView?.layer?.add(spring, forKey: "entryScale")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func updateText(_ text: String, animated: Bool = true) {
        let shown = text.isEmpty ? "正在聆听…" : text
        textField.stringValue = shown

        let textWidth = shown.size(withAttributes: [.font: textField.font as Any]).width + 20
        let targetLabelWidth = min(max(textWidth, 160), 560)
        labelWidthConstraint.constant = targetLabelWidth

        let panelWidth = 14 + 44 + 12 + targetLabelWidth + 16
        let targetSize = NSSize(width: panelWidth, height: 56)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frameForSize(targetSize), display: true)
                panel.contentView?.layoutSubtreeIfNeeded()
            }
        } else {
            panel.setFrame(frameForSize(targetSize), display: true)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
    }

    func updateAudioLevel(_ level: CGFloat) {
        waveformView.update(level: level)
    }

    func hide() {
        guard panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        }

        panel.contentView?.wantsLayer = true
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 0.94
        scale.duration = 0.22
        scale.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.contentView?.layer?.add(scale, forKey: "exitScale")
    }

    private func layoutPanelToBottomCenter() {
        panel.setFrame(frameForSize(panel.frame.size), display: false)
    }

    private func frameForSize(_ size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visible.midX - size.width / 2
        let y = visible.minY + 72
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func applyTheme() {
        let theme = resolvedTheme()
        switch theme {
        case .dark:
            visualEffectView.material = .hudWindow
            textField.textColor = NSColor.white.withAlphaComponent(0.96)
            waveformView.barColor = NSColor.white.withAlphaComponent(0.96)
            visualEffectView.layer?.borderWidth = 1
            visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
            visualEffectView.layer?.shadowOpacity = 0.28
            visualEffectView.layer?.shadowRadius = 20
            visualEffectView.layer?.shadowOffset = .init(width: 0, height: 6)
            visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        case .light:
            visualEffectView.material = .popover
            textField.textColor = NSColor.black.withAlphaComponent(0.86)
            waveformView.barColor = NSColor.systemBlue.withAlphaComponent(0.9)
            visualEffectView.layer?.borderWidth = 1
            visualEffectView.layer?.borderColor = NSColor.black.withAlphaComponent(0.14).cgColor
            visualEffectView.layer?.shadowOpacity = 0.16
            visualEffectView.layer?.shadowRadius = 18
            visualEffectView.layer?.shadowOffset = .init(width: 0, height: 5)
            visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        }
    }

    private func resolvedTheme() -> OverlayTheme {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return (match == .darkAqua) ? .dark : .light
    }
}
