import AppKit
import Carbon.HIToolbox
@testable import MeetingTranscriber
import XCTest

@MainActor
final class HotKeyComboTests: XCTestCase {
    // MARK: - Validation

    func testDefaultComboIsValid() {
        XCTAssertTrue(HotKeyCombo.recordAppDefault.isValid)
    }

    func testUnmodifiedKeyIsInvalid() {
        let combo = HotKeyCombo(keyCode: UInt32(kVK_ANSI_R), carbonModifiers: 0)
        XCTAssertFalse(combo.isValid, "a bare letter would shadow ordinary typing")
    }

    func testShiftOnlyIsInvalid() {
        let combo = HotKeyCombo(keyCode: UInt32(kVK_ANSI_R), carbonModifiers: UInt32(shiftKey))
        XCTAssertFalse(combo.isValid, "shift-only combos would shadow capitalised typing")
    }

    func testEachPrimaryModifierAloneIsValid() {
        for modifier in [cmdKey, optionKey, controlKey] {
            let combo = HotKeyCombo(keyCode: UInt32(kVK_ANSI_R), carbonModifiers: UInt32(modifier))
            XCTAssertTrue(combo.isValid, "modifier mask \(modifier) must qualify as a global shortcut")
        }
    }

    // MARK: - Cocoa → Carbon conversion

    func testCarbonModifiersFromCocoaFlags() {
        XCTAssertEqual(HotKeyCombo.carbonModifiers(from: [.command]), UInt32(cmdKey))
        XCTAssertEqual(HotKeyCombo.carbonModifiers(from: [.option]), UInt32(optionKey))
        XCTAssertEqual(HotKeyCombo.carbonModifiers(from: [.control]), UInt32(controlKey))
        XCTAssertEqual(HotKeyCombo.carbonModifiers(from: [.shift]), UInt32(shiftKey))
        XCTAssertEqual(
            HotKeyCombo.carbonModifiers(from: [.command, .option, .control]),
            UInt32(cmdKey | optionKey | controlKey),
        )
    }

    func testCarbonModifiersIgnoresNonHotkeyFlags() {
        XCTAssertEqual(
            HotKeyCombo.carbonModifiers(from: [.capsLock, .function, .numericPad]),
            0,
            "flags Carbon hot keys can't match must not leak into the mask",
        )
    }

    // MARK: - Display string

    func testDisplayStringModifierOrderFollowsMacOSConvention() {
        let combo = HotKeyCombo(
            keyCode: UInt32(kVK_ANSI_R),
            carbonModifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey),
        )
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘R")
    }

    func testDisplayStringSpecialKeys() {
        let escape = HotKeyCombo(keyCode: UInt32(kVK_Escape), carbonModifiers: UInt32(cmdKey))
        XCTAssertEqual(escape.displayString, "⌘⎋")
        let f19 = HotKeyCombo(keyCode: UInt32(kVK_F19), carbonModifiers: UInt32(optionKey))
        XCTAssertEqual(f19.displayString, "⌥F19")
        let space = HotKeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(controlKey))
        XCTAssertEqual(space.displayString, "⌃Space")
    }

    // MARK: - Settings round-trip

    func testSettingsComboRoundTrip() {
        let suiteName = "HotKeyComboTests-\(getpid())-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.recordAppHotkeyCombo, .recordAppDefault, "fresh settings must default to ⌃⌥⌘R")

        let custom = HotKeyCombo(keyCode: UInt32(kVK_ANSI_M), carbonModifiers: UInt32(cmdKey | shiftKey))
        settings.recordAppHotkeyCombo = custom

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.recordAppHotkeyCombo, custom, "a rebound shortcut must survive relaunch")
    }
}
