import AppKit
import CoreGraphics
import Foundation

final class TextInjector {
    private let inputSourceManager = InputSourceManager()

    func inject(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        let originalSource = inputSourceManager.currentSource()
        let shouldSwitch = inputSourceManager.isCJKInputSource(originalSource)
        if shouldSwitch {
            _ = inputSourceManager.switchToASCIISource()
            usleep(35_000)
        }

        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)
        simulateCmdV()
        usleep(90_000)

        if shouldSwitch {
            inputSourceManager.select(originalSource)
        }

        snapshot.restore(to: pasteboard)
    }

    private func simulateCmdV() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            return
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copied = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copied.setData(data, forType: type)
                }
            }
            return copied
        }
        return PasteboardSnapshot(items: copiedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
