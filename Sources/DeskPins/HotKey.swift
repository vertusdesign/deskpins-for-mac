import AppKit
import Carbon.HIToolbox

/// Registers the one global shortcut DeskPins uses.
///
/// Carbon's `RegisterEventHotKey` is still the supported way to get a system-wide shortcut
/// without an input-monitoring event tap: it costs nothing while idle, needs no extra
/// privacy permission, and — unlike a tap — cannot observe any other keystroke.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var action: (() -> Void)?

    private var ref: EventHotKeyRef?
    private var handlerInstalled = false
    private var suspended = false
    private var current: Shortcut?

    private init() {}

    /// Installs `shortcut`, replacing whatever was registered. Nil switches it off.
    func apply(_ shortcut: Shortcut?) {
        current = shortcut
        guard !suspended else { return }
        unregister()
        guard let shortcut else { return }
        register(shortcut)
    }

    /// Releases the shortcut while the user is recording a new one, so pressing the old
    /// combination types into the recorder instead of pinning a window.
    func suspend() {
        suspended = true
        unregister()
    }

    func resume() {
        suspended = false
        apply(current)
    }

    // MARK: - Carbon plumbing

    private func register(_ shortcut: Shortcut) {
        installHandlerIfNeeded()
        var created: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4450_696E), id: 1)   // 'DPin'
        let status = RegisterEventHotKey(shortcut.keyCode,
                                         shortcut.carbonModifiers,
                                         id,
                                         GetApplicationEventTarget(),
                                         0,
                                         &created)
        if status == noErr { ref = created }
    }

    private func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            HotKeyCenter.shared.action?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
