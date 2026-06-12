import SwiftUI
import KeyholdrKit

/// What the vault transfer form is collecting a passphrase for.
enum TransferMode: Equatable {
    case exportAll
    case importFile(URL)
}

/// Passphrase prompt shown before exporting or importing the vault.
struct TransferView: View {
    let mode: TransferMode
    var errorText: String?
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var passphrase = ""
    @State private var confirmPassphrase = ""

    private var isExport: Bool {
        mode == .exportAll
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(isExport ? "Export Vault" : "Import Vault")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KHTheme.ink)
                Spacer()
                Button(action: { onCancel() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(KHTheme.ink60)
                        .frame(width: 24, height: 24)
                        .background(KHTheme.ink06)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            Text(isExport
                 ? "Every key and its secret is sealed into a single file, encrypted with the passphrase below. Anyone with the file and the passphrase can read your keys — store both carefully."
                 : "Enter the passphrase this vault file was exported with. Keys you already have are left untouched.")
                .font(.system(size: 12))
                .foregroundColor(KHTheme.ink60)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                field(label: "PASSPHRASE") {
                    SecureField(isExport ? "At least \(VaultExport.minimumPassphraseLength) characters" : "Passphrase", text: $passphrase)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }

                if isExport {
                    field(label: "CONFIRM PASSPHRASE") {
                        SecureField("Repeat passphrase", text: $confirmPassphrase)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                }
            }

            if let errorText {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text(errorText)
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: { onCancel() }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHTheme.ink60)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .overlay(
                            Capsule().strokeBorder(KHTheme.ink12, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { onConfirm(passphrase) }) {
                    Text(isExport ? "Choose location…" : "Import keys")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHTheme.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(KHTheme.ink.opacity(isConfirmDisabled ? 0.3 : 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isConfirmDisabled)
            }
        }
        .padding(18)
        .frame(width: 360, height: 440)
        .background(KHTheme.paper)
    }

    private var isConfirmDisabled: Bool {
        if isExport {
            return passphrase.count < VaultExport.minimumPassphraseLength || passphrase != confirmPassphrase
        }
        return passphrase.isEmpty
    }

    @ViewBuilder
    private func field(label labelText: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(labelText)
                .font(.khMonoLabel)
                .tracking(0.8)
                .foregroundColor(KHTheme.ink40)

            content()
                .foregroundColor(KHTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(KHTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(KHTheme.ink12, lineWidth: 1)
                )
        }
    }
}
