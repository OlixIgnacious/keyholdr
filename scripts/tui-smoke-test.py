#!/usr/bin/env python3
"""Drives the CLI's full-screen UI through a pseudo-terminal against a throwaway vault.

Usage: python3 scripts/tui-smoke-test.py [path-to-keyholdr-cli]   (default: .build/debug/keyholdr-cli)

Safety: HOME / CFFIXED_USER_HOME point at a temp dir holding fake keys.json + notes.json, so
your real vault is never read or written. The test never saves or deletes a key and never
triggers Touch ID (both would touch the real Keychain), it only exercises browsing, filtering,
tabs, the notes editor, modals, validation, resize and terminal restore.
"""
import codecs, fcntl, json, os, pty, re, select, signal, struct, sys, tempfile, termios, time, uuid

CLI = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".build/debug/keyholdr-cli")
HOME = tempfile.mkdtemp(prefix="kh-tui-")
SUPPORT = f"{HOME}/Library/Application Support/com.olixstudios.Keyholdr"
os.makedirs(SUPPORT)
now = time.time() - 978307200  # seconds since 2001, JSONEncoder's default Date format
def key(platform, label, tags, age_days):
    return {"id": str(uuid.uuid4()), "platform": platform, "label": label, "tags": tags,
            "dateCreated": now - age_days * 86400, "secretUpdatedAt": now - age_days * 86400}
json.dump([key("AWS", "personal", ["dev"], 250), key("GitHub", "work", ["dev", "ci"], 20),
           key("Claude", "learn", [], 5), key("Stripe", "live", ["prod"], 40)], open(f"{SUPPORT}/keys.json", "w"))
iso = lambda secs: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - secs))
json.dump([{"id": str(uuid.uuid4()), "text": "Standup notes\n- ship the TUI", "createdAt": iso(3600), "updatedAt": iso(3600)},
           {"id": str(uuid.uuid4()), "text": "curl staging health", "createdAt": iso(86400*3), "updatedAt": iso(86400*3)}],
          open(f"{SUPPORT}/notes.json", "w"))

ESC = "\x1b"
DECODERS = {}
failures = 0
LAST = None
strip = lambda text: re.sub(r"\x1b\[[0-9;]*m", "", text)
def check(cond, label):
    global failures
    print(("  ok   " if cond else "  FAIL ") + label)
    if not cond:
        failures += 1
        if os.environ.get("DEBUG") and LAST:
            for r in sorted(LAST.grid):
                line = strip(LAST.grid[r])
                print(f"      | {line}   [{len(line)}]")

class Screen:
    """Just enough VT emulation for what the UI emits: CSI r;cH addressing, 2J, SGR."""
    def __init__(self, rows, cols):
        self.rows, self.cols, self.grid, self.raw, self.held, self.row = rows, cols, {}, "", "", 1
    def feed(self, data):
        self.raw += data
        data = self.held + data
        m = re.search(r"\x1b(\[[0-9;?]*)?$", data)   # a sequence cut off by the read boundary
        self.held = m.group(0) if m else ""
        if m: data = data[:m.start()]
        row = self.row
        for m in re.finditer(r"\x1b\[(\d+);1H|\x1b\[2J|\x1b\[[0-9;?]*[a-zA-Z]|([^\x1b]+)", data):
            if m.group(1): row = int(m.group(1)); self.grid[row] = ""
            elif m.group(0) == ESC + "[2J": self.grid = {}
            elif m.group(2): self.grid[row] = self.grid.get(row, "") + m.group(2).replace("\r", "").replace("\n", "")
        self.row = row
    def text(self): return "\n".join(self.grid.get(r, "") for r in sorted(self.grid))

def spawn(args, rows=28, cols=100):
    pid, fd = pty.fork()
    if pid == 0:
        env = dict(os.environ, HOME=HOME, CFFIXED_USER_HOME=HOME, TERM="xterm-256color")
        env.pop("NO_COLOR", None)
        os.execve(CLI, [CLI, *args], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    return pid, fd, Screen(rows, cols)

def pump(fd, screen, wait=0.6):
    global LAST
    LAST = screen
    end = time.time() + wait
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: data = DECODERS.setdefault(fd, codecs.getincrementaldecoder("utf8")("replace")).decode(os.read(fd, 65536))
            except OSError: return False
            if not data: return False
            screen.feed(data); end = max(end, time.time() + 0.15)
    return True

def send(fd, screen, data, wait=0.5):
    os.write(fd, data.encode()); pump(fd, screen, wait)

def finish(pid, fd, screen, timeout=3):
    end = time.time() + timeout
    while time.time() < end:
        pump(fd, screen, 0.1)
        done, status = os.waitpid(pid, os.WNOHANG)
        if done: return os.waitstatus_to_exitcode(status)
    os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); return None

# ── 1. launch, render ─────────────────────────────────────────────────────────
print("launch + render")
pid, fd, scr = spawn([]); pump(fd, scr, 1.0)
t = scr.text()
check("KEYHOLDR" in t and "KEYS 4" in t and "NOTES 2" in t, "header shows both tabs with counts")
check("AWS" in t and "GitHub" in t and "Claude" in t and "Stripe" in t, "all four keys listed")
check("env var" in t and "AWS_API_KEY" in t, "detail pane shows the selected key (AWS_API_KEY)")
check("⌃R to reveal" in t and "••••" in t, "secret is masked until revealed")
check("LOCKED AT REST" in t, "footer shows LOCKED AT REST on keys tab")
check("╭" in t and "╰" in t, "box frame drawn")
check(all(len(strip(scr.grid[r])) == 100 for r in range(1, 29) if r in scr.grid),
      "every row is exactly 100 columns (no ragged edges)")

# ── 2. filter ────────────────────────────────────────────────────────────────
print("filter")
send(fd, scr, "git"); t = scr.text()
check("GitHub" in t and "AWS_API_KEY" not in t, "typing filters the list")
check("1 MATCH" in t, "status row counts matches")
send(fd, scr, ESC); t = scr.text()
check("Stripe" in t and "AWS" in t, "Esc clears the filter (does not quit)")
send(fd, scr, "zzzz"); check("No matching keys." in scr.text(), "empty result state")
send(fd, scr, ESC)

# ── 3. navigation + marks ────────────────────────────────────────────────────
print("navigation")
send(fd, scr, ESC + "[B"); check("ANTHROPIC_API_KEY" in scr.text(), "↓ moves the selection (AWS → Claude, alphabetical)")
send(fd, scr, " "); check("1 MARKED" in scr.text(), "space marks a key")
send(fd, scr, " "); check("2 MARKED" in scr.text(), "marking advances and stacks")

# ── 4. tabs + notes ──────────────────────────────────────────────────────────
print("notes tab")
send(fd, scr, "\t"); t = scr.text()
check("PLAIN TEXT" in t and "Standup notes" in t and "curl staging" in t, "Notes tab lists notes, footer says PLAIN TEXT")
check("EDITED" in t, "notes detail pane shows the note")
send(fd, scr, "\x0e"); check("New note" in scr.text(), "⌃N opens a new note editor")
send(fd, scr, ESC + "[200~first line\nsecond line" + ESC + "[201~", 0.6)
t = scr.text()
check("first line" in t and "second line" in t, "bracketed paste keeps its newline (does not fire Enter/save)")
check("2 lines" in t, "editor reports 2 lines")
send(fd, scr, ESC, 0.8)
notes = json.load(open(f"{SUPPORT}/notes.json"))
check(any(n["text"] == "first line\nsecond line" for n in notes), "Esc saved the note to notes.json")
check(len(notes) == 3, "the two existing notes are preserved")
check("first line" in scr.text(), "new note appears at the top of the list")

# empty new note is discarded
send(fd, scr, "\x0e"); send(fd, scr, ESC, 0.8)
check(len(json.load(open(f"{SUPPORT}/notes.json"))) == 3, "an empty new note is discarded")

# delete confirm: cancel
send(fd, scr, "\x18"); check("Delete" in scr.text() and "can't be undone" in scr.text(), "⌃X asks before deleting a note")
send(fd, scr, "n"); check("can't be undone" not in scr.text(), "n cancels")
check(len(json.load(open(f"{SUPPORT}/notes.json"))) == 3, "cancelled delete removed nothing")
# delete confirm: accept (only touches the temp notes.json)
send(fd, scr, "\x18"); send(fd, scr, "y", 0.8)
check(len(json.load(open(f"{SUPPORT}/notes.json"))) == 2, "y deleted the selected note")

# ── 5. add-key form validation (never saves) ─────────────────────────────────
print("add-key form")
send(fd, scr, "\t"); send(fd, scr, "\x0e")
t = scr.text(); check("New key" in t and "Platform" in t and "Secret" in t, "⌃N on the keys tab opens the add form")
send(fd, scr, "\x13"); check("Platform is required." in scr.text(), "saving an empty form shows a validation error")
send(fd, scr, "Test"); check("Platform is required." not in scr.text(), "typing clears the error")
send(fd, scr, "\r\r\r"); send(fd, scr, "s3cret")
check("••••••" in scr.text() and "s3cret" not in scr.text(), "secret field is masked")
send(fd, scr, ESC); check("New key" not in scr.text(), "Esc cancels the form without saving")
check(len(json.load(open(f"{SUPPORT}/keys.json"))) == 4, "keys.json unchanged (nothing saved)")

# ── 6. resize ────────────────────────────────────────────────────────────────
print("resize")
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 10, 40, 0, 0)); os.kill(pid, signal.SIGWINCH); pump(fd, scr, 0.8)
check("too small" in scr.text(), "shrinking below 60×16 shows 'terminal too small'")
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 70, 0, 0)); os.kill(pid, signal.SIGWINCH); pump(fd, scr, 0.8)
check("KEYHOLDR" in scr.text(), "growing back redraws the UI")
narrow = scr.text()
check("env var" not in narrow, "at 70 columns the detail pane hides (list only)")

# ── 7. quit + terminal restore ───────────────────────────────────────────────
print("quit + restore")
send(fd, scr, ESC, 0.3)
code = finish(pid, fd, scr)
check(code == 0, f"Esc quits with exit code 0 (got {code})")
tail = scr.raw[-200:]
check("\x1b[?1049l" in tail and "\x1b[?25h" in tail and "\x1b[?2004l" in tail and "\x1b[?7h" in tail,
      "leaves the alternate screen, shows the cursor, ends bracketed paste, re-enables wrap")

for label, how in (("⌃C", lambda p, f, s: send(f, s, "\x03", 0.3)),
                   ("SIGTERM", lambda p, f, s: os.kill(p, signal.SIGTERM)),
                   ("SIGHUP", lambda p, f, s: os.kill(p, signal.SIGHUP))):
    pid, fd, scr = spawn([]); pump(fd, scr, 0.8); how(pid, fd, scr)
    code = finish(pid, fd, scr)
    check(code == 0 and "\x1b[?1049l" in scr.raw[-200:] and "\x1b[?25h" in scr.raw[-200:],
          f"{label} exits cleanly and restores the terminal (code {code})")

# ── 8. one-liners + fallbacks ────────────────────────────────────────────────
print("classic + fallbacks")
pid, fd, scr = spawn(["--classic"]); pump(fd, scr, 0.8)
check("1049h" not in scr.raw and "type to filter" in scr.raw, "--classic shows the inline picker (no alternate screen)")
send(fd, scr, ESC, 0.3); finish(pid, fd, scr)
os.environ["KEYHOLDR_CLASSIC"] = "1"
pid, fd, scr = spawn([]); pump(fd, scr, 0.8)
check("1049h" not in scr.raw and "type to filter" in scr.raw, "KEYHOLDR_CLASSIC=1 also forces the inline picker")
send(fd, scr, ESC, 0.3); finish(pid, fd, scr)
del os.environ["KEYHOLDR_CLASSIC"]
pid, fd, scr = spawn([], rows=10, cols=40); pump(fd, scr, 0.8)
check("1049h" not in scr.raw and "type to filter" in scr.raw, "a terminal smaller than 60×16 falls back to the inline picker")
send(fd, scr, ESC, 0.3); finish(pid, fd, scr)
pid, fd, scr = spawn(["git"]); pump(fd, scr, 0.8)
check("› git" in scr.text() and "GITHUB_TOKEN" in scr.text() and "AWS_API_KEY" not in scr.text(), "`keyholdr git` opens the UI pre-filtered")
send(fd, scr, ESC + ESC, 0.3); finish(pid, fd, scr)

print(f"\n{'ALL PASSED' if failures == 0 else str(failures) + ' FAILED'}")
sys.exit(1 if failures else 0)
