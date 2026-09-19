import Foundation
import KeyholdrKit
import KeyholdrTUI

// Drawing for `Dashboard`. Every line is built to exactly the terminal width
// (plain text is fitted *before* it is styled, and `Text.width` ignores ANSI),
// addressed by row, and sent in a single write.

extension Dashboard {
    // MARK: - Entry

    func render(size: TerminalSize) -> String {
        let minimum = Terminal.minimumSize
        guard size.columns >= minimum.columns, size.rows >= minimum.rows else {
            return tooSmall(size)
        }
        return frame(size).enumerated()
            .map { "\u{1B}[\($0.offset + 1);1H" + $0.element }
            .joined()
    }

    private func tooSmall(_ size: TerminalSize) -> String {
        let minimum = Terminal.minimumSize
        let text = "Terminal too small — need \(minimum.columns)×\(minimum.rows), have \(size.columns)×\(size.rows)"
        return "\u{1B}[2J\u{1B}[1;1H" + Text.truncate(text, to: size.columns)
    }

    // MARK: - Styling

    private func sty(_ text: String, _ codes: String...) -> String {
        guard Ansi.enabled, !text.isEmpty else { return text }
        return codes.joined() + text + Ansi.reset
    }

    private func border(_ text: String) -> String { sty(text, Ansi.dim) }

    private func spaces(_ count: Int) -> String { String(repeating: " ", count: max(count, 0)) }

    /// A reverse-video cell standing in for the cursor.
    private func cursorCell(_ character: String) -> String {
        Ansi.enabled ? "\u{1B}[7m\(character)\u{1B}[27m" : character
    }

    private var hasModal: Bool {
        if case .none = modal { return false }
        return true
    }

    // MARK: - Frame

    private func frame(_ size: TerminalSize) -> [String] {
        let width = size.columns
        let inner = width - 2
        let bodyHeight = size.rows - 7
        // Modals take the whole body; otherwise the detail pane needs room.
        let split = inner >= 74 && !hasModal
        let leftWidth = split ? (inner - 1) * 11 / 20 : inner
        let rightWidth = split ? inner - 1 - leftWidth : 0

        func rule(_ left: String, _ mid: String, _ right: String) -> String {
            let dashes = String(repeating: "─", count: leftWidth)
            let rest = split ? mid + String(repeating: "─", count: rightWidth) : ""
            return border(left + dashes + rest + right)
        }

        var lines: [String] = []

        let title = " KEYHOLDR "
        lines.append(
            border("╭─") + sty(title, Ansi.bold, Ansi.accent)
            + border(String(repeating: "─", count: max(inner - 1 - Text.width(title), 0)) + "╮")
        )
        lines.append(border("│") + Text.pad(headerContent(inner), to: inner) + border("│"))
        lines.append(rule("├", "┬", "┤"))

        for row in bodyRows(inner: inner, leftWidth: leftWidth, rightWidth: rightWidth, height: bodyHeight, split: split) {
            lines.append(border("│") + Text.pad(row, to: inner) + border("│"))
        }

        lines.append(rule("├", "┴", "┤"))
        lines.append(border("│") + Text.pad(" " + Text.fit(hints, to: inner - 2), to: inner) + border("│"))
        lines.append(border("│") + Text.pad(statusContent(inner, showsDetail: split), to: inner) + border("│"))
        lines.append(border("╰" + String(repeating: "─", count: inner) + "╯"))
        return lines
    }

    // MARK: - Header

    private func headerContent(_ inner: Int) -> String {
        func label(_ name: String, _ count: Int, active: Bool) -> String {
            active ? sty("● \(name) \(count)", Ansi.bold, Ansi.accent) : sty("○ \(name) \(count)", Ansi.dim)
        }
        let tabs = label("KEYS", allKeys.count, active: tab == .keys)
            + "   " + label("NOTES", allNotes.count, active: tab == .notes)

        let searchWidth = min(32, max(inner / 3, 18))
        let gap = max(inner - 2 - Text.width(tabs) - searchWidth, 1)
        return " " + tabs + spaces(gap) + searchField(width: searchWidth) + " "
    }

    private func searchField(width: Int) -> String {
        let filter = tab == .keys ? keyFilter : noteFilter
        let prefix = sty("› ", Ansi.accent, Ansi.bold)
        let room = width - 2

        guard !filter.isEmpty else {
            let placeholder = tab == .keys ? "type to search keys" : "type to search notes"
            let cursor = hasModal ? "" : cursorCell(" ")
            return prefix + Text.pad(cursor + sty(Text.fit(placeholder, to: max(room - 1, 0)), Ansi.dim), to: room)
        }
        // Keep the tail of long queries visible.
        var visible = ""
        var used = 0
        for character in filter.string.reversed() {
            let w = Text.width(of: character)
            if used + w > room - 1 { break }
            visible = String(character) + visible
            used += w
        }
        return prefix + Text.pad(visible + (hasModal ? "" : cursorCell(" ")), to: room)
    }

    // MARK: - Footer

    private var hints: String {
        switch modal {
        case .none:
            return tab == .keys
                ? "⏎ copy · ␣ mark · ⌃R reveal · ^N new (Ctrl+N) · ⌃X delete · ⇥/←/→ notes · esc quit"
                : "⏎ copy · ⌃E edit · ^N new (Ctrl+N) · ⌃X delete · ⇥/←/→ keys · esc quit"
        case .confirm:
            return "y confirm · n / esc cancel"
        case .addKey:
            return "⇥ next field · ⏎ next / save · ⌃S save · esc cancel"
        case .editNote:
            return "esc save & close · ⌃S save · ⌃U clear line · ⌃W delete word"
        }
    }

    private func statusContent(_ inner: Int, showsDetail: Bool) -> String {
        let rightText = tab == .keys ? "LOCKED AT REST" : "PLAIN TEXT · NOT ENCRYPTED"
        let rightWidth = Text.width(rightText)
        let leftRoom = max(inner - 3 - rightWidth, 10)

        let left: String
        if let busy {
            left = sty(Text.fit("● " + busy, to: leftRoom), Ansi.accent)
        } else if let toast {
            let mark = toast.isError ? "✕ " : "✓ "
            left = sty(Text.fit(mark + toast.text, to: leftRoom), toast.isError ? Ansi.red : Ansi.green)
        } else if let reveal, tab == .keys, !showsDetail, !hasModal {
            let seconds = max(Int(reveal.until.timeIntervalSinceNow.rounded(.up)), 0)
            left = Text.fit("secret: \(reveal.secret)  (\(seconds)s)", to: leftRoom)
        } else {
            left = sty(Text.fit(countText, to: leftRoom), Ansi.dim)
        }
        return " " + Text.pad(left, to: leftRoom) + " " + sty(rightText, Ansi.dim) + " "
    }

    private var countText: String {
        switch tab {
        case .keys:
            let total = "\(allKeys.count) \(allKeys.count == 1 ? "KEY" : "KEYS")"
            let shown = keyFilter.isEmpty ? "" : " · \(visibleKeys.count) MATCH"
            let picked = marked.isEmpty ? "" : " · \(marked.count) MARKED"
            return total + shown + picked
        case .notes:
            let total = "\(allNotes.count) \(allNotes.count == 1 ? "NOTE" : "NOTES")"
            let shown = noteFilter.isEmpty ? "" : " · \(visibleNotes.count) MATCH"
            return total + shown
        }
    }

    // MARK: - Body

    private func bodyRows(inner: Int, leftWidth: Int, rightWidth: Int, height: Int, split: Bool) -> [String] {
        switch modal {
        case .confirm(let confirm):
            return centered(confirmLines(confirm), width: inner, height: height)
        case .addKey(let form):
            return addFormLines(form, width: inner, height: height)
        case .editNote(let editor):
            return editorLines(editor, width: inner, height: height)
        case .none:
            break
        }

        let left = tab == .keys
            ? keyListRows(width: leftWidth, height: height)
            : noteListRows(width: leftWidth, height: height)
        guard split else { return left }

        let right = tab == .keys
            ? keyDetailRows(width: rightWidth, height: height)
            : noteDetailRows(width: rightWidth, height: height)
        return zip(left, right).map { Text.pad($0, to: leftWidth) + border("│") + Text.pad($1, to: rightWidth) }
    }

    private func blanks(_ count: Int, width: Int) -> [String] {
        Array(repeating: spaces(width), count: max(count, 0))
    }

    /// Exactly `height` rows of `width` cells, centring `content` in both directions.
    private func centered(_ content: [String], width: Int, height: Int) -> [String] {
        let top = max((height - content.count) / 2, 0)
        var rows = blanks(top, width: width)
        for line in content.prefix(height - top) {
            let pad = max((width - Text.width(line)) / 2, 0)
            rows.append(Text.pad(spaces(pad) + line, to: width))
        }
        rows += blanks(height - rows.count, width: width)
        return Array(rows.prefix(height))
    }

    // MARK: - Keys tab

    private func keyListRows(width: Int, height: Int) -> [String] {
        let keys = visibleKeys
        guard !keys.isEmpty else {
            let message = keyFilter.isEmpty
                ? [sty("No keys yet.", Ansi.dim), "",
                   "Press " + sty("⏎", Ansi.bold, Ansi.accent) + " or " + sty("⌃N", Ansi.bold, Ansi.accent) + " to add your first key."]
                : [sty("No matching keys.", Ansi.dim), "",
                   "Press " + sty("⏎", Ansi.bold, Ansi.accent) + " to add “" + Text.truncate(keyFilter.string, to: 24) + "” as a new key."]
            return centered(message, width: width, height: height)
        }

        if keyIndex < keyTop { keyTop = keyIndex }
        if keyIndex >= keyTop + height { keyTop = keyIndex - height + 1 }
        keyTop = max(0, min(keyTop, max(keys.count - height, 0)))

        var rows: [String] = []
        for offset in 0..<height {
            let index = keyTop + offset
            rows.append(index < keys.count
                        ? keyRow(keys[index], selected: index == keyIndex, width: width)
                        : spaces(width))
        }
        return rows
    }

    private func keyRow(_ key: KeyItem, selected: Bool, width: Int) -> String {
        let ageWidth = 6
        let fixed = 16 + (ageWidth - 6)
        let rest = max(width - fixed, 4)
        let showLabel = rest >= 14
        let platformWidth = showLabel ? rest * 55 / 100 : rest
        let labelWidth = showLabel ? rest - platformWidth : 0

        let age = key.compactAge + (key.isStale ? " ⚠" : "")
        let marker = selected ? "▸" : " "
        let mark = marked.contains(key.id) ? "◉ " : "  "
        let platform = Text.fit(key.platform, to: platformWidth)
        let label = showLabel ? " " + Text.fit(key.label, to: labelWidth) : ""
        let agePart = Text.padLeft(age, to: ageWidth)

        if selected {
            // One plain string: nested resets would cut the highlight short.
            let line = "\(marker)\(mark)\(key.initials)  \(platform)\(label) \(agePart) "
            return sty(Text.pad(line, to: width), Ansi.bold, Ansi.dark, Ansi.accentBg)
        }
        let styledMark = marked.contains(key.id) ? sty("◉ ", Ansi.accent) : "  "
        return marker + styledMark + sty(key.initials, Ansi.bold) + "  " + platform
            + sty(label, Ansi.dim) + " " + sty(agePart, key.isStale ? Ansi.red : Ansi.dim) + " "
    }

    private func keyDetailRows(width: Int, height: Int) -> [String] {
        guard let key = selectedKey else { return blanks(height, width: width) }
        let inner = max(width - 4, 10)
        let valueWidth = max(inner - 10, 4)

        func row(_ name: String, _ value: String) -> String {
            sty(Text.pad(name, to: 10), Ansi.dim) + Text.fit(value, to: valueWidth)
        }

        var lines: [String] = [
            sty(Text.fit(key.platform, to: inner), Ansi.bold, Ansi.accent),
            sty(Text.fit(key.label, to: inner), Ansi.dim),
            "",
            row("env var", key.suggestedEnvName),
            row("tags", key.tags.isEmpty ? "—" : key.tags.map { "[\($0)]" }.joined(separator: " ")),
            row("created", Self.dateFormatter.string(from: key.dateCreated)),
            row("rotated", key.compactAge + " ago" + (key.isStale ? " ⚠ rotate?" : "")),
            "",
        ]

        if let reveal, reveal.id == key.id {
            let wrapped = Text.wrap(reveal.secret, to: valueWidth)
            let room = max(height - lines.count - 2, 1)
            for (i, part) in wrapped.prefix(room).enumerated() {
                lines.append((i == 0 ? sty(Text.pad("secret", to: 10), Ansi.dim) : spaces(10)) + part)
            }
            if wrapped.count > room { lines[lines.count - 1] = lines[lines.count - 1] + sty("…", Ansi.dim) }
            let seconds = max(Int(reveal.until.timeIntervalSinceNow.rounded(.up)), 0)
            lines.append(spaces(10) + sty("hides in \(seconds)s · ⌃R to hide now", Ansi.dim))
        } else {
            lines.append(row("secret", "••••••••••••"))
            lines.append(spaces(10) + sty("⌃R to reveal (Touch ID)", Ansi.dim))
        }

        return padRows(lines.map { "  " + $0 }, width: width, height: height)
    }

    // MARK: - Notes tab

    private func noteListRows(width: Int, height: Int) -> [String] {
        let notes = visibleNotes
        guard !notes.isEmpty else {
            let message = noteFilter.isEmpty
                ? [sty("No notes yet.", Ansi.dim), "",
                   "Press " + sty("⏎", Ansi.bold, Ansi.accent) + " or " + sty("⌃N", Ansi.bold, Ansi.accent) + " to write one."]
                : [sty("No matching notes.", Ansi.dim), "",
                   "Press " + sty("⏎", Ansi.bold, Ansi.accent) + " to save “" + Text.truncate(noteFilter.string, to: 24) + "” as a new note."]
            return centered(message, width: width, height: height)
        }

        if noteIndex < noteTop { noteTop = noteIndex }
        if noteIndex >= noteTop + height { noteTop = noteIndex - height + 1 }
        noteTop = max(0, min(noteTop, max(notes.count - height, 0)))

        var rows: [String] = []
        for offset in 0..<height {
            let index = noteTop + offset
            rows.append(index < notes.count
                        ? noteRow(notes[index], selected: index == noteIndex, width: width)
                        : spaces(width))
        }
        return rows
    }

    private func noteRow(_ note: NoteItem, selected: Bool, width: Int) -> String {
        let ageWidth = 9
        let rest = max(width - (ageWidth + 6), 4)
        let showPreview = rest >= 20
        let titleWidth = showPreview ? rest * 45 / 100 : rest
        let previewWidth = showPreview ? rest - titleWidth : 0

        let marker = selected ? "▸" : " "
        let title = Text.fit(note.title, to: titleWidth)
        let preview = showPreview ? "  " + Text.fit(note.preview, to: previewWidth - 2) : ""
        let age = Text.padLeft(note.ageLabel(), to: ageWidth)

        if selected {
            let line = "\(marker) \(title)\(preview) \(age) "
            return sty(Text.pad(line, to: width), Ansi.bold, Ansi.dark, Ansi.accentBg)
        }
        return marker + " " + sty(title, Ansi.bold) + sty(preview, Ansi.dim) + " " + sty(age, Ansi.dim) + " "
    }

    private func noteDetailRows(width: Int, height: Int) -> [String] {
        guard let note = selectedNote else { return blanks(height, width: width) }
        let inner = max(width - 4, 10)

        var lines = [
            sty(Text.fit(note.title, to: inner), Ansi.bold, Ansi.accent),
            sty("EDITED \(note.ageLabel())", Ansi.dim),
            "",
        ]
        let body = Text.wrap(note.text, to: inner)
        let room = max(height - lines.count, 1)
        lines += body.prefix(room)
        if body.count > room { lines[lines.count - 1] = sty("…", Ansi.dim) }

        return padRows(lines.map { "  " + $0 }, width: width, height: height)
    }

    // MARK: - Modals

    private func confirmLines(_ confirm: Confirm) -> [String] {
        var lines: [String] = []
        switch confirm {
        case .deleteKeys(let targets):
            lines.append(sty(targets.count == 1
                             ? "Delete \(targets[0].platform) (\(targets[0].label))?"
                             : "Delete \(targets.count) keys?", Ansi.bold))
            for key in targets.prefix(4) where targets.count > 1 {
                lines.append(sty("\(key.platform) (\(key.label))", Ansi.dim))
            }
            if targets.count > 4 { lines.append(sty("…and \(targets.count - 4) more", Ansi.dim)) }
            lines.append("")
            lines.append(sty("This permanently erases \(targets.count == 1 ? "the secret" : "the secrets") from your Keychain.", Ansi.red))
        case .deleteNote(let note):
            lines.append(sty("Delete “\(Text.truncate(note.title, to: 40))”?", Ansi.bold))
            lines.append("")
            lines.append(sty("This can't be undone.", Ansi.red))
        }
        lines.append("")
        lines.append(sty("y", Ansi.bold, Ansi.accent) + " delete      " + sty("n", Ansi.bold, Ansi.accent) + " cancel")
        return lines
    }

    private func addFormLines(_ form: AddForm, width: Int, height: Int) -> [String] {
        let titles = ["Platform", "Label", "Tags", "Secret"]
        let placeholders = ["e.g. GitHub, AWS, Stripe", "default", "comma separated, optional", "hidden as you type"]
        let valueWidth = max(width - 16, 8)

        var lines = ["  " + sty("New key", Ansi.bold, Ansi.accent), ""]
        for index in form.fields.indices {
            let focused = index == form.focus
            let name = sty(Text.pad(titles[index], to: 10), focused ? Ansi.accent : Ansi.dim, focused ? Ansi.bold : "")
            let field = form.fields[index]
            let value: String
            if field.isEmpty && !focused {
                value = sty(Text.fit(placeholders[index], to: valueWidth), Ansi.dim)
            } else {
                value = cursorLine(
                    Array(field.characters), cursor: focused ? field.cursor : nil,
                    width: valueWidth, mask: index == 3 ? "•" : nil
                )
            }
            lines.append("  " + (focused ? sty("› ", Ansi.accent, Ansi.bold) : "  ") + name + value)
        }
        lines.append("")
        if let error = form.error {
            lines.append("  " + sty(Text.fit("✕ " + error, to: width - 4), Ansi.red))
        }
        return padRows(lines, width: width, height: height)
    }

    private func editorLines(_ editor: NoteEditor, width: Int, height: Int) -> [String] {
        let rows = max(height - 2, 1)
        let currentLine = editor.buffer.position.line
        let lines = editor.buffer.lines

        // Keep the cursor line in view; persist the scroll so it doesn't jump.
        var top = editor.scrollTop
        if currentLine < top { top = currentLine }
        if currentLine >= top + rows { top = currentLine - rows + 1 }
        top = max(0, min(top, max(lines.count - 1, 0)))
        if top != editor.scrollTop {
            var updated = editor
            updated.scrollTop = top
            modal = .editNote(updated)
        }

        let heading = editor.isNew ? "New note" : "Editing · " + Text.truncate(editor.note.title, to: 40)
        var out = [
            "  " + sty(heading, Ansi.bold, Ansi.accent) + sty("   \(lines.count) \(lines.count == 1 ? "line" : "lines")", Ansi.dim),
            "",
        ]
        let room = max(width - 4, 8)
        for offset in 0..<rows {
            let index = top + offset
            guard index < lines.count else { out.append(""); continue }
            let text = "  " + (index == currentLine
                ? cursorLine(of: editor.buffer, lineText: lines[index], width: room)
                : Text.fit(lines[index], to: room))
            out.append(text)
        }
        return padRows(out, width: width, height: height)
    }

    /// The cursor's line, windowed horizontally so the cursor stays visible.
    private func cursorLine(of buffer: TextBuffer, lineText: String, width: Int) -> String {
        cursorLine(Array(lineText), cursor: buffer.position.column, width: width, mask: nil)
    }

    /// Renders a single line of `characters` with a reverse-video cursor cell
    /// (when `cursor` is non-nil), scrolled horizontally to keep it visible.
    /// `mask` replaces every character (for the secret field). Exactly `width` cells.
    private func cursorLine(_ characters: [Character], cursor: Int?, width: Int, mask: Character?) -> String {
        let shown = mask.map { m in characters.map { _ in m } } ?? characters
        guard let cursor else { return Text.fit(String(shown), to: width) }

        // Scroll so the cursor cell (and its leading text) fit in `width`.
        var start = 0
        while start < cursor, Text.width(String(shown[start..<cursor])) > width - 1 { start += 1 }

        let before = String(shown[start..<min(cursor, shown.count)])
        let under = cursor < shown.count ? String(shown[cursor]) : " "
        var after = cursor < shown.count ? String(shown[(cursor + 1)...]) : ""
        let used = Text.width(before) + Text.width(under)
        after = Text.truncate(after, to: max(width - used, 0), ellipsis: "")
        return Text.pad(before + cursorCell(under) + after, to: width)
    }

    /// Exactly `height` rows of `width` cells, top-aligned.
    private func padRows(_ lines: [String], width: Int, height: Int) -> [String] {
        var rows = lines.prefix(height).map { Text.pad($0, to: width) }
        rows += blanks(height - rows.count, width: width)
        return Array(rows)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
}
