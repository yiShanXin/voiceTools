import CoreGraphics
import Foundation

final class FnKeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false

    func start() {
        guard tap == nil else { return }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard type == .flagsChanged,
                  let userInfo else {
                return Unmanaged.passRetained(event)
            }

            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handleFlagsChanged(proxy: proxy, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.tap = nil
        self.runLoopSource = nil
    }

    private func handleFlagsChanged(proxy: CGEventTapProxy, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keycode == 63 else {
            return Unmanaged.passRetained(event)
        }

        let nowFnDown = event.flags.contains(.maskSecondaryFn)
        if nowFnDown != isFnDown {
            isFnDown = nowFnDown
            if nowFnDown {
                onPress?()
            } else {
                onRelease?()
            }
        }

        // Swallow Fn flagsChanged events to avoid triggering system emoji picker.
        return nil
    }
}
