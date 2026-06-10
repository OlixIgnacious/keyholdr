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
            // Platform Icon with color-coded background
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.symbolColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: item.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(item.symbolColor)
            }
            
            // Text Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.platform)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // Simple Tag Badges (if any)
                    ForEach(item.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(item.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Dynamic Right-side Content (Masked Secret vs Action Buttons)
            HStack(spacing: 8) {
                if let revealed = revealedSecret {
                    Text(revealed)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                } else if !isHovered && !isCopied {
                    Text("••••••••")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                }
                
                if isHovered || revealedSecret != nil || isCopied {
                    HStack(spacing: 4) {
                        // Reveal Button
                        Button(action: toggleReveal) {
                            Image(systemName: revealedSecret != nil ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(isHovered ? 0.06 : 0))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help(revealedSecret != nil ? "Hide key" : "Reveal key")
                        
                        // Copy Button
                        Button(action: copyToClipboard) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(isCopied ? .green : .secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(isHovered ? 0.06 : 0))
                                .cornerRadius(4)
                                .scaleEffect(isCopied ? 1.15 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help("Copy key")
                        
                        // Edit Button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(isHovered ? 0.06 : 0))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Edit details")
                        
                        // Delete Button
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(isHovered ? 0.06 : 0))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Delete key")
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
            // Hide the key automatically when hovering away from the row
            if !hovering && revealedSecret != nil {
                revealedSecret = nil
            }
        }
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
