# Contributing to Keyholdr

Thanks for taking the time to contribute. Bug reports, platform/icon
mappings, and CLI ergonomics improvements are especially useful.

## Before you start

By opening a pull request, you agree your contribution is provided under the
same [non-commercial license](LICENSE) as the rest of the project.

For anything beyond a small fix, open an issue first to discuss the change —
this avoids wasted work on approaches that don't fit the project's direction.

## Reporting bugs

Open an [issue](https://github.com/OlixIgnacious/keyholdr/issues) with:

- macOS version and Mac model (Apple Silicon / Intel)
- Keyholdr version (`keyholdr --version`, or **About** in the app)
- Steps to reproduce, and what you expected vs. what happened
- Relevant log output, if any

## Development setup

Needs full Xcode, selected with `xcode-select -s /Applications/Xcode.app` and
its licence accepted (`xcodebuild -license`). The Command Line Tools alone can't
build the app on the current macOS SDK — SwiftUI's `@State` is a macro whose
plugin ships with Xcode.

```bash
git clone https://github.com/OlixIgnacious/keyholdr.git
cd keyholdr
./build.sh              # release build → signed app bundle → relaunches it in your menu bar
./build.sh --no-launch  # same, but leaves running processes alone
```

For iterating on the CLI without rebuilding the whole app bundle:

```bash
swift build
swift run keyholdr-cli list
```

An unsandboxed `swift run` CLI reads `~/Library/Application Support/...`, not
the app's container, so it sees a different vault than the installed app. To
exercise your real vault, use the signed CLI inside the bundle:
`build/Keyholdr.app/Contents/MacOS/keyholdr-cli`.

To compile the Mac App Store variant, run `swift build -Xswiftc -DMAS_BUILD`.

## Tests

```bash
swift test
```

Add or update tests in [Tests/keyholdrTests](Tests/keyholdrTests) for any
behavioral change to `KeyholdrKit` or `KeyholdrTUI`.

`swift test --filter KeyParserTests` runs a single suite (or test name).

`swift test` needs the `Testing` module that ships with Xcode. If it's missing
(`no such module 'Testing'`), run the same tests without it:

```bash
python3 scripts/run-tests-harness.py     # compiles the tests into a plain executable
```

To check the full-screen terminal UI, drive it through a pty:

```bash
python3 scripts/tui-smoke-test.py [path-to-cli]
```

Neither touches your real vault: the smoke test points `HOME` at a throwaway
temp directory. Keep it that way — a test must never save or delete a key or
trigger Touch ID, since both reach the real Keychain. And don't test UI by
sending keystrokes or clicks to the desktop (e.g. `osascript`); use the smoke
test.

## Project layout

See [Project layout](README.md#project-layout) in the README for an overview
of where things live. The Windows app is in its own repo:
[keyholdr-windows](https://github.com/OlixIgnacious/keyholdr-windows).

## Pull requests

- Keep PRs focused — one logical change per PR.
- Match the existing code style and conventions of the surrounding code.
- Update `docs/CLI.md` and the README if you change CLI flags or behavior.
- Describe what changed and why in the PR description.

## Adding platform/icon mappings

Platform detection (icons, env var naming conventions) lives in
`KeyholdrKit`. If you're adding support for a new platform, keep the mapping
table sorted and add a short comment only if the matching logic is
non-obvious (e.g. why a platform matches multiple substrings).
