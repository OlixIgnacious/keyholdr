import Darwin
import Foundation
import KeyholdrKit

/// An fzf-style inline picker: type to filter, ↑↓ to move, ⏎ to select,
/// esc to cancel. In multi mode, tab/space mark entries. Renders on stderr
/// and reads raw bytes from the tty, so stdout stays clean for piping.
enum Picker {
    /// Interactive UI is only possible when a human is on both ends.
    static var isInteractive: Bool {
        isatty(STDIN_FILENO) != 0 && isatty(STDERR_FILENO) != 0
    }

    static func pick(from all: [KeyItem], title: String, initialFilter: String = "") -> KeyItem? {
        run(from: all, title: title, initialFilter: initialFilter, multi: false)?.first
    }

    /// Multi-select variant; returns nil on cancel, the marked items on ⏎
    /// (or the highlighted item when nothing was marked).
    static func pickMany(from all: [KeyItem], title: String, initialFilter: String = "") -> [KeyItem]? {
        run(from: all, title: title, initialFilter: initialFilter, multi: true)
    }

    private static func run(from all: [KeyItem], title: String, initialFilter: String, multi: Bool) -> [KeyItem]? {
        guard isInteractive, !all.isEmpty else { return nil }

        var original = termios()
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        // No echo, no line buffering; ISIG off so ^C restores the terminal
        // through our own handling instead of killing us mid-raw-mode.
        raw.c_lflag &= ~UInt(ECHO | ICANON | ISIG)
        // TCSANOW, not TCSAFLUSH: flushing would discard keys typed before
        // raw mode engaged (fast typists, piped test input).
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        defer { tcsetattr(STDIN_FILENO, TCSANOW, &original) }

        let err = FileHandle.standardError
        var filter = initialFilter
        var index = 0
        var renderedLines = 0
        // Keyed by id, not row index — filtering reshuffles indices and the
        // marks must stay on the same keys.
        var marked = Set<UUID>()

        func write(_ s: String) { err.write(Data(s.utf8)) }

        func matches() -> [KeyItem] {
            let q = filter.lowercased()
            guard !q.isEmpty else { return all }
            return all.filter {
                $0.platform.lowercased().contains(q)
                    || $0.label.lowercased().contains(q)
                    || $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }

        func render() {
            let items = matches()
            index = min(index, max(items.count - 1, 0))

            let hints = multi
                ? "type to filter · ↑↓ move · ⇥/space mark · ⏎ confirm · esc cancel"
                : "type to filter · ↑↓ move · ⏎ select · esc cancel"
            let selection = multi && !marked.isEmpty ? " — \(marked.count) marked" : ""

            var out = ""
            if renderedLines > 0 { out += "\u{1B}[\(renderedLines)A" }
            out += "\r\u{1B}[J"
            out += Ansi.style(title, Ansi.bold, Ansi.accent)
            out += Ansi.style("\(selection) — \(hints)", Ansi.dim) + "\n"
            out += Ansi.style("›", Ansi.accent, Ansi.bold) + " \(filter)\n"
            for (i, key) in items.enumerated() {
                let mark = multi ? (marked.contains(key.id) ? "◉ " : "○ ") : ""
                let tags = key.tags.isEmpty ? "" : "  [\(key.tags.joined(separator: ","))]"
                let age = key.isStale ? "  ⚠ \(key.compactAge)" : "  \(key.compactAge)"
                let line = "  \(mark)\(key.platform) · \(key.label)\(tags)\(age)  "
                if i == index {
                    // Embedded ANSI in the mark would reset the highlight
                    // partway through, so the selected row is styled as one
                    // plain string with no nested color codes.
                    out += Ansi.style(line, Ansi.bold, Ansi.dark, Ansi.accentBg) + "\n"
                } else if multi {
                    let styledMark = marked.contains(key.id) ? Ansi.style("◉ ", Ansi.accent) : Ansi.style("○ ", Ansi.dim)
                    out += "  \(styledMark)\(key.platform) · \(key.label)\(tags)\(age)  \n"
                } else {
                    out += "\(line)\n"
                }
            }
            if items.isEmpty { out += Ansi.style("  no matches", Ansi.dim) + "\n" }
            renderedLines = 2 + max(items.count, 1)
            write(out)
        }

        func clearUI() {
            write("\u{1B}[\(renderedLines)A\r\u{1B}[J")
        }

        func toggleCurrent() {
            let items = matches()
            guard !items.isEmpty else { return }
            let id = items[index].id
            if marked.contains(id) { marked.remove(id) } else { marked.insert(id) }
            // fzf-style: marking advances to the next row.
            index = min(index + 1, items.count - 1)
            render()
        }

        func readByte() -> UInt8? {
            var byte: UInt8 = 0
            return read(STDIN_FILENO, &byte, 1) == 1 ? byte : nil
        }

        /// True when more bytes are immediately available (distinguishes a
        /// lone esc keypress from an escape sequence like ↑).
        func hasPendingInput() -> Bool {
            var fd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            return poll(&fd, 1, 25) > 0
        }

        render()
        while true {
            guard let byte = readByte() else { clearUI(); return nil }
            switch byte {
            case 0x1B: // esc — alone cancels, as a CSI prefix it's an arrow
                guard hasPendingInput(), readByte() == 0x5B, let code = readByte() else {
                    clearUI()
                    return nil
                }
                let count = matches().count
                if code == 0x41 { index = max(index - 1, 0) }                  // ↑
                if code == 0x42 { index = min(index + 1, max(count - 1, 0)) }  // ↓
                render()
            case 0x09: // tab — mark (multi only)
                if multi { toggleCurrent() }
            case 0x0D, 0x0A: // enter
                let items = matches()
                clearUI()
                if multi, !marked.isEmpty {
                    return all.filter { marked.contains($0.id) }
                }
                return items.isEmpty ? nil : [items[index]]
            case 0x03, 0x04: // ^C, ^D
                clearUI()
                return nil
            case 0x7F, 0x08: // backspace
                if !filter.isEmpty { filter.removeLast() }
                render()
            case 0x15: // ^U — clear the filter
                filter = ""
                render()
            case 0x20: // space — mark in multi mode, filter text otherwise
                if multi {
                    toggleCurrent()
                } else {
                    filter.append(" ")
                    index = 0
                    render()
                }
            case 0x21...0x7E: // printable ASCII
                filter.append(Character(UnicodeScalar(byte)))
                index = 0
                render()
            default:
                break
            }
        }
    }
}
