# keyholdr-cli usage

> Also available as a browsable page, alongside the architecture and install
> docs: [olixignacious.github.io/keyholdr-site/docs.html](https://olixignacious.github.io/keyholdr-site/docs.html)

The terminal companion to the Keyholdr menu bar app. It reads the same vault
— the same key list and the same macOS Keychain entries — so anything you add
in the app shows up in the CLI and vice versa. Every secret access requires
Touch ID (or your account password as a fallback).

Install via Homebrew (`brew install --cask olixignacious/tap/keyholdr`) or the
[direct download](https://github.com/OlixIgnacious/keyholdr/releases/latest);
both link `keyholdr` onto your PATH.

## Commands

| Command | What it does |
|---|---|
| `keyholdr` | Full-screen UI for keys and notes (default subcommand) |
| `keyholdr list` | List every key (never the secrets) |
| `keyholdr get <platform>` | Print or copy a secret |
| `keyholdr run` | Run a command with secrets injected as env vars |
| `keyholdr env` | Emit `export`/`.env` lines for `eval` |
| `keyholdr add <platform>` | Add a new key |
| `keyholdr rm [platform]` | Delete one or more keys |

Run `keyholdr <command> --help` for full flag details.

---

### `keyholdr` / `keyholdr pick [filter]` — the terminal UI

Opens a full-screen UI with **KEYS** and **NOTES** tabs, the same as the menu
bar app. The left pane lists entries; the right pane shows the selected one
(env var name, tags, dates, and the masked secret for a key; the full text for
a note).

```bash
keyholdr            # browse everything
keyholdr aws        # start pre-filtered to "aws"
keyholdr --classic  # the simple inline picker instead (also: KEYHOLDR_CLASSIC=1)
```

```text
╭─ KEYHOLDR ────────────────────────────────────────────────────────────────╮
│ ● KEYS 15   ○ NOTES 3                               › type to search keys │
├───────────────────────────────────────┬───────────────────────────────────┤
│ ▸  AW  AWS            personal   8mo ⚠│  AWS                              │
│    CL  Claude         learn      5d   │  personal                         │
│    GH  GitHub         work       2w   │                                   │
│                                       │  env var   AWS_API_KEY            │
│                                       │  tags      [dev]                  │
│                                       │  secret    ••••••••••••           │
│                                       │            ⌃R to reveal (Touch ID)│
├───────────────────────────────────────┴───────────────────────────────────┤
│ ⏎ copy · ␣ mark · ⌃R reveal · ⌃N new · ⌃X delete · ⇥ notes · esc quit     │
│ 15 KEYS                                                     LOCKED AT REST│
╰───────────────────────────────────────────────────────────────────────────╯
```

**Keys tab.** Copy and reveal need Touch ID, exactly like `get`. Marking
several keys with **space** and pressing **⏎** copies all their secrets, one
per line. A revealed secret hides itself after 10 seconds. **⌃N** opens a form
to add a key (the secret field is hidden as you type) and **⌃X** deletes after
a confirmation — both use the same rules as `keyholdr add` and `keyholdr rm`.

**Notes tab.** Quick plain-text scratch notes, shared with the menu bar app.
**⏎** copies a note (no Touch ID — notes are not secrets and are stored
unencrypted), **⌃N** starts a new one and **⌃E** edits the selected one in a
multi-line editor. Pasting keeps its newlines; **esc** saves and closes, and an
empty note is discarded.

Because it draws on the alternate screen, nothing you reveal stays in your
terminal's scrollback. On quit, a one-line "Copied … to the clipboard." remains
if you copied something (never the secret itself).

The UI needs a real terminal (stdin and stderr must both be a tty), a `TERM`
other than `dumb`, and at least 60×16 cells — below that it falls back to the
inline picker. Under about 76 columns the detail pane is hidden. In scripts or
pipes, use `list`, `get`, `run`, or `env` instead. If a terminal is ever left in
an odd state (for example after a crash), `reset` restores it.

#### Terminal UI controls

| Key | Action |
|---|---|
| type | filter the current tab (^U clears it, ^W deletes a word) |
| ↑ / ↓, PgUp / PgDn, Home / End | move the selection |
| ⏎ | copy the selection (or every marked key) |
| space | mark / unmark a key (keys tab) |
| ⌃R | reveal / hide the secret (keys tab, Touch ID) |
| ⌃N | new key (keys tab) or new note (notes tab) |
| ⌃E | edit the selected note (notes tab) |
| ⌃X | delete the selection or marked keys, after a `y` confirmation |
| ⇥ / ⇧⇥ | switch between KEYS and NOTES |
| esc | clear the filter; quit when it is already empty (saves and closes the note editor) |
| ^C, ^D | quit |

The UI exits with code `0`. The other commands, and the inline picker, are
unchanged.

---

### `keyholdr list`

Prints every key — platform, label, tags, and age — without ever touching the
Keychain or prompting for Touch ID.

```bash
keyholdr list
# PLATFORM   LABEL     TAGS      AGE
# github     work      dev,ci    14d
# aws        default             3mo ⚠
```

A `⚠` next to the age means the key is old enough that Keyholdr suggests
rotating it.

---

### `keyholdr get <platform>`

Resolves `<platform>` (case-insensitive, substring match — `keyholdr get
git` finds `github`), prompts for Touch ID, then prints the secret to
stdout.

```bash
keyholdr get aws                       # prints to stdout
keyholdr get github --label work       # disambiguate when one platform
                                        # has multiple keys
keyholdr get github --label work --copy  # clipboard instead of stdout
```

If a platform has more than one matching key and `--label` isn't given, the
picker opens to choose — but only in an interactive terminal. In scripts,
ambiguity is a hard error listing the `--label` values to disambiguate with,
so automation never blocks on hidden interactivity.

---

### `keyholdr run`

Runs a command with secrets injected as environment variables in the child
process only — they never touch stdout, files, or shell history.

**Explicit mappings**, one or more `-e ENV_VAR=platform[/label]`:

```bash
keyholdr run -e AWS_ACCESS_KEY_ID=aws -e GITHUB_TOKEN=github/work -- npm start
```

**Multi-select**, with no `-e` flags, in an interactive terminal:

```bash
keyholdr run -- npm start
```

This opens the multi-select picker (**⇥** or **space** to mark, **⏎** to
confirm) and derives conventional env var names automatically — e.g.
`GITHUB_TOKEN`, `AWS_ACCESS_KEY_ID` (see [naming conventions](#env-var-naming)
below).

---

### `keyholdr env`

Selects keys and prints `export NAME='value'` lines (or `NAME=value` with
`--dotenv`) designed to be `eval`'d into your *current* shell — nothing lands
in files or history.

```bash
eval "$(keyholdr env)"                  # multi-select picker
eval "$(keyholdr env aws github/work)"  # name keys directly
eval "$(keyholdr env --dotenv aws)"     # .env-style NAME=value
keyholdr env --names                    # dry run: shows the name mapping
                                         # only, no Touch ID, nothing exported
```

`eval` is required — without it, the `export` lines just print to your
terminal and don't affect your shell's environment. `--names` is a preview:
it never reads secrets or requires Touch ID, and on its own doesn't export
anything.

---

### `keyholdr add <platform>`

Adds a key. The secret is **never** an argument (arguments are visible to
every process via `ps`) — it's read from a hidden prompt, or piped on stdin.

```bash
keyholdr add github --label work --tags dev,ci   # hidden prompt
pbpaste | keyholdr add aws                       # piped from the clipboard
```

`--label` defaults to `default`. An identical platform + label pair is
rejected — use a different `--label` to keep keys addressable.

---

### `keyholdr rm [platform]`

Deletes one or more keys and their Keychain secrets.

```bash
keyholdr rm github --label work   # confirms, then deletes
keyholdr rm github --force        # skip the confirmation prompt (scripts)
keyholdr rm                       # multi-select: ⇥/space to mark, ⏎ deletes
```

With no `platform`, opens the multi-select picker (interactive terminals
only). Without `--force`, deletion always asks for confirmation — and refuses
outright in non-interactive contexts so scripts can't silently wipe keys.

---

## Env var naming

`keyholdr run` (multi-select) and `keyholdr env` derive a conventional
environment variable name per platform:

| Platform contains | Env var |
|---|---|
| github | `GITHUB_TOKEN` |
| gitlab | `GITLAB_TOKEN` |
| huggingface | `HF_TOKEN` |
| slack | `SLACK_TOKEN` |
| discord | `DISCORD_TOKEN` |
| telegram | `TELEGRAM_BOT_TOKEN` |
| vercel | `VERCEL_TOKEN` |
| netlify | `NETLIFY_AUTH_TOKEN` |
| cloudflare | `CLOUDFLARE_API_TOKEN` |
| twilio | `TWILIO_AUTH_TOKEN` |
| npm | `NPM_TOKEN` |
| sentry | `SENTRY_AUTH_TOKEN` |
| claude / anthropic | `ANTHROPIC_API_KEY` |
| chatgpt / openai | `OPENAI_API_KEY` |
| anything else | `<PLATFORM>_API_KEY` |

If selecting multiple keys would produce the same env var name, the label is
appended (then a numeric counter) to keep names unique — e.g. `GITHUB_TOKEN`
and `GITHUB_TOKEN_WORK`.

---

## Inline picker controls

The inline picker is what `--classic` shows, and what `rm`, `run`, `env` and
ambiguous key references use.

| Key | Action |
|---|---|
| type | filter by platform, label, or tag |
| ↑ / ↓ | move selection |
| ⏎ | select (single) / confirm (multi) |
| ⇥ or space | mark/unmark an entry (multi-select only) |
| ^U | clear the filter |
| esc, ^C, ^D | cancel |

`pick --classic`, `rm`, `run`, and `env` all use the multi-select picker. The picker
that resolves an ambiguous `--label`-less reference (e.g. `keyholdr get aws`
matching two keys) is single-select — ⏎ just picks the highlighted entry.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Validation error or declined confirmation |
| `130` | Picker cancelled (esc / ^C / ^D) |
| *other* | Forwarded from the child process for `keyholdr run` |
