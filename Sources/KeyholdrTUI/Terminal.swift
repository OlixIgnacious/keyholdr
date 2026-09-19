import Darwin
import Foundation

public struct TerminalSize: Equatable, Sendable {
    public var columns: Int
    public var rows: Int
    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }
}

public enum TerminalEvent: Equatable, Sendable {
    case key(Key)
    case resize
    /// The poll timed out with no input — a chance to expire toasts, etc.
    case tick
    /// SIGINT / SIGTERM / SIGHUP arrived; unwind and restore the terminal.
    case terminate
    /// stdin closed.
    case eof
}

// Signal handlers can't capture context, so they flag globals that the event
// loop polls. Only ever written from handlers and cleared from the loop.
nonisolated(unsafe) private var resizeFlag: Int32 = 0
nonisolated(unsafe) private var terminateFlag: Int32 = 0

/// Owns the terminal for a full-screen UI: raw input, the alternate screen,
/// a hidden cursor and bracketed paste, all restored on every way out.
/// Draws on stderr and reads from stdin, like the inline picker, so stdout
/// stays clean for anything piped from it.
public final class Terminal: @unchecked Sendable {
    public static let minimumSize = TerminalSize(columns: 60, rows: 16)

    /// A full-screen UI needs a human on both ends and a terminal that
    /// understands cursor addressing.
    public static var isSupported: Bool {
        guard isatty(STDIN_FILENO) != 0, isatty(STDERR_FILENO) != 0 else { return false }
        let term = ProcessInfo.processInfo.environment["TERM"] ?? ""
        return !term.isEmpty && term != "dumb"
    }

    private var original = termios()
    private var started = false
    private var parser = KeyParser()
    private var queue: [Key] = []

    public init() {}

    deinit { stop() }

    // MARK: - Lifecycle

    public func start() {
        guard !started else { return }
        started = true

        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        // No echo or line buffering; ISIG off so ^C arrives as a byte and we
        // can restore the terminal ourselves; IXON/IEXTEN off so ^S ^Q ^V pass.
        raw.c_lflag &= ~UInt(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~UInt(IXON)
        // TCSANOW, not TCSAFLUSH: keep keys typed before raw mode engaged.
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)

        installHandler(for: SIGWINCH) { _ in resizeFlag = 1 }
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            installHandler(for: sig) { _ in terminateFlag = 1 }
        }

        // Alternate screen (nothing lands in scrollback), hidden cursor, bracketed paste.
        // Autowrap off, so filling the bottom-right cell can never scroll the screen.
        write("\u{1B}[?1049h\u{1B}[?25l\u{1B}[?2004h\u{1B}[?7l\u{1B}[2J")
    }

    /// Idempotent; safe to call from `defer`.
    public func stop() {
        guard started else { return }
        started = false
        write("\u{1B}[?7h\u{1B}[?2004l\u{1B}[?25h\u{1B}[0m\u{1B}[?1049l")
        tcsetattr(STDIN_FILENO, TCSANOW, &original)
        for sig in [SIGWINCH, SIGINT, SIGTERM, SIGHUP] { signal(sig, SIG_DFL) }
    }

    // MARK: - Size & output

    public var size: TerminalSize {
        var ws = winsize()
        if ioctl(STDERR_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0, ws.ws_row > 0 {
            return TerminalSize(columns: Int(ws.ws_col), rows: Int(ws.ws_row))
        }
        return TerminalSize(columns: 80, rows: 24)
    }

    /// One write per frame keeps redraws flicker-free.
    public func write(_ string: String) {
        let bytes = Array(string.utf8)
        var offset = 0
        while offset < bytes.count {
            let written = bytes[offset...].withUnsafeBytes { Darwin.write(STDERR_FILENO, $0.baseAddress, $0.count) }
            if written <= 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                return
            }
            offset += written
        }
    }

    // MARK: - Input

    /// Waits up to `timeoutMs` for the next event.
    public func nextEvent(timeoutMs: Int = 100) -> TerminalEvent {
        if terminateFlag != 0 { return .terminate }
        if resizeFlag != 0 { resizeFlag = 0; return .resize }
        if !queue.isEmpty { return .key(queue.removeFirst()) }

        var fd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        let ready = poll(&fd, 1, Int32(timeoutMs))
        if ready < 0 {
            // A signal interrupted the wait; surface it on the next call.
            return terminateFlag != 0 ? .terminate : (resizeFlag != 0 ? .resize : .tick)
        }
        if ready == 0 { return .tick }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = read(STDIN_FILENO, &buffer, buffer.count)
        if count <= 0 { return count == 0 ? .eof : .tick }

        queue.append(contentsOf: parser.feed(Array(buffer[0..<count])))
        if parser.hasPendingEscape {
            // A lone ESC is the Escape key unless the rest of a sequence
            // follows within a few ms.
            var again = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            if poll(&again, 1, 25) == 0 { queue.append(contentsOf: parser.flush()) }
        }
        return queue.isEmpty ? .tick : .key(queue.removeFirst())
    }

    // MARK: - Helpers

    private func installHandler(for signalNumber: Int32, _ handler: @escaping @convention(c) (Int32) -> Void) {
        var action = sigaction()
        action.__sigaction_u.__sa_handler = handler
        sigemptyset(&action.sa_mask)
        action.sa_flags = 0 // no SA_RESTART: let poll() return so the loop notices
        sigaction(signalNumber, &action, nil)
    }
}
