import SwiftUI
import AppKit

@MainActor
struct KeyRowView: View {
    let item: KeyItem
    @ObservedObject var securityManager: SecurityManager

    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var revealedSecret: String? = nil
    @State private var isCopied = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Monogram tile
            Text(item.initials)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(KHTheme.paper)
                .frame(width: 32, height: 32)
                .background(KHTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Text details
            VStack(alignment: .leading, spacing: 3) {
                Text(item.platform)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KHTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(revealedSecret ?? subtitle)
                    .font(.khMonoSub)
                    .foregroundColor(revealedSecret != nil ? KHTheme.ink : KHTheme.ink40)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            // Hover-only secondary actions
            if isHovered {
                HStack(spacing: 2) {
                    iconButton(revealedSecret != nil ? "eye.slash" : "eye",
                               help: revealedSecret != nil ? "Hide key" : "Reveal key",
                               action: toggleReveal)
                    iconButton("pencil", help: "Edit details", action: onEdit)
                    iconButton("trash", help: "Delete key", action: onDelete)
                }
                .transition(.opacity)
            }

            // Primary copy action
            Button(action: copyToClipboard) {
                Text(isCopied ? "COPIED" : "COPY")
                    .font(.khMonoLabel)
                    .tracking(0.8)
                    .foregroundColor(isCopied || isHovered ? KHTheme.ink : KHTheme.ink40)
            }
            .buttonStyle(.plain)
            .help("Copy key")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(isHovered ? KHTheme.ink06 : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            // Hide the key automatically when hovering away from the row
            if !hovering && revealedSecret != nil {
                revealedSecret = nil
            }
        }
    }

    private var subtitle: String {
        "\(item.label) · ••••••••"
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(KHTheme.ink60)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toggleReveal() {
        if revealedSecret != nil {
            revealedSecret = nil
        } else {
            Task {
                let success = await securityManager.authenticate(reason: "reveal the secret for \(item.platform)")
                if success {
                    if let secret = KeychainHelper.retrieve(for: item.id) {
                        withAnimation {
                            self.revealedSecret = secret
                        }
                    }
                }
            }
        }
    }

    private func copyToClipboard() {
        Task {
            let success = await securityManager.authenticate(reason: "copy the secret for \(item.platform)")
            if success {
                if let secret = KeychainHelper.retrieve(for: item.id) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(secret, forType: .string)

                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        self.isCopied = true
                    }

                    try? await Task.sleep(nanoseconds: 2_000_000_000)

                    withAnimation {
                        self.isCopied = false
                    }
                }
            }
        }
    }
}
