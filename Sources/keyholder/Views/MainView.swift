import SwiftUI

@MainActor
struct MainView: View {
    @StateObject private var securityManager = SecurityManager()
    @State private var keys: [KeyItem] = []

    @State private var searchText = ""
    @State private var selectedTag: String? = nil

    // Add/Edit view states
    @State private var showingAddSheet = false
    @State private var editingItem: KeyItem? = nil
    @State private var editingSecret: String? = nil

    // Delete states
    @State private var itemToDelete: KeyItem? = nil
    @State private var showingDeleteAlert = false

    var body: some View {
        ZStack {
            KHTheme.paper.ignoresSafeArea()

            if showingAddSheet {
                AddKeyView(
                    onSave: { newItem, secret in
                        saveNewKey(newItem, secret: secret)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showingAddSheet = false
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showingAddSheet = false
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else if let item = editingItem {
                AddKeyView(
                    editingItem: item,
                    existingSecret: editingSecret,
                    onSave: { updatedItem, secret in
                        saveUpdatedKey(updatedItem, secret: secret)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            editingItem = nil
                            editingSecret = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            editingItem = nil
                            editingSecret = nil
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                // Primary Key List Interface
                VStack(spacing: 0) {
                    // Search + Add
                    HStack(spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(KHTheme.ink40)

                            TextField("Search keys…", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(KHTheme.ink)

                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(KHTheme.ink40)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(KHTheme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(KHTheme.ink12, lineWidth: 1)
                        )

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showingAddSheet = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(KHTheme.paper)
                                .frame(width: 30, height: 30)
                                .background(KHTheme.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("n", modifiers: .command)
                        .help("Add new key (⌘N)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    // Tag filter pills
                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                TagPill(title: "ALL", isSelected: selectedTag == nil) {
                                    withAnimation(.easeOut(duration: 0.2)) { selectedTag = nil }
                                }

                                ForEach(allTags, id: \.self) { tag in
                                    TagPill(title: tag.uppercased(), isSelected: selectedTag == tag) {
                                        withAnimation(.easeOut(duration: 0.2)) { selectedTag = tag }
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                        .padding(.bottom, 10)
                    }

                    // Main Keys List
                    if filteredKeys.isEmpty {
                        VStack(spacing: 14) {
                            Spacer()
                            Image(systemName: searchText.isEmpty ? "key" : "magnifyingglass")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(KHTheme.ink40)

                            Text(searchText.isEmpty ? "No keys yet." : "No matching keys.")
                                .font(.system(size: 13))
                                .foregroundColor(KHTheme.ink60)

                            if searchText.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        showingAddSheet = true
                                    }
                                }) {
                                    Text("Add your first key")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(KHTheme.paper)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(KHTheme.ink)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredKeys) { item in
                                    KeyRowView(
                                        item: item,
                                        securityManager: securityManager,
                                        onEdit: {
                                            startEditing(item)
                                        },
                                        onDelete: {
                                            itemToDelete = item
                                            showingDeleteAlert = true
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .frame(maxHeight: .infinity)
                    }

                    // Footer
                    HStack {
                        Text("\(keys.count) \(keys.count == 1 ? "KEY" : "KEYS") · ⌘N TO ADD")
                            .font(.khMonoLabel)
                            .tracking(0.5)
                            .foregroundColor(KHTheme.ink40)

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: "lock")
                                .font(.system(size: 9, weight: .medium))
                            Text("LOCKED AT REST")
                                .font(.khMonoLabel)
                                .tracking(0.5)
                        }
                        .foregroundColor(KHTheme.ink40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(KHTheme.ink06)
                            .frame(height: 1)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
        }
        .frame(width: 360, height: 440)
        .onAppear {
            loadKeysData()
        }
        // Auto-lock session when status bar popup is dismissed/closed
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            securityManager.lock()
        }
        // Delete Confirmation Alert
        .alert("Delete Key?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    deleteKey(item)
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete the key for \(item.platform)? This will permanently erase the secret from your macOS Keychain.")
            } else {
                Text("This action cannot be undone.")
            }
        }
    }

    private func loadKeysData() {
        keys = StorageManager.loadKeys()
    }

    private func saveNewKey(_ item: KeyItem, secret: String) {
        KeychainHelper.save(secret: secret, for: item.id)
        keys.append(item)
        StorageManager.saveKeys(keys)
    }

    private func startEditing(_ item: KeyItem) {
        Task {
            let success = await securityManager.authenticate(reason: "edit the details for \(item.platform)")
            if success {
                self.editingSecret = KeychainHelper.retrieve(for: item.id) ?? ""
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    self.editingItem = item
                }
            }
        }
    }

    private func saveUpdatedKey(_ item: KeyItem, secret: String) {
        KeychainHelper.save(secret: secret, for: item.id)
        if let idx = keys.firstIndex(where: { $0.id == item.id }) {
            keys[idx] = item
        }
        StorageManager.saveKeys(keys)
        editingItem = nil
        editingSecret = nil
    }

    private func deleteKey(_ item: KeyItem) {
        KeychainHelper.delete(for: item.id)
        keys.removeAll { $0.id == item.id }
        StorageManager.saveKeys(keys)
        itemToDelete = nil
    }

    private var allTags: [String] {
        let tagsSet = Set(keys.flatMap { $0.tags })
        return Array(tagsSet).sorted()
    }

    private var filteredKeys: [KeyItem] {
        keys.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.platform.localizedCaseInsensitiveContains(searchText) ||
                item.label.localizedCaseInsensitiveContains(searchText) ||
                item.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })

            let matchesTag = selectedTag == nil || item.tags.contains(selectedTag!)

            return matchesSearch && matchesTag
        }
        .sorted(by: { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending })
    }
}

struct TagPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Text(title)
            .font(.khMonoLabel)
            .tracking(0.5)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundColor(isSelected ? KHTheme.paper : KHTheme.ink60)
            .background(isSelected ? KHTheme.ink : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : KHTheme.ink12, lineWidth: 1)
            )
            .contentShape(Capsule())
            .onTapGesture(perform: action)
    }
}
