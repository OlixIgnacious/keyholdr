import Foundation

/// Display-width helpers. Terminals lay text out in cells, not characters:
/// CJK and emoji take two, combining marks none. This is an approximation
/// (no full East Asian Width table), which is enough to keep columns aligned
/// for the text Keyholdr shows.
public enum Text {
    /// Cells a single character occupies.
    public static func width(of character: Character) -> Int {
        var wide = false
        var sawVisible = false
        for scalar in character.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .enclosingMark, .format, .control:
                continue
            default:
                sawVisible = true
                if isWide(scalar) { wide = true }
            }
        }
        return wide ? 2 : (sawVisible ? 1 : 0)
    }

    /// Cells a string occupies, ignoring ANSI escape sequences.
    public static func width(_ string: String) -> Int {
        var total = 0
        var inEscape = false
        for character in string {
            if inEscape {
                // CSI ends on a byte in @…~
                if let scalar = character.unicodeScalars.first, (0x40...0x7E).contains(scalar.value), character != "[" {
                    inEscape = false
                }
                continue
            }
            if character == "\u{1B}" { inEscape = true; continue }
            total += width(of: character)
        }
        return total
    }

    /// Cuts plain (unstyled) text to at most `columns` cells, ending in `…`
    /// when something was dropped.
    public static func truncate(_ string: String, to columns: Int, ellipsis: String = "…") -> String {
        guard columns > 0 else { return "" }
        if width(string) <= columns { return string }
        let budget = max(columns - width(ellipsis), 0)
        var out = ""
        var used = 0
        for character in string {
            let w = width(of: character)
            if used + w > budget { break }
            out.append(character)
            used += w
        }
        return out + (columns >= width(ellipsis) ? ellipsis : "")
    }

    /// Pads with spaces on the right up to `columns` cells (never truncates).
    public static func pad(_ string: String, to columns: Int) -> String {
        let missing = columns - width(string)
        return missing > 0 ? string + String(repeating: " ", count: missing) : string
    }

    /// Truncate then pad: exactly `columns` cells wide.
    public static func fit(_ string: String, to columns: Int) -> String {
        pad(truncate(string, to: columns), to: columns)
    }

    /// Right-aligns within `columns` cells.
    public static func padLeft(_ string: String, to columns: Int) -> String {
        let missing = columns - width(string)
        return missing > 0 ? String(repeating: " ", count: missing) + string : string
    }

    /// Word-wraps plain text to `columns`, keeping explicit newlines.
    public static func wrap(_ string: String, to columns: Int) -> [String] {
        guard columns > 0 else { return [] }
        var lines: [String] = []
        for paragraph in string.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = ""
            var used = 0
            for character in paragraph {
                let w = width(of: character)
                if used + w > columns {
                    lines.append(line)
                    line = ""
                    used = 0
                }
                line.append(character)
                used += w
            }
            lines.append(line)
        }
        return lines
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF,
             0xFE30...0xFE6F, 0xFF00...0xFF60, 0xFFE0...0xFFE6,
             0x1F300...0x1F64F, 0x1F900...0x1F9FF, 0x20000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}
