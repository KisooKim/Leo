import AppKit
import HotKey

/// Registers a single global hotkey (⌥+Space by default) and invokes
/// `onPress` on the main thread each time it fires.
final class HotKeyManager {
    private var hotKey: HotKey?

    /// Called on the main thread each time the hotkey is pressed.
    var onPress: (() -> Void)?

    func register(key: Key = .space, modifiers: NSEvent.ModifierFlags = [.option]) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onPress?()
        }
    }

    func unregister() {
        hotKey = nil
    }
}
