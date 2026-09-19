import Foundation

/// A decoded keypress.
public enum Key: Equatable, Sendable {
    case char(Character)
    case enter, tab, backTab, escape, backspace, delete
    case up, down, left, right, home, end, pageUp, pageDown
    /// Option/Ctrl + ←/→ — jump by word.
    case wordLeft, wordRight
    /// ⌃ + a letter, lowercased ("c" for ^C). Tab, Enter and Backspace keep their own cases.
    case ctrl(Character)
    /// A bracketed paste, delivered as a single event so pasted newlines
    /// never fire Enter.
    case paste(String)
}

/// Turns raw tty bytes into `Key`s. Pure and stateful only to carry a partial
/// escape sequence, UTF-8 character or paste across reads, so it can be
/// tested without a terminal.
public struct KeyParser: Sendable {
    private var pending: [UInt8] = []
    private var paste: [UInt8]?

    private static let pasteEnd: [UInt8] = [0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E] // ESC [ 201 ~

    public init() {}

    /// True when the only thing buffered is a lone ESC — which is either the
    /// Escape key or the start of a sequence whose remaining bytes haven't
    /// arrived yet. The caller waits briefly, then calls `flush()`.
    public var hasPendingEscape: Bool { pending == [0x1B] }

    /// Resolves whatever is still buffered once no more input is coming.
    public mutating func flush() -> [Key] {
        defer { pending = [] }
        return pending == [0x1B] ? [.escape] : []
    }

    public mutating func feed(_ bytes: [UInt8]) -> [Key] {
        var input = pending + bytes
        pending = []
        var keys: [Key] = []
        var i = 0

        while i < input.count {
            if paste != nil {
                if let end = Self.find(Self.pasteEnd, in: input, from: i) {
                    paste!.append(contentsOf: input[i..<end])
                    keys.append(.paste(String(decoding: paste!, as: UTF8.self)))
                    paste = nil
                    i = end + Self.pasteEnd.count
                } else {
                    // Hold back a possible half-arrived end marker.
                    let keep = Self.partialSuffix(of: Self.pasteEnd, in: input, from: i)
                    paste!.append(contentsOf: input[i..<(input.count - keep)])
                    pending = Array(input[(input.count - keep)...])
                    return keys
                }
                continue
            }

            let byte = input[i]
            switch byte {
            case 0x1B:
                switch parseEscape(input, at: i) {
                case .incomplete:
                    pending = Array(input[i...])
                    return keys
                case .consumed(let count, let key):
                    if let key { keys.append(key) }
                    i += count
                }
            case 0x0D, 0x0A: keys.append(.enter); i += 1
            case 0x09: keys.append(.tab); i += 1
            case 0x7F, 0x08: keys.append(.backspace); i += 1
            case 0x01...0x1A:
                keys.append(.ctrl(Character(UnicodeScalar(byte + 0x60))))
                i += 1
            case 0x20...0x7E:
                keys.append(.char(Character(UnicodeScalar(byte))))
                i += 1
            case 0xC2...0xF4:
                let length = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : 2
                if i + length > input.count {
                    pending = Array(input[i...])
                    return keys
                }
                let text = String(decoding: input[i..<(i + length)], as: UTF8.self)
                keys.append(contentsOf: text.map { .char($0) })
                i += length
            default:
                i += 1 // NUL, stray continuation bytes, C1 controls
            }
        }
        input.removeAll()
        return keys
    }

    // MARK: - Escape sequences

    private enum Escape {
        case incomplete
        case consumed(Int, Key?)
    }

    private mutating func parseEscape(_ input: [UInt8], at i: Int) -> Escape {
        guard i + 1 < input.count else { return .incomplete }
        let next = input[i + 1]

        switch next {
        case 0x5B: // CSI: ESC [ params final
            var j = i + 2
            while j < input.count, !(0x40...0x7E).contains(input[j]) { j += 1 }
            guard j < input.count else { return .incomplete }
            let params = String(decoding: input[(i + 2)..<j], as: UTF8.self)
            let final = input[j]
            let consumed = j - i + 1
            let hasModifier = params.contains(";")

            switch final {
            case 0x41: return .consumed(consumed, .up)
            case 0x42: return .consumed(consumed, .down)
            case 0x43: return .consumed(consumed, hasModifier ? .wordRight : .right)
            case 0x44: return .consumed(consumed, hasModifier ? .wordLeft : .left)
            case 0x48: return .consumed(consumed, .home)
            case 0x46: return .consumed(consumed, .end)
            case 0x5A: return .consumed(consumed, .backTab)
            case 0x7E:
                switch params.split(separator: ";").first.flatMap({ Int($0) }) {
                case 1, 7: return .consumed(consumed, .home)
                case 4, 8: return .consumed(consumed, .end)
                case 3: return .consumed(consumed, .delete)
                case 5: return .consumed(consumed, .pageUp)
                case 6: return .consumed(consumed, .pageDown)
                case 200:
                    paste = []
                    return .consumed(consumed, nil)
                default: return .consumed(consumed, nil)
                }
            default: return .consumed(consumed, nil)
            }

        case 0x4F: // SS3: ESC O x (application-mode arrows)
            guard i + 2 < input.count else { return .incomplete }
            let key: Key?
            switch input[i + 2] {
            case 0x41: key = .up
            case 0x42: key = .down
            case 0x43: key = .right
            case 0x44: key = .left
            case 0x48: key = .home
            case 0x46: key = .end
            default: key = nil
            }
            return .consumed(3, key)

        case 0x1B: // ESC ESC — the first is a real Escape press
            return .consumed(1, .escape)

        case 0x62: return .consumed(2, .wordLeft)   // ESC b (Option-←)
        case 0x66: return .consumed(2, .wordRight)  // ESC f (Option-→)
        default:
            return .consumed(2, nil) // other Alt-combos are ignored
        }
    }

    // MARK: - Helpers

    private static func find(_ needle: [UInt8], in haystack: [UInt8], from start: Int) -> Int? {
        guard haystack.count - start >= needle.count else { return nil }
        var i = start
        while i <= haystack.count - needle.count {
            if haystack[i] == needle[0], Array(haystack[i..<(i + needle.count)]) == needle { return i }
            i += 1
        }
        return nil
    }

    /// Length of the longest tail of `input[from...]` that is a proper prefix of `marker`.
    private static func partialSuffix(of marker: [UInt8], in input: [UInt8], from: Int) -> Int {
        let available = input.count - from
        var length = min(marker.count - 1, available)
        while length > 0 {
            if Array(input[(input.count - length)...]) == Array(marker[..<length]) { return length }
            length -= 1
        }
        return 0
    }
}
