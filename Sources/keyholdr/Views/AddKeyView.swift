import SwiftUI
import KeyholdrKit
import AppKit

struct AddKeyView: View {
    var onSave: (KeyItem, String) -> Void
    var onCancel: () -> Void

    var editingItem: KeyItem? = nil
    var existingSecret: String? = nil

    @State private var platform = ""
    @State private var label = ""
    @State private var secret = ""
    @State private var tagsText = ""
    @State private var showSecret = false

    @FocusState private var isSecretFocused: Bool

    init(editingItem: KeyItem? = nil, existingSecret: String? = nil, onSave: @escaping (KeyItem, String) -> Void, onCancel: @escaping () -> Void) {
        self.editingItem = editingItem
        self.existingSecret = existingSecret
        self.onSave = onSave
        self.onCancel = onCancel

        _platform = State(initialValue: editingItem?.platform ?? "")
        _label = State(initialValue: editingItem?.label ?? "")
        _secret = State(initialValue: existingSecret ?? "")
        _tagsText = State(initialValue: editingItem?.tags.joined(separator: ", ") ?? "")
        _showSecret = State(initialValue: editingItem == nil)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(editingItem == nil ? "New Key" : "Edit Key")
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

            // Input Fields
            VStack(spacing: 14) {
                field(label: "PLATFORM") {
                    TextField("e.g. GitHub, OpenAI, AWS", text: $platform)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .textContentType(.none)
                        .autocorrectionDisabled(true)
                }

                field(label: "LABEL") {
                    TextField("e.g. personal, work", text: $label)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .textContentType(.none)
                        .autocorrectionDisabled(true)
                }

                field(label: "SECRET VALUE") {
                    HStack(spacing: 6) {
                        TextField("Enter token or key value", text: $secret)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .textContentType(.oneTimeCode) // Force macOS Smart Autofill to treat this as OTP, preventing password autofill popups
                            .autocorrectionDisabled(true)
                            .focused($isSecretFocused)
                            .overlay(
                                Group {
                                    if !showSecret {
                                        HStack {
                                            Text(secret.isEmpty ? "Click to enter key" : "••••••••••••")
                                                .font(.system(size: secret.isEmpty ? 13 : 11, design: secret.isEmpty ? .default : .monospaced))
                                                .foregroundColor(secret.isEmpty ? KHTheme.ink40 : KHTheme.ink)
                                            Spacer()
                                        }
                                        .background(KHTheme.field)
                                        .background(KHTheme.paper)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            showSecret = true
                                            isSecretFocused = true
                                        }
                                    }
                                }
                            )

                        Button(action: {
                            showSecret.toggle()
                            if showSecret {
                                isSecretFocused = true
                            }
                        }) {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .font(.system(size: 11))
                                .foregroundColor(KHTheme.ink60)
                        }
                        .buttonStyle(.plain)
                    }
                }

                field(label: "TAGS · COMMA SEPARATED") {
                    TextField("e.g. dev, api, production", text: $tagsText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
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
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: { saveItem() }) {
                    Text(editingItem == nil ? "Save to vault" : "Save changes")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHTheme.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(KHTheme.ink.opacity(isSaveDisabled ? 0.3 : 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
            }
        }
        .padding(18)
        .frame(width: 360, height: 440)
        .background(KHTheme.paper)
    }

    private var isSaveDisabled: Bool {
        platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func saveItem() {
        let cleanedPlatform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsList = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // The rotation age only resets when the secret value itself changes.
        let secretChanged = editingItem == nil || cleanedSecret != existingSecret
        let item = KeyItem(
            id: editingItem?.id ?? UUID(),
            platform: cleanedPlatform,
            label: cleanedLabel.isEmpty ? "default" : cleanedLabel,
            tags: tagsList,
            dateCreated: editingItem?.dateCreated ?? Date(),
            secretUpdatedAt: secretChanged ? Date() : editingItem?.secretUpdatedAt
        )

        onSave(item, cleanedSecret)
    }
}
