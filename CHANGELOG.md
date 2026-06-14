# Changelog

All notable changes to Keyholdr are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- `keyholdr pick` (and the default no-argument picker) is now multi-select —
  ⇥/space marks several keys, ⏎ copies them all, one per line.
- Claude-style terracotta color theme across the CLI (skipped automatically
  when stderr isn't a tty, or `NO_COLOR` is set).
- `CONTRIBUTING.md` with dev setup, test, and PR guidelines.

### Changed
- Marketing site moved to its own repo:
  [keyholdr-site](https://github.com/OlixIgnacious/keyholdr-site).
- README install and build instructions restructured as numbered steps.

## [1.5.0] - 2026-06-13

### Added
- `keyholdr env` — multi-select keys and emit `export`/`.env` lines for
  `eval`, with conventional env var names guessed per platform
  (`GITHUB_TOKEN`, `OPENAI_API_KEY`, etc.).
- `keyholdr run` — with no `-e` mappings, opens the same multi-select picker
  and derives env var names automatically.
- `keyholdr rm` — bare invocation opens a multi-select picker (⇥/space to
  mark, ⏎ deletes several keys at once).
- [docs/CLI.md](docs/CLI.md), a full CLI usage reference.

### Changed
- Switched from MIT to the Keyholdr Non-Commercial License.

## [1.4.0] - 2026-06-12

### Added
- `keyholdr add` — create keys from the terminal. The secret is read from a
  hidden prompt or stdin (`pbpaste | keyholdr add openai`), never from
  arguments.
- `keyholdr rm` — delete a key and its secret, with confirmation and
  `--force` for scripts.

## [1.3.0] - 2026-06-12

### Added
- Interactive CLI — run `keyholdr` with no arguments to filter, move, and
  copy a secret after Touch ID. `keyholdr pick aws` starts pre-filtered.
- Ambiguous `keyholdr get aws` matches open a picker in a terminal; scripts
  get a hard error with `--label` hints instead.
- Duplicate guard — the app refuses to create two keys with the same
  platform and label.

## [1.2.0] - 2026-06-12

### Added
- Terminal companion CLI bundled with the app: `keyholdr list`,
  `keyholdr get <platform>` (with `--copy`), `keyholdr run -e ...`.
- Rotation hints — keys whose secret hasn't changed in 6 months show a
  `11MO · ROTATE?` nudge in the popover and a ⚠ in `keyholdr list`.

## [1.1.0] - 2026-06-12

First release under the Keyholdr name.

### Added
- Global hotkey (⌃⌥⌘K) to summon or dismiss the popover from anywhere.
- Starts at login, with an AUTOSTART toggle in the footer.
- Encrypted vault export/import (PBKDF2-SHA256 + AES-256-GCM).
- Homebrew cask: `brew install --cask olixignacious/tap/keyholdr`.

## [1.0.0] - 2026-06-11

First release of KeyHolder — a native menu bar / system tray vault for API
keys.

### Added
- Secrets stored in macOS Keychain / Windows Credential Locker.
- Touch ID / Windows Hello required to copy or reveal any key.
- macOS: ⌘N to add a key, Escape to dismiss, instant search.

[Unreleased]: https://github.com/OlixIgnacious/keyholdr/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/OlixIgnacious/keyholdr/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/OlixIgnacious/keyholdr/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/OlixIgnacious/keyholdr/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/OlixIgnacious/keyholdr/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/OlixIgnacious/keyholdr/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/OlixIgnacious/keyholdr/releases/tag/v1.0.0
