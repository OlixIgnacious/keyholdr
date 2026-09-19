import Foundation

/// An editable text model with a cursor, used for the search box, the add
/// form and the note editor. Lines are separated by "\n"; `multiline: false`
/// buffers turn pasted newlines into spaces.
public struct TextBuffer: Equatable, Sendable {
    public private(set) var characters: [Character]
    /// Insertion point, as an index in `0...characters.count`.
    public private(set) var cursor: Int
    public let multiline: Bool
    /// Column to return to when moving up/down across shorter lines.
    private var desiredColumn: Int?

    public init(_ text: String = "", multiline: Bool = false) {
        self.multiline = multiline
        let normalized = TextBuffer.normalize(text, multiline: multiline)
        characters = Array(normalized)
        cursor = characters.count
    }

    public var string: String { String(characters) }
    public var isEmpty: Bool { characters.isEmpty }
    public var lines: [String] {
        string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Cursor location as (line, column) — column in characters.
    public var position: (line: Int, column: Int) {
        var line = 0
        var column = 0
        for character in characters[..<cursor] {
            if character == "\n" { line += 1; column = 0 } else { column += 1 }
        }
        return (line, column)
    }

    public mutating func setText(_ text: String) {
        characters = Array(TextBuffer.normalize(text, multiline: multiline))
        cursor = characters.count
        desiredColumn = nil
    }

    // MARK: - Editing

    public mutating func insert(_ text: String) {
        let clean = TextBuffer.normalize(text, multiline: multiline)
        guard !clean.isEmpty else { return }
        characters.insert(contentsOf: clean, at: cursor)
        cursor += clean.count
        desiredColumn = nil
    }

    public mutating func newline() {
        guard multiline else { return }
        insert("\n")
    }

    public mutating func backspace() {
        guard cursor > 0 else { return }
        characters.remove(at: cursor - 1)
        cursor -= 1
        desiredColumn = nil
    }

    public mutating func deleteForward() {
        guard cursor < characters.count else { return }
        characters.remove(at: cursor)
        desiredColumn = nil
    }

    /// ⌃W — delete the word before the cursor.
    public mutating func deleteWordBack() {
        let target = wordStart(before: cursor)
        characters.removeSubrange(target..<cursor)
        cursor = target
        desiredColumn = nil
    }

    /// ⌃U — delete from the start of the line to the cursor.
    public mutating func deleteToLineStart() {
        let target = lineStart(of: cursor)
        characters.removeSubrange(target..<cursor)
        cursor = target
        desiredColumn = nil
    }

    // MARK: - Movement

    public mutating func moveLeft() { cursor = max(cursor - 1, 0); desiredColumn = nil }
    public mutating func moveRight() { cursor = min(cursor + 1, characters.count); desiredColumn = nil }
    public mutating func moveToLineStart() { cursor = lineStart(of: cursor); desiredColumn = nil }
    public mutating func moveToLineEnd() { cursor = lineEnd(of: cursor); desiredColumn = nil }
    public mutating func moveWordLeft() { cursor = wordStart(before: cursor); desiredColumn = nil }

    public mutating func moveWordRight() {
        var i = cursor
        while i < characters.count, characters[i].isWhitespace { i += 1 }
        while i < characters.count, !characters[i].isWhitespace { i += 1 }
        cursor = i
        desiredColumn = nil
    }

    public mutating func moveUp() {
        let start = lineStart(of: cursor)
        guard start > 0 else { cursor = 0; return }
        let column = desiredColumn ?? (cursor - start)
        let previousStart = lineStart(of: start - 1)
        cursor = previousStart + min(column, start - 1 - previousStart)
        desiredColumn = column
    }

    public mutating func moveDown() {
        let end = lineEnd(of: cursor)
        guard end < characters.count else { cursor = characters.count; return }
        let column = desiredColumn ?? (cursor - lineStart(of: cursor))
        let nextStart = end + 1
        cursor = nextStart + min(column, lineEnd(of: nextStart) - nextStart)
        desiredColumn = column
    }

    /// Applies an editing key. Returns false for keys the buffer doesn't
    /// handle (Enter on a single-line buffer, Esc, Tab, unknown ⌃ combos…),
    /// so the caller can treat them as commands.
    @discardableResult
    public mutating func apply(_ key: Key) -> Bool {
        switch key {
        case .char(let c): insert(String(c))
        case .paste(let text): insert(text)
        case .enter:
            guard multiline else { return false }
            newline()
        case .backspace: backspace()
        case .delete: deleteForward()
        case .left: moveLeft()
        case .right: moveRight()
        case .up:
            guard multiline else { return false }
            moveUp()
        case .down:
            guard multiline else { return false }
            moveDown()
        case .home, .ctrl("a"): moveToLineStart()
        case .end, .ctrl("e"): moveToLineEnd()
        case .wordLeft: moveWordLeft()
        case .wordRight: moveWordRight()
        case .ctrl("u"): deleteToLineStart()
        case .ctrl("w"): deleteWordBack()
        default: return false
        }
        return true
    }

    // MARK: - Helpers

    private func lineStart(of index: Int) -> Int {
        var i = index
        while i > 0, characters[i - 1] != "\n" { i -= 1 }
        return i
    }

    private func lineEnd(of index: Int) -> Int {
        var i = index
        while i < characters.count, characters[i] != "\n" { i += 1 }
        return i
    }

    private func wordStart(before index: Int) -> Int {
        var i = index
        while i > 0, characters[i - 1].isWhitespace { i -= 1 }
        while i > 0, !characters[i - 1].isWhitespace { i -= 1 }
        return i
    }

    private static func normalize(_ text: String, multiline: Bool) -> String {
        // Character-based: "\r\n" is one grapheme in Swift, so it must be
        // handled before splitting into separate CR/LF checks.
        var out = ""
        for character in text {
            if character == "\r\n" || character == "\r" || character == "\n" {
                out.append(multiline ? "\n" : " ")
            } else if character == "\t" {
                out.append(multiline ? "    " : " ")
            } else if character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
                continue
            } else {
                out.append(character)
            }
        }
        return out
    }
}
