import Foundation
import ServiceManagement

/// Registers Keyholdr as a login item so it survives reboots — only when the
/// user opts in via the footer AUTOSTART toggle. Off by default: apps may not
/// enable login items without explicit user consent.
public enum LaunchAtLogin {
    private static let clearedInvoluntaryRegistrationKey = "didClearInvoluntaryAutostart"

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("Launch at login \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }

    /// Versions before 1.6.0 (9) silently registered the app as a login item
    /// on first launch, without consent. SMAppService registrations are keyed
    /// to the bundle identifier, not the build, so upgrading alone doesn't
    /// clear one made by an old build. Unregister it once so upgraders land
    /// on the same opt-in-only default as a fresh install — after this runs,
    /// only the user's own footer toggle touches the registration.
    public static func clearInvoluntaryRegistrationIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: clearedInvoluntaryRegistrationKey) else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }
        if isEnabled {
            setEnabled(false)
        }
        defaults.set(true, forKey: clearedInvoluntaryRegistrationKey)
    }
}
