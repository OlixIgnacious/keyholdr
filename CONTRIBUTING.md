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

Needs Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/OlixIgnacious/keyholdr.git
cd keyholdr
./build.sh   # release build → app bundle → launches in your menu bar
```

For iterating on the CLI without rebuilding the whole app bundle:

```bash
swift build
swift run keyholdr-cli -- list
```

## Tests

```bash
swift test
```

Add or update tests in [Tests/keyholdrTests](Tests/keyholdrTests) for any
behavioral change to `KeyholdrKit`.

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
