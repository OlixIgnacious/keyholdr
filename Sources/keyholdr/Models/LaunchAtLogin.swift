import Foundation
import ServiceManagement

/// Registers Keyholdr as a login item so it survives reboots — only when the
/// user opts in via the footer AUTOSTART toggle. Off by default: apps may not
/// enable login items without explicit user consent.
public enum LaunchAtLogin {
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
}
