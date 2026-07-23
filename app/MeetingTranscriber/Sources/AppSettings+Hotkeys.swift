import Foundation

/// Derived hotkey API split out of `AppSettings` to keep the class body
/// under the file-length cap (line-cap split). Stored properties
/// (`recordAppHotkeyEnabled` / `...KeyCode` / `...Modifiers` /
/// `hotkeyCaptureActive`) stay in AppSettings.swift.
extension AppSettings {
    /// The Record-App shortcut as a value type (the two persisted Ints are
    /// the storage; this is the API the recorder UI and scene wiring use).
    var recordAppHotkeyCombo: HotKeyCombo {
        get {
            HotKeyCombo(
                keyCode: UInt32(recordAppHotkeyKeyCode),
                carbonModifiers: UInt32(recordAppHotkeyModifiers),
            )
        }
        set {
            recordAppHotkeyKeyCode = Int(newValue.keyCode)
            recordAppHotkeyModifiers = Int(newValue.carbonModifiers)
        }
    }

    /// Everything the scene needs to (re)register the Record-App hot key,
    /// as one Equatable value so a single `onChange` covers enable/disable,
    /// rebinding, and capture suspension.
    struct RecordAppHotkeyState: Equatable {
        var enabled: Bool
        var combo: HotKeyCombo
        var captureSuspended: Bool
    }

    var recordAppHotkeyState: RecordAppHotkeyState {
        RecordAppHotkeyState(
            enabled: recordAppHotkeyEnabled,
            combo: recordAppHotkeyCombo,
            captureSuspended: hotkeyCaptureActive,
        )
    }

    // Init-time read of all persisted hotkey settings in one go. A tuple
    // (not a bag struct) so `AppSettings.init` can destructure it in a
    // single statement — the init body sits at the function-body-length
    // cap and has no line to spare for an intermediate `let`.
    // swiftlint:disable:next large_tuple
    static func loadHotkeys(from defaults: UserDefaults) -> (Bool, Int, Int, String, String) {
        (
            defaults.object(forKey: "recordAppHotkeyEnabled") as? Bool ?? false,
            defaults.object(forKey: "recordAppHotkeyKeyCode") as? Int
                ?? Int(HotKeyCombo.recordAppDefault.keyCode),
            defaults.object(forKey: "recordAppHotkeyModifiers") as? Int
                ?? Int(HotKeyCombo.recordAppDefault.carbonModifiers),
            defaults.string(forKey: "quickRecordBundleID") ?? "",
            defaults.string(forKey: "quickRecordAppName") ?? "",
        )
    }
}
