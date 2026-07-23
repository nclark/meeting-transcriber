import AppKit
import Carbon.HIToolbox

/// A key code + Carbon modifier mask describing a global keyboard shortcut.
///
/// Pure value type so the decision logic around shortcuts — validation,
/// NSEvent→Carbon flag conversion, display formatting — is unit-testable
/// without touching the Carbon registration path (`GlobalHotKey`).
struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// Default shortcut for the "Record App" window: ⌃⌥⌘R — mirrors the
    /// menu bar item's local `⌘R` with the full modifier stack that global
    /// shortcuts conventionally carry to avoid shadowing app-local bindings.
    static let recordAppDefault = Self(
        keyCode: UInt32(kVK_ANSI_R),
        carbonModifiers: UInt32(cmdKey | optionKey | controlKey),
    )

    /// A usable global shortcut must include at least one of ⌘ ⌃ ⌥.
    /// Shift-only (or unmodified) combos would shadow ordinary typing.
    var isValid: Bool {
        carbonModifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    /// Carbon modifier mask from Cocoa event flags. Only the four modifier
    /// keys meaningful to `RegisterEventHotKey` are carried over.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    /// Human-readable form, e.g. "⌃⌥⌘R". Modifier order follows the macOS
    /// convention (⌃ ⌥ ⇧ ⌘). Main-actor because the key name lookup reads
    /// the current keyboard layout via TIS.
    @MainActor var displayString: String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        return parts + Self.keyName(for: keyCode)
    }

    /// Display name for a key code: fixed symbols for non-printing keys,
    /// otherwise the character the current keyboard layout produces
    /// (via `UCKeyTranslate`, so a French layout shows "A" where a US
    /// layout shows "Q").
    @MainActor
    static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeyNames[Int(keyCode)] {
            return special
        }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> OSStatus in
            UCKeyTranslate(
                ptr.bindMemory(to: UCKeyboardLayout.self).baseAddress,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars,
            )
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    /// Non-printing keys `UCKeyTranslate` can't render. F-keys plus the
    /// standard macOS glyphs for editing/navigation keys.
    private static let specialKeyNames: [Int: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space",
            kVK_Return: "↩",
            kVK_Tab: "⇥",
            kVK_Escape: "⎋",
            kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_UpArrow: "↑",
            kVK_DownArrow: "↓",
            kVK_Home: "↖",
            kVK_End: "↘",
            kVK_PageUp: "⇞",
            kVK_PageDown: "⇟",
        ]
        let fKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9,
            kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17,
            kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, code) in fKeys.enumerated() {
            names[code] = "F\(index + 1)"
        }
        return names
    }()
}
