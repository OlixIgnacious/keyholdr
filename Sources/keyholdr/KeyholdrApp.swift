import SwiftUI
import Combine
import KeyholdrKit
import MenuBarExtraAccess

@main
struct KeyholdrApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Hides the Dock icon programmatically, rendering the app only in the menu bar
        NSApplication.shared.setActivationPolicy(.accessory)
        LaunchAtLogin.enableOnFirstLaunch()
    }

    var body: some Scene {
        MenuBarExtra("Keyholdr", systemImage: "key.fill") {
            MainView(securityManager: appState.securityManager)
        }
        // Must come before any other scene modifier — it extends MenuBarExtra itself.
        .menuBarExtraAccess(isPresented: $appState.isMenuPresented)
        .menuBarExtraStyle(.window)
    }
}

/// Owns the popover presentation state so the global hotkey can drive it.
@MainActor
final class AppState: ObservableObject {
    @Published var isMenuPresented = false {
        didSet {
            // Auto-lock when the popover is dismissed by the user — but not
            // when it's the Touch ID / password prompt that closed it
            // (isAuthenticating is still true in that case), since the
            // session should remain unlocked once that prompt succeeds.
            if oldValue, !isMenuPresented, !securityManager.isAuthenticating {
                securityManager.lock()
            }
        }
    }

    /// Shared across the popover's lifetime (unlike `MainView`, which is torn
    /// down whenever the popover window closes), so an unlocked session
    /// survives the popover being re-presented.
    let securityManager = SecurityManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        HotKeyManager.shared.onHotKey = { [weak self] in
            guard let self else { return }
            self.isMenuPresented.toggle()
            if self.isMenuPresented {
                // Pull focus so the search field is ready to type into.
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        HotKeyManager.shared.register()

        // The system Touch ID / password prompt steals focus, which causes
        // MenuBarExtra's popover to auto-close as a side effect. Re-present
        // it once the prompt is dismissed so the user sees the result.
        securityManager.$isAuthenticating
            .removeDuplicates()
            .sink { [weak self] isAuthenticating in
                guard let self, !isAuthenticating, !self.isMenuPresented else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.isMenuPresented = true
            }
            .store(in: &cancellables)
    }
}
