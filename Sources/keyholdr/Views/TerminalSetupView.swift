import SwiftUI
import AppKit

/// Terminal guidance for the sandboxed Mac App Store build. The sandbox limits
/// the command-line tool bundled in this build (it can't link itself onto the
/// PATH, and it can't drive an interactive terminal UI), so terminal users are
/// pointed at the Homebrew / direct-download build instead.
struct TerminalSetupView: View {
    private static let command = "brew install --cask olixignacious/tap/keyholdr"
    private static let releasesURL = URL(string: "https://github.com/OlixIgnacious/keyholdr/releases/latest")!

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terminal Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KHTheme.ink)

            Text("The App Store build is sandboxed, which limits its command-line tool. For the terminal — including the full-screen keyholdr UI — install the Homebrew or direct-download build:")
                .font(.system(size: 11))
                .foregroundColor(KHTheme.ink60)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(KHTheme.ink)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KHTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)

            Button(action: copy) {
                Text(copied ? "Copied ✓" : "Copy Command")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KHTheme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(KHTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Link("Or download it from GitHub Releases", destination: Self.releasesURL)
                .font(.system(size: 11))
                .foregroundColor(KHTheme.ink60)

            Text("Then run `keyholdr` in Terminal.")
                .font(.system(size: 10))
                .foregroundColor(KHTheme.ink40)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.command, forType: .string)
        copied = true
    }
}
