import SwiftUI
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
                Text(editingItem == nil ? "Add Secure Key" : "Edit Key")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { onCancel() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            // Input Fields
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Platform Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. GitHub, OpenAI, AWS", text: $platform)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                        .autocorrectionDisabled(true)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reference Label")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. personal, work", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                        .autocorrectionDisabled(true)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        TextField("Enter token or key value", text: $secret)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.oneTimeCode) // Force macOS Smart Autofill to treat this as OTP, preventing password autofill popups
                            .autocorrectionDisabled(true)
                            .focused($isSecretFocused)
                            .overlay(
                                Group {
                                    if !showSecret {
                                        HStack {
                                            Text(secret.isEmpty ? "Click to enter key" : "••••••••••••")
                                                .font(.system(secret.isEmpty ? .body : .caption, design: secret.isEmpty ? .default : .monospaced))
                                                .foregroundColor(secret.isEmpty ? .secondary : .primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .background(Color(NSColor.controlBackgroundColor))
                                        .cornerRadius(3)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            showSecret = true
                                            isSecretFocused = true
                                        }
                                    }
                                }
                                .padding(1)
                            )
                        
                        Button(action: {
                            showSecret.toggle()
                            if showSecret {
                                isSecretFocused = true
                            }
                        }) {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags (comma separated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. dev, api, production", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer().frame(height: 8)
            
            // Action Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(editingItem == nil ? "Add Key" : "Save Changes") {
                    saveItem()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
    
    private func saveItem() {
        let cleanedPlatform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsList = tagsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let item = KeyItem(
            id: editingItem?.id ?? UUID(),
            platform: cleanedPlatform,
            label: cleanedLabel.isEmpty ? "default" : cleanedLabel,
            tags: tagsList,
            dateCreated: editingItem?.dateCreated ?? Date()
        )
        
        onSave(item, cleanedSecret)
    }
}
