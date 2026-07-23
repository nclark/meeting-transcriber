import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click-to-record shortcut field. Clicking arms a local key monitor; the
/// next valid combo (must include ⌘ ⌃ or ⌥) replaces `combo`, Esc cancels.
///
/// `onArmedChange` fires on arm/disarm so the owner can suspend the live
/// Carbon registration while recording — a registered hot key is consumed
/// at the window-server level before the app's local monitor ever sees it,
/// so without the suspension the *current* combo could not be re-captured.
struct ShortcutRecorderView: View {
    @Binding var combo: HotKeyCombo
    var onArmedChange: (Bool) -> Void = { _ in }

    @State private var isArmed = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isArmed ? disarm() : arm()
        } label: {
            Text(isArmed ? "Press shortcut…" : combo.displayString)
                .font(.body.monospaced())
                .frame(minWidth: 110)
        }
        .foregroundStyle(isArmed ? .secondary : .primary)
        .onDisappear {
            disarm()
        }
    }

    private func arm() {
        isArmed = true
        onArmedChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape),
               event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]) {
                disarm()
                return nil
            }
            let captured = HotKeyCombo(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: HotKeyCombo.carbonModifiers(from: event.modifierFlags),
            )
            guard captured.isValid else {
                // Swallow but stay armed — the caption explains the ⌘⌃⌥ rule.
                return nil
            }
            combo = captured
            disarm()
            return nil
        }
    }

    private func disarm() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if isArmed {
            isArmed = false
            onArmedChange(false)
        }
    }
}
