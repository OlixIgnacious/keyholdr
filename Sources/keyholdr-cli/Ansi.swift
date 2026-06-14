import Darwin
import Foundation

/// Minimal ANSI styling for terminal output. Colors are skipped when stderr
/// isn't a tty (piped/redirected output stays plain), or when NO_COLOR is set.
enum Ansi {
    static let enabled = isatty(STDERR_FILENO) != 0 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil

    static let reset = "\u{1B}[0m"
    static let dim = "\u{1B}[2m"
    static let bold = "\u{1B}[1m"

    /// Claude's warm terracotta accent.
    static let accent = "\u{1B}[38;2;215;119;87m"
    static let accentBg = "\u{1B}[48;2;215;119;87m"
    static let dark = "\u{1B}[38;2;38;38;38m"
    static let green = "\u{1B}[38;5;108m"
    static let red = "\u{1B}[38;5;167m"

    static func style(_ s: String, _ codes: String...) -> String {
        guard enabled, !s.isEmpty else { return s }
        return codes.joined() + s + reset
    }
}
