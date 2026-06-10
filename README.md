# KeyHolder 🔑

KeyHolder is a native, ultra-lightweight, and highly secure status bar (menu bar / system tray) utility built in pure SwiftUI for macOS and C#/WPF for Windows. It sits silently beside your clock, allowing you to instantly search, copy, and manage API keys, access tokens, and credentials for all your development platforms.

---

## Supported Platforms

KeyHolder is implemented as a native application for both **macOS** and **Windows** to ensure zero-overhead, premium OS integration, and maximum security:

| Feature | macOS Version | Windows Version |
| :--- | :--- | :--- |
| **UI Framework** | Pure SwiftUI | WPF (Windows Presentation Foundation) |
| **Accessory Type** | Menu Bar Accessory (`LSUIElement = 1`) | System Tray Utility (`NotifyIcon` + Background App) |
| **Secure Storage** | Keychain Services (`Security` API) | Credential Locker (`PasswordVault` API) |
| **Biometrics** | Touch ID / Apple Watch (`LocalAuthentication`) | Windows Hello (Fingerprint / Face / PIN) |
| **Footprint** | ~680 KB | Lightweight C# Assembly |

---

## Key Features

- **Menu Bar / System Tray Accessory**: Lives entirely in your menu bar (macOS) or Notification Area (Windows). Clicking the key icon slides open a clean, native popup window directly underneath. No Dock or Taskbar clutter.
- **Hardware-Backed Security**: Secret keys are stored securely using the OS's native secure vaults. They are encrypted at rest by the operating system and tied to your user account.
- **Biometric Protection**: Access to copying or revealing credentials requires authentication using **Touch ID / Apple Watch** (macOS) or **Windows Hello** (Windows).
- **Smart Session Lock**: Once authenticated, the app remains unlocked for a smooth experience until the popup window is closed/dismissed, at which point it automatically auto-locks itself.
- **Platform Icon Auto-Mapping**: Automatically detects platform names (e.g., GitHub, AWS, OpenAI, Stripe, Google, Databases) and assigns them unique, color-coded SF Symbols (macOS) or Segoe Fluent Icons (Windows).
- **Quick Filtering & Search**: Instant real-time search and horizontal tag pills let you filter keys by custom category tags (e.g. `dev`, `prod`, `api`).

---

## Security Model

To protect your credentials, KeyHolder enforces strict **separation of concerns** in its storage model:

1. **Metadata Store (`keys.json`)**:
   - macOS Location: `~/Library/Application Support/com.olixstudios.KeyHolder/keys.json`
   - Windows Location: `%APPDATA%/KeyHolder/keys.json`
   - Content: Platform names, account/reference labels, tags, and a unique `id` (UUID).
   - *Security Check*: **No secret keys or password values are ever written to disk.**
   
2. **Keychain / Credential Store**:
   - Secrets are saved into your macOS System Keychain or Windows Credential Locker.
   - This ensures that even if someone reads your local metadata file, they see no sensitive data. The secret key is only queried from the secure OS vault at the exact millisecond you choose to copy or reveal it, and only after successful biometric authentication.

---

## Installation & Running

Ensure you have the required prerequisites for your development environment:

### macOS
#### Prerequisite
Ensure you have Xcode Command Line Tools installed (run `xcode-select --install`).

#### Build & Run
Run the build script located at the root of the project:
```bash
./build.sh
```

---

### Windows
#### Build, Run, & Publish Standalone EXE

You can run the app in development mode using the SDK, or generate a **self-contained, standalone `.exe`** with zero external dependencies (meaning users do not need .NET installed to run it).

##### Option A: Run in Development (Requires SDK)
```cmd
cd windows/KeyHolder
dotnet run
```

##### Option B: Build a Standalone `.exe` (Self-Contained)
To bundle the .NET runtime and WPF libraries directly into a single file:
```cmd
cd windows/KeyHolder
dotnet publish -c Release
```
This compiles a single executable file at:
`windows/KeyHolder/bin/Release/net8.0-windows10.0.19041.0/win-x64/publish/KeyHolder.exe`

You can copy and run this `KeyHolder.exe` file on any Windows 10/11 PC without installing any prerequisites.

---

## Project Structure

```text
keyholder/
├── Package.swift            # macOS Swift Package Manager configuration
├── build.sh                 # macOS Compilation and App Bundle packaging script
├── README.md                # Documentation
├── Sources/                 # macOS SwiftUI Source Code
│   └── keyholder/
│       ├── KeyHolderApp.swift   # Main SwiftUI App entry point (accessory activation policy)
│       ├── Models/
│       │   ├── KeyItem.swift        # Metadata schema and icon mapping logic
│       │   ├── KeychainHelper.swift # Wrapper around macOS SecItem Keychain APIs
│       │   ├── SecurityManager.swift# LocalAuthentication (Touch ID) coordinator
│       │   └── StorageManager.swift # File loader/saver for keys.json
│       └── Views/
│           ├── MainView.swift       # Primary UI (search, filter pills, inline transitions)
│           ├── KeyRowView.swift     # Individual rows with hover triggers and copy animations
│           ├── AddKeyView.swift     # Inline form inputs with secure layout overrides
├── Tests/                   # macOS Unit Tests
└── windows/                 # Windows C# / WPF Source Code
    ├── KeyHolder.sln           # Visual Studio Solution
    └── KeyHolder/
        ├── KeyHolder.csproj    # WPF project targeting .NET 8.0 & WinRT (Windows SDK 19041)
        ├── App.xaml            # Application entry point
        ├── App.xaml.cs         # System tray NotifyIcon manager & popup window positioning
        ├── Models/
        │   ├── KeyItem.cs       # Metadata model with platform Segoe glyph & brush mappings
        │   ├── CredentialHelper.cs # Interface wrapping Windows Hello Credential Locker
        │   ├── SecurityManager.cs  # Biometrics Authenticator wrapping Windows Hello WinRT APIs
        │   └── StorageManager.cs   # JSON loader/saver matching macOS keys.json structure
        └── Views/
            ├── MainWindow.xaml  # Premium dark mode WPF popover layout
            └── MainWindow.xaml.cs # Code-behind for search, filtering, copying & form input
```
