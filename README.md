# KeyHolder 🔑

KeyHolder is a native, ultra-lightweight, and highly secure macOS status bar (menu bar) utility built in pure SwiftUI. It sits silently beside your clock, allowing you to instantly search, copy, and manage API keys, access tokens, and credentials for all your development platforms.

---

## Key Features

- **Menu Bar Accessory**: Lives entirely in your menu bar (`LSUIElement = 1`). Clicking the key icon slides open a clean, native popup window directly underneath. No Dock clutter.
- **Hardware-Backed Security**: Secret keys are stored securely using the **macOS Keychain Services API** (`Security` framework). They are encrypted at rest by the OS and tied to your user account.
- **Biometric Protection (Touch ID)**: Access to copying, revealing, or editing credentials requires authentication using **Touch ID / Apple Watch** or your Mac password.
- **Smart Session Lock**: Once authenticated, the app remains unlocked for a smooth experience until the popup window is closed/dismissed, at which point it automatically auto-locks itself.
- **Platform Icon Auto-Mapping**: Automatically detects platform names (e.g., GitHub, AWS, OpenAI, Stripe, Google, Databases) and assigns them unique, color-coded SF Symbols in the list.
- **Quick Filtering & Search**: Instant real-time search and horizontal tag pills let you filter keys by custom category tags (e.g. `dev`, `prod`, `api`).
- **Secure Input Fields**: Input boxes utilize custom text boundaries and one-time code attributes to bypass macOS auto-fill popups, ensuring the popup window never loses focus or closes unexpectedly.
- **Developer-Friendly Footprint**: Compiled natively using Swift Package Manager. The entire application bundle is only **~680 KB** and runs with a highly optimized memory footprint.

---

## Security Model

To protect your credentials, KeyHolder enforces strict **separation of concerns** in its storage model:

1. **Metadata Store (`keys.json`)**:
   - Location: `~/Library/Application Support/com.olixstudios.KeyHolder/keys.json`
   - Content: Platform names, account/reference labels, tags, and a unique `id` (UUID).
   - *Security Check*: **No secret keys or password values are ever written to disk.**
   
2. **Keychain Store**:
   - Secrets are saved into your macOS System Keychain.
   - **Service Name**: `com.olixstudios.KeyHolder`
   - **Account Name**: The metadata item's unique `id` (UUID).
   - This ensures that even if someone reads your local metadata file, they see no sensitive data. The secret key is only queried from the Keychain at the exact millisecond you choose to copy or reveal it, and only after successful biometric authentication.

---

## Installation & Running

KeyHolder is set up as a standard Swift Package Manager project, making it extremely easy to build from the command line.

### Prerequisite
Ensure you have Xcode Command Line Tools installed (run `xcode-select --install`).

### Build & Run
Run the build script located at the root of the project:
```bash
./build.sh
```

This automated script will:
1. Compile the Swift project in release mode.
2. Build the standard macOS App Bundle directory structure (`build/KeyHolder.app`).
3. Write the required accessory configurations to `Info.plist`.
4. Gracefully terminate any running instances of the app.
5. Launch the newly compiled app directly into your system menu bar.

---

## Project Structure

```text
keyholder/
├── Package.swift            # Swift Package Manager configuration
├── build.sh                 # Compilation and App Bundle packaging script
├── README.md                # Documentation
└── Sources/
    └── keyholder/
        ├── KeyHolderApp.swift   # Main SwiftUI App entry point (accessory activation policy)
        ├── Models/
        │   ├── KeyItem.swift        # Metadata schema and icon mapping logic
        │   ├── KeychainHelper.swift # Wrapper around macOS SecItem Keychain APIs
        │   ├── SecurityManager.swift# LocalAuthentication (Touch ID) coordinator
        │   └── StorageManager.swift # File loader/saver for keys.json
        └── Views/
            ├── MainView.swift       # Primary UI (search, filter pills, inline transitions)
            ├── KeyRowView.swift     # Individual rows with hover triggers and copy animations
            ├── AddKeyView.swift     # Inline form inputs with secure layout overrides
```
