import AppKit
import Carbon.HIToolbox

/// Registers the system-wide summon hotkey (⌃⌥K) through Carbon's
/// RegisterEventHotKey, which works without the Accessibility permission
/// that NSEvent global monitors would require.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in
                HotKeyManager.shared.onHotKey?()
            }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B48_4C44) /* "KHLD" */, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_K),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
