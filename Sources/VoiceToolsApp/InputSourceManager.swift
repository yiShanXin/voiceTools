import Carbon
import Foundation

final class InputSourceManager {
    typealias Source = TISInputSource

    func currentSource() -> Source? {
        TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    }

    func isCJKInputSource(_ source: Source?) -> Bool {
        guard let source else { return false }

        if let array: [String] = property(for: source, key: kTISPropertyInputSourceLanguages),
           array.contains(where: { $0.hasPrefix("zh") || $0.hasPrefix("ja") || $0.hasPrefix("ko") }) {
            return true
        }

        if let sourceID: String = property(for: source, key: kTISPropertyInputSourceID),
           (sourceID.contains("inputmethod") || sourceID.contains("SCIM")) {
            return true
        }

        return false
    }

    func switchToASCIISource() -> Source? {
        guard let listRef = TISCreateASCIICapableInputSourceList()?.takeRetainedValue() as? [TISInputSource],
              !listRef.isEmpty else {
            return nil
        }

        let preferred = listRef.first { source in
            let sourceID: String = property(for: source, key: kTISPropertyInputSourceID) ?? ""
            return sourceID.contains(".ABC") || sourceID.contains(".US")
        }

        let target = preferred ?? listRef[0]
        TISSelectInputSource(target)
        return target
    }

    func select(_ source: Source?) {
        guard let source else { return }
        TISSelectInputSource(source)
    }

    private func property<T>(for source: Source, key: CFString) -> T? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? T
    }
}
