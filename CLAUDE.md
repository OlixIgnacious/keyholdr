# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Keyholdr is a macOS menu bar vault for API keys (SwiftUI app) plus a terminal companion (`keyholdr` CLI) that share one vault. SwiftPM, Swift 6 language mode, macOS 13+. The Windows app and the marketing site live in separate repos (`keyholdr-windows`, and `../keyholdr-site`, a static GitHub Pages site that deploys on every push to its `main`).

## Commands

```bash
swift build                              # debug build of everything
swift run keyholdr-cli list              # iterate on the CLI without a bundle
./build.sh                               # release build → signed .app in build/ → kills the running Keyholdr and relaunches it
./build.sh --no-launch                   # same, but leaves running processes alone (what CI uses)
swift build -Xswiftc -DMAS_BUILD         # compile the Mac App Store variant
./build-mas.sh                           # signed App Store .pkg in build/ (needs the Apple Distribution + Installer certs and the "Keyholdr MAS" profile)

swift test                               # Swift Testing (needs Xcode's Testing module)
swift test --filter KeyParserTests       # one suite (also works for a single test name)
python3 scripts/run-tests-harness.py     # same tests without Xcode: rewrites @Test/#expect into a plain executable
python3 scripts/tui-smoke-test.py [cli]  # drives the full-screen UI through a pty against a throwaway vault
```

There is no linter. `swift test` and the smoke test never touch your real vault: the smoke test points `HOME`/`CFFIXED_USER_HOME` at a temp dir, and it must never save/delete a key or trigger Touch ID (both reach the real Keychain).

Toolchain: needs full Xcode selected (`xcode-select -p` → `/Applications/Xcode.app/...`) with its licence accepted. With Command Line Tools only, the macOS 27 SDK fails (SwiftUI `@State` is a macro whose plugin lives in Xcode; SwiftPM's default engine dies with "Unknown error parsing property list").

## Architecture

**Four targets** (`Package.swift`): `KeyholdrKit` (model, Keychain, storage, vault export — used by both binaries), `KeyholdrTUI` (dependency-free terminal primitives: raw mode, key parsing, text width/editing), `keyholdr` (the app), `keyholdr-cli` (ArgumentParser CLI). Tests import Kit and TUI only.

**Metadata and secrets are stored apart.** Names/labels/tags live in `keys.json` (`StorageManager`, mirrored into a Keychain item so the app can self-heal); each secret is its own Keychain item (service `com.olixstudios.Keyholdr`, account = key UUID) via `KeychainHelper`. Every secret read is gated by `LocalAuthentication`, and the authenticated `LAContext` is passed into `KeychainHelper.retrieve/lookup`. Notes are the deliberate exception: plain `notes.json`, no Keychain, not in vault export. The app and CLI both write `notes.json`, so use `NoteStorage.upsert/remove` (they re-read before writing) rather than saving a whole stale array.

**The hard part is sandboxing and signing — three signed variants share one bundle id:**
- *Direct/Homebrew (Developer ID):* app signed with `Keyholdr.entitlements`; the CLI with `Keyholdr-CLI.entitlements`, which adds an sbpl `file-ioctl` rule for `/dev/tty` — without it the sandbox refuses `tcsetattr`, so the UI draws but never receives a key (and the inline picker too). The CLI also embeds `EmbeddedInfo.xml` (linker `-sectcreate __TEXT __info_plist`, set in `Package.swift`); without a bundle identity macOS 27 kills the sandboxed CLI with SIGTRAP on launch. `build.sh` and `.github/workflows/release-macos.yml` each sign — keep them in sync.
- *Mac App Store (`-DMAS_BUILD`):* `Keyholdr-MAS.entitlements`, CLI `Keyholdr-CLI-MAS.entitlements` (sandbox + `inherit`). No temporary exceptions are allowed, and that CLI does not run reliably from Terminal, so the MAS-only `TerminalSetupView` (behind `#if MAS_BUILD`) points users at the Homebrew build. `CLIInstaller` is the `#if !MAS_BUILD` counterpart.
- Secrets saved by the App Store build live in a protected Keychain area the direct-download CLI cannot read (and vice versa). `KeychainHelper.lookup` returns the `OSStatus`, `explain` turns it into a message, and the dashboard copies what it can and names the rest.
- An unsandboxed dev CLI (`.build/.../keyholdr-cli`) reads `~/Library/Application Support/...`, not the app's container, and can stall ~10 s on a Keychain approval dialog. To exercise the real vault use the signed one in `build/Keyholdr.app/Contents/MacOS/`.

**The app** is a SwiftUI `MenuBarExtra(.window)` popover (360×480). `MainView` is torn down every time the popover closes, so anything that must survive lives in `AppState`/`SecurityManager` (`KeyholdrApp.swift`), and `NotesStore` flushes its debounced autosave on disappear. The popover doesn't route key equivalents, so shortcuts go through an `NSEvent` local monitor in `MainView`; `.alert` is unreliable there, so confirmations are in-view overlays. A `stroke` overlay on a control swallows its clicks (shape hit-testing covers the interior) — add `.allowsHitTesting(false)`. `khGlass` (`Theme.swift`) is Liquid Glass on macOS 26 with the flat look as the fallback for the macOS 13 target.

**The CLI:** bare `keyholdr` is the default subcommand `Pick`, which opens the full-screen `Dashboard` when `Terminal.isSupported` (tty on stdin+stderr, real `TERM`, `Terminal.canChangeMode`) and the window is ≥60×16; otherwise it falls back to the inline `Picker` (also `--classic` / `KEYHOLDR_CLASSIC=1`). `Dashboard.swift` holds state and actions; `Dashboard+View.swift` builds every frame as strings exactly one terminal width wide (plain text is fitted before styling; `Text.width` ignores ANSI) and writes it in one call. UI output goes to **stderr** so stdout stays clean for `eval "$(keyholdr env)"`. Write rules and the biometric gate are shared with the one-liners in `VaultActions.swift` (`addKey`, `deleteKeys`, non-printing `authenticate` vs `authenticateOrExit`). The existing one-liners (`get`, `run`, `env`, `list`, `add`, `rm`) must keep byte-identical output and exit codes.

## Releasing

The version lives in four places: `build.sh`, `build-mas.sh` (`VERSION`/`BUILD` — the App Store needs a higher `BUILD` for every upload), `Sources/keyholdr-cli/EmbeddedInfo.xml`, and `version:` in `KeyholdrCLI.swift`; then cut `CHANGELOG.md`. `gh release create vX.Y.Z --notes-file …` pushes the tag, which runs CI: build, Developer ID sign, notarize, attach the zip, bump the Homebrew tap. The App Store `.pkg` is uploaded by hand via Transporter. Batch features on `main`; don't tag or release unless asked.

## Conventions

- Update `docs/CLI.md` and `README.md` when CLI flags or behavior change; the site repo mirrors them, so update it before or with a release that changes user-facing behavior.
- Commit messages carry no Claude/Anthropic attribution and no `Co-Authored-By: Claude` trailer.
- Don't test UI by sending keystrokes or clicks to the desktop (e.g. `osascript`, especially Esc) — inside VS Code they land in the Claude panel. Use the pty smoke test.
