import SwiftUI

@main
struct KeyHolderApp: App {
    init() {
        // Hides the Dock icon programmatically, rendering the app only in the menu bar
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra("KeyHolder", systemImage: "key.fill") {
            MainView()
        }
        .menuBarExtraStyle(.window)
    }
}
