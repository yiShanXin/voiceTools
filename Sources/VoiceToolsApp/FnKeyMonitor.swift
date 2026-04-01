import CoreGraphics
import Foundation
import ApplicationServices

struct TriggerKeyDebugEvent {
    let timestamp: Date
    let keycode: Int64
    let flagsRaw: UInt64
    let fnDown: Bool
    let rightCommandDown: Bool
    let triggerDown: Bool
    let mode: TriggerKeyOption
}

final class FnKeyMonitor {
    enum StartResult {
        case started
        case permissionDenied
        case tapCreationFailed
    }

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onDebugEvent: ((TriggerKeyDebugEvent) -> Void)?
    var triggerKeyMode: TriggerKeyOption = .fnOrRightCommand

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false
    private var isRightCommandDown = false
    private let rightCommandKeyCode: Int64 = 54
    private var canSuppressEvents = true

    func start() -> StartResult {
        guard tap == nil else { return .started }

        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
            if !CGPreflightListenEventAccess() {
                return .permissionDenied
            }
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard type == .flagsChanged,
                  let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handleFlagsChanged(proxy: proxy, event: event)
        }

        var options: CGEventTapOptions = .defaultTap
        var tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        if tap == nil {
            options = .listenOnly
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: options,
                eventsOfInterest: CGEventMask(mask),
                callback: callback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        }

        guard let tap else {
            return .tapCreationFailed
        }

        canSuppressEvents = (options == .defaultTap)
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return .started
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
        let wasTriggerDown = currentTriggerDown()
        var consumed = false

        let nowFnDown = event.flags.contains(.maskSecondaryFn)
        if nowFnDown != isFnDown {
            isFnDown = nowFnDown
            if triggerKeyMode.includesFn {
                consumed = true
            }
        }

        if keycode == rightCommandKeyCode {
            let nowRightCommandDown = event.flags.contains(.maskCommand)
            if nowRightCommandDown != isRightCommandDown {
                isRightCommandDown = nowRightCommandDown
                if triggerKeyMode.includesRightCommand {
                    consumed = true
                }
            }
        }

        let nowTriggerDown = currentTriggerDown()
        onDebugEvent?(TriggerKeyDebugEvent(
            timestamp: Date(),
            keycode: keycode,
            flagsRaw: UInt64(event.flags.rawValue),
            fnDown: isFnDown,
            rightCommandDown: isRightCommandDown,
            triggerDown: nowTriggerDown,
            mode: triggerKeyMode
        ))
        if wasTriggerDown != nowTriggerDown {
            if nowTriggerDown {
                onPress?()
            } else {
                onRelease?()
            }
        }

        if consumed && canSuppressEvents {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func currentTriggerDown() -> Bool {
        switch triggerKeyMode {
        case .fnOnly:
            return isFnDown
        case .fnOrRightCommand:
            return isFnDown || isRightCommandDown
        case .rightCommandOnly:
            return isRightCommandDown
        }
    }
}
