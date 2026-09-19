import Testing
import Foundation
@testable import KeyholdrTUI

@Suite struct KeyParserTests {
    private func parse(_ bytes: [UInt8]) -> [Key] {
        var parser = KeyParser()
        return parser.feed(bytes)
    }

    @Test func printableAndControlKeys() {
        #expect(parse(Array("ab ".utf8)) == [.char("a"), .char("b"), .char(" ")])
        #expect(parse([0x0D]) == [.enter])
        #expect(parse([0x0A]) == [.enter])
        #expect(parse([0x09]) == [.tab])
        #expect(parse([0x7F]) == [.backspace])
        #expect(parse([0x0E]) == [.ctrl("n")])
        #expect(parse([0x18]) == [.ctrl("x")])
        #expect(parse([0x03]) == [.ctrl("c")])
    }

    @Test func arrowsAndNavigation() {
        #expect(parse([0x1B, 0x5B, 0x41]) == [.up])
        #expect(parse([0x1B, 0x5B, 0x42]) == [.down])
        #expect(parse([0x1B, 0x5B, 0x43]) == [.right])
        #expect(parse([0x1B, 0x5B, 0x44]) == [.left])
        #expect(parse([0x1B, 0x4F, 0x41]) == [.up]) // application mode
        #expect(parse([0x1B, 0x5B, 0x5A]) == [.backTab])
        #expect(parse([0x1B, 0x5B, 0x33, 0x7E]) == [.delete])
        #expect(parse([0x1B, 0x5B, 0x35, 0x7E]) == [.pageUp])
        #expect(parse([0x1B, 0x5B, 0x36, 0x7E]) == [.pageDown])
        #expect(parse([0x1B, 0x5B, 0x48]) == [.home])
        #expect(parse([0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x43]) == [.wordRight]) // ⌃→
        #expect(parse([0x1B, 0x62]) == [.wordLeft])                          // ESC b
    }

    @Test func loneEscapeNeedsAFlush() {
        var parser = KeyParser()
        #expect(parser.feed([0x1B]).isEmpty)
        #expect(parser.hasPendingEscape)
        #expect(parser.flush() == [.escape])
        #expect(!parser.hasPendingEscape)
    }

    @Test func sequencesSplitAcrossReadsAreReassembled() {
        var parser = KeyParser()
        #expect(parser.feed([0x1B]).isEmpty)
        #expect(parser.feed([0x5B]).isEmpty)
        #expect(parser.feed([0x41]) == [.up])
    }

    @Test func utf8CharactersAndSplitBytes() {
        #expect(parse(Array("é✓".utf8)) == [.char("é"), .char("✓")])
        var parser = KeyParser()
        let bytes = Array("✓".utf8)
        #expect(parser.feed(Array(bytes[0..<2])).isEmpty)
        #expect(parser.feed(Array(bytes[2...])) == [.char("✓")])
    }

    @Test func bracketedPasteArrivesAsOneEventWithNewlines() {
        let start: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
        let end: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]
        let body = Array("line one\nline two\r\nq".utf8)
        #expect(parse(start + body + end) == [.paste("line one\nline two\r\nq")])
        // Keys after the paste still parse.
        #expect(parse(start + body + end + [0x0D]) == [.paste("line one\nline two\r\nq"), .enter])
    }

    @Test func pasteSplitAcrossReadsIncludingTheEndMarker() {
        let start: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E]
        let end: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E]
        var parser = KeyParser()
        #expect(parser.feed(start + Array("abc".utf8)).isEmpty)
        #expect(parser.feed(Array("def".utf8) + Array(end[0..<3])).isEmpty)
        #expect(parser.feed(Array(end[3...]) + [0x0D]) == [.paste("abcdef"), .enter])
    }
}

@Suite struct TextTests {
    @Test func widths() {
        #expect(Text.width("abc") == 3)
        #expect(Text.width("日本") == 4)
        #expect(Text.width("e\u{301}") == 1) // combining accent
        #expect(Text.width("\u{1B}[1;31mred\u{1B}[0m") == 3) // ANSI ignored
    }

    @Test func truncateAndFit() {
        #expect(Text.truncate("hello world", to: 8) == "hello w…")
        #expect(Text.truncate("hi", to: 8) == "hi")
        #expect(Text.truncate("日本語テキスト", to: 7) == "日本語…")
        #expect(Text.fit("ab", to: 5) == "ab   ")
        #expect(Text.width(Text.fit("日本語テキスト", to: 9)) == 9)
        #expect(Text.padLeft("7", to: 3) == "  7")
    }

    @Test func wrapKeepsNewlines() {
        #expect(Text.wrap("abcdef\ngh", to: 4) == ["abcd", "ef", "gh"])
        #expect(Text.wrap("", to: 4) == [""])
    }
}

@Suite struct TextBufferTests {
    @Test func insertBackspaceAndCursor() {
        var buffer = TextBuffer()
        buffer.insert("hello")
        buffer.moveLeft()
        buffer.insert("X")
        #expect(buffer.string == "hellXo")
        buffer.backspace()
        buffer.backspace()
        #expect(buffer.string == "helo")
        buffer.moveToLineStart()
        buffer.deleteForward()
        #expect(buffer.string == "elo")
    }

    @Test func singleLineFlattensPastedNewlines() {
        var buffer = TextBuffer()
        buffer.insert("a\nb\r\nc")
        #expect(buffer.string == "a b c")
        #expect(!buffer.apply(.enter))
    }

    @Test func multilineNavigationKeepsDesiredColumn() {
        var buffer = TextBuffer("abcdef\nab\nabcdef", multiline: true)
        #expect(buffer.lines.count == 3)
        buffer.moveToLineStart()
        buffer.moveRight(); buffer.moveRight(); buffer.moveRight(); buffer.moveRight()
        #expect(buffer.position.line == 2 && buffer.position.column == 4)
        buffer.moveUp()
        #expect(buffer.position.line == 1 && buffer.position.column == 2) // clamped
        buffer.moveUp()
        #expect(buffer.position.line == 0 && buffer.position.column == 4) // remembered
        buffer.moveDown(); buffer.moveDown()
        #expect(buffer.position.line == 2 && buffer.position.column == 4)
    }

    @Test func wordAndLineDeletes() {
        var buffer = TextBuffer("one two three")
        buffer.deleteWordBack()
        #expect(buffer.string == "one two ")
        buffer.moveWordLeft()
        #expect(buffer.position.column == 4)
        buffer.deleteToLineStart()
        #expect(buffer.string == "two ")
    }

    @Test func applyRoutesKeys() {
        var buffer = TextBuffer(multiline: true)
        buffer.apply(.char("h"))
        buffer.apply(.char("i"))
        buffer.apply(.enter)
        buffer.apply(.paste("x\ny"))
        #expect(buffer.string == "hi\nx\ny")
        #expect(!buffer.apply(.escape))
        #expect(!buffer.apply(.ctrl("n")))
    }

    @Test func controlCharactersAreDropped() {
        var buffer = TextBuffer()
        buffer.insert("a\u{07}b")
        #expect(buffer.string == "ab")
    }
}
