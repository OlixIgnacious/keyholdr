import SwiftUI
import AppKit

/// Manual CLI linking instructions for the sandboxed Mac App Store build,
/// which can't write to ~/.local/bin or patch a shell profile on its own the
/// way the direct-distribution build's CLIInstaller does.
struct TerminalSetupView: View {
    private static let command = #"""
    mkdir -p ~/.local/bin
    ln -sf "/Applications/Keyholdr.app/Contents/MacOS/keyholdr-cli" ~/.local/bin/keyholdr
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    """#

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terminal Setup")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KHTheme.ink)

            Text("The App Store build is sandboxed, so it can't link the CLI onto your PATH automatically. Paste this into Terminal once:")
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

            Text("Restart Terminal (or run `source ~/.zshrc`) afterward, then `keyholdr` is on your PATH.")
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
