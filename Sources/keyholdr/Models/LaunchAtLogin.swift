import Foundation
import ServiceManagement

/// Registers Keyholdr as a login item so it survives reboots.
public enum LaunchAtLogin {
    private static let configuredDefaultKey = "didConfigureLaunchAtLogin"

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

    /// A tray utility should be there after a reboot out of the box: enable on
    /// the first launch, then never override the user's choice again — whether
    /// they flip the footer toggle or remove the login item in System Settings.
    public static func enableOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: configuredDefaultKey) else { return }
        // SMAppService needs a real app bundle; skip when running the bare
        // executable (e.g. `swift run`) and retry on the next bundled launch.
        guard Bundle.main.bundleIdentifier != nil else { return }
        if setEnabled(true) {
            defaults.set(true, forKey: configuredDefaultKey)
        }
    }
}
