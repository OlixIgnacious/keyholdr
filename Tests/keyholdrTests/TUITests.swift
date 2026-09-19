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

    @Test func kittyCSIuEncodings() {
        #expect(parse([0x1B, 0x5B, 0x39, 0x75]) == [.tab])                       // CSI 9 u
        #expect(parse([0x1B, 0x5B, 0x39, 0x3B, 0x32, 0x75]) == [.backTab])       // CSI 9;2 u  (shift)
        #expect(parse([0x1B, 0x5B, 0x31, 0x33, 0x75]) == [.enter])                // CSI 13 u
        #expect(parse([0x1B, 0x5B, 0x32, 0x37, 0x75]) == [.escape])               // CSI 27 u
        #expect(parse([0x1B, 0x5B, 0x31, 0x32, 0x37, 0x75]) == [.backspace])      // CSI 127 u
        #expect(parse(Array("\u{1B}[104u".utf8)) == [.char("h")])
        #expect(parse(Array("\u{1B}[104;2u".utf8)) == [.char("H")])              // shift + h
        #expect(parse(Array("\u{1B}[49:33;2u".utf8)) == [.char("!")])            // shift + 1 with the shifted key
        #expect(parse(Array("\u{1B}[110;5u".utf8)) == [.ctrl("n")])              // ctrl + n
        #expect(parse(Array("\u{1B}[110;3u".utf8)).isEmpty)                      // alt + n is ignored
        #expect(parse(Array("\u{1B}[27;5;9~".utf8)) == [.tab])                   // modifyOtherKeys
        #expect(parse(Array("\u{1B}[104;1:3u".utf8)) == [.char("h")])            // event-type suffix
    }

    @Test func loneEscapeNeedsAFlush() {
        var parser = KeyParser()
        let result1 = parser.feed([0x1B])
        #expect(result1.isEmpty)
        #expect(parser.hasPendingEscape)
        let result2 = parser.flush()
        #expect(result2 == [.escape])
        #expect(!parser.hasPendingEscape)
    }

    @Test func sequencesSplitAcrossReadsAreReassembled() {
        var parser = KeyParser()
        let result3 = parser.feed([0x1B])
        #expect(result3.isEmpty)
        let result4 = parser.feed([0x5B])
        #expect(result4.isEmpty)
        let result5 = parser.feed([0x41])
        #expect(result5 == [.up])
    }

    @Test func utf8CharactersAndSplitBytes() {
        #expect(parse(Array("é✓".utf8)) == [.char("é"), .char("✓")])
        var parser = KeyParser()
        let bytes = Array("✓".utf8)
        let result6 = parser.feed(Array(bytes[0..<2]))
        #expect(result6.isEmpty)
        let result7 = parser.feed(Array(bytes[2...]))
        #expect(result7 == [.char("✓")])
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
        let result8 = parser.feed(start + Array("abc".utf8))
        #expect(result8.isEmpty)
        let result9 = parser.feed(Array("def".utf8) + Array(end[0..<3]))
        #expect(result9.isEmpty)
        let result10 = parser.feed(Array(end[3...]) + [0x0D])
        #expect(result10 == [.paste("abcdef"), .enter])
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
        let result11 = buffer.apply(.enter)
        #expect(!result11)
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
        let result12 = buffer.apply(.escape)
        #expect(!result12)
        let result13 = buffer.apply(.ctrl("n"))
        #expect(!result13)
    }

    @Test func controlCharactersAreDropped() {
        var buffer = TextBuffer()
        buffer.insert("a\u{07}b")
        #expect(buffer.string == "ab")
    }
}
