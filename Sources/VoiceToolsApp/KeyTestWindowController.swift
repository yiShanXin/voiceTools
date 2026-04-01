import AppKit

final class KeyTestWindowController: NSWindowController {
    private let statusLabel = NSTextField(labelWithString: "Waiting for key events...")
    private let textView = NSTextView()
    private var lines: [String] = []

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 760, height: 420)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(contentRect: contentRect, styleMask: style, backing: .buffered, defer: false)
        window.title = "Key Test Panel"
        window.center()
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        statusLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(statusLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = "No key events yet.\n"
        scrollView.documentView = textView

        let tipLabel = NSTextField(labelWithString: "Tip: Press Fn / Right Command and watch keycode + flags changes.")
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        tipLabel.font = NSFont.systemFont(ofSize: 12)
        tipLabel.textColor = .secondaryLabelColor
        contentView.addSubview(tipLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: tipLabel.topAnchor, constant: -10),

            tipLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            tipLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            tipLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func append(event: TriggerKeyDebugEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let t = formatter.string(from: event.timestamp)
        let line = "\(t) keycode=\(event.keycode) flags=0x\(String(event.flagsRaw, radix: 16)) fn=\(event.fnDown) rightCmd=\(event.rightCommandDown) trigger=\(event.triggerDown) mode=\(event.mode.rawValue)"

        lines.append(line)
        if lines.count > 400 {
            lines.removeFirst(lines.count - 400)
        }

        statusLabel.stringValue = "Latest: keycode=\(event.keycode), fn=\(event.fnDown), rightCmd=\(event.rightCommandDown), trigger=\(event.triggerDown)"
        textView.string = lines.joined(separator: "\n")
        textView.scrollToEndOfDocument(nil)
    }
}
