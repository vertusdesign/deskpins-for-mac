import AppKit
import Carbon.HIToolbox

/// A keyboard shortcut, stored as a virtual key code plus Carbon modifier mask.
///
/// The key code is stored rather than the character, so a shortcut recorded on one
/// keyboard layout keeps working — and keeps displaying correctly — on another.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let fallback = Shortcut(keyCode: UInt32(kVK_ANSI_P),
                                   carbonModifiers: UInt32(controlKey | optionKey | cmdKey))

    /// Builds a shortcut from a recorded key event. Returns nil when the combination is
    /// not usable as a global shortcut — macOS requires at least one modifier.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }

        guard carbon != 0 else { return nil }
        keyCode = UInt32(event.keyCode)
        carbonModifiers = carbon
    }

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0     { flags.insert(.command) }
        if carbonModifiers & UInt32(optionKey) != 0  { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbonModifiers & UInt32(shiftKey) != 0   { flags.insert(.shift) }
        return flags
    }

    /// e.g. "⌃⌥⌘P" — modifiers in the order macOS itself displays them.
    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0  { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0   { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0     { result += "⌘" }
        return result + Shortcut.keyName(for: keyCode)
    }

    /// The character this key produces, for use as an `NSMenuItem` key equivalent.
    var menuKeyEquivalent: String {
        Shortcut.character(for: keyCode)?.lowercased() ?? ""
    }

    // MARK: - Key naming

    private static let namedKeys: [Int: String] = [
        kVK_Return: "↩", kVK_ANSI_KeypadEnter: "⌤", kVK_Tab: "⇥", kVK_Space: "␣",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static func keyName(for keyCode: UInt32) -> String {
        if let named = namedKeys[Int(keyCode)] { return named }
        if let character = character(for: keyCode), !character.isEmpty {
            return character.uppercased()
        }
        return "#\(keyCode)"
    }

    /// Asks the current keyboard layout what this key produces with no modifiers held.
    private static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
                .takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(layout,
                                  UInt16(keyCode),
                                  UInt16(kUCKeyActionDisplay),
                                  0,                       // no modifiers
                                  UInt32(LMGetKbdType()),
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState,
                                  characters.count,
                                  &length,
                                  &characters)
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}

/// Persisted preferences. A nil shortcut means the global shortcut is switched off.
enum Settings {
    private static let keyCodeKey = "shortcut.keyCode"
    private static let modifiersKey = "shortcut.modifiers"
    private static let enabledKey = "shortcut.enabled"

    static var shortcut: Shortcut? {
        get {
            let defaults = UserDefaults.standard
            // First launch: no stored value at all, so start from the default shortcut.
            guard defaults.object(forKey: keyCodeKey) != nil else { return .fallback }
            guard defaults.bool(forKey: enabledKey) else { return nil }
            return Shortcut(keyCode: UInt32(defaults.integer(forKey: keyCodeKey)),
                            carbonModifiers: UInt32(defaults.integer(forKey: modifiersKey)))
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue != nil, forKey: enabledKey)
            if let newValue {
                defaults.set(Int(newValue.keyCode), forKey: keyCodeKey)
                defaults.set(Int(newValue.carbonModifiers), forKey: modifiersKey)
            } else {
                // Remember the keys so switching the shortcut back on restores them.
                defaults.set(defaults.object(forKey: keyCodeKey) ?? Int(Shortcut.fallback.keyCode),
                             forKey: keyCodeKey)
            }
        }
    }
}
