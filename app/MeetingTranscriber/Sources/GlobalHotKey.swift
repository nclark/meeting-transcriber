import AppKit
import Carbon.HIToolbox
import os

private let logger = Logger(subsystem: AppPaths.logSubsystem, category: "GlobalHotKey")

/// A system-wide keyboard shortcut registered via Carbon's
/// `RegisterEventHotKey`.
///
/// Chosen over the alternatives because it is the only macOS API that fires
/// while another app has focus *without* an Accessibility / Input Monitoring
/// TCC grant, and it consumes the keystroke instead of leaking it to the
/// focused app (`NSEvent.addGlobalMonitorForEvents` does neither). It also
/// works inside the App Store sandbox, so no `#if APPSTORE` split is needed.
///
/// The handler is installed on the event dispatcher target, so Carbon
/// delivers hot-key events on the main thread.
@MainActor
final class GlobalHotKey {
    // nonisolated(unsafe): `deinit` (nonisolated) must be able to release the
    // Carbon handles so a dropped reference never leaves Carbon holding a
    // dangling userData pointer. All accesses in practice run on the main
    // thread — init/unregister are MainActor, deinit runs after the last
    // (MainActor-held) reference is gone.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    private let onPress: @MainActor () -> Void

    /// Fails (returns nil) when Carbon rejects the registration — e.g. the
    /// combination is unavailable on this system.
    init?(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress: @escaping @MainActor () -> Void,
    ) {
        self.onPress = onPress

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed),
        )
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                logger.info("hot key pressed")
                // Carbon dispatches hot-key events on the main thread (the
                // handler target is the main event dispatcher).
                MainActor.assumeIsolated { hotKey.onPress() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef,
        )
        guard installStatus == noErr else {
            logger.error("InstallEventHandler failed: \(installStatus)")
            return nil
        }

        // Signature is the four-char code "MTHK"; the id disambiguates
        // multiple hot keys if the app ever registers more than one.
        let hotKeyID = EventHotKeyID(signature: 0x4D54_484B, id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef,
        )
        guard registerStatus == noErr else {
            logger.error("RegisterEventHotKey failed: \(registerStatus)")
            release()
            return nil
        }
        logger.info("registered hot key (keyCode \(keyCode), modifiers \(modifiers))")
    }

    /// Unregisters the shortcut. Idempotent; also runs from `deinit`.
    func unregister() {
        release()
    }

    nonisolated private func release() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }

    deinit {
        release()
    }
}
