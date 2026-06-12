import SwiftUI
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
            MainView()
        }
        // Must come before any other scene modifier — it extends MenuBarExtra itself.
        .menuBarExtraAccess(isPresented: $appState.isMenuPresented)
        .menuBarExtraStyle(.window)
    }
}

/// Owns the popover presentation state so the global hotkey can drive it.
@MainActor
final class AppState: ObservableObject {
    @Published var isMenuPresented = false

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
    }
}
