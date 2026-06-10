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
                    // Header Section
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                            
                            Text("KeyHolder")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        // Add Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showingAddSheet = true
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Add new key")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search platforms, labels, tags...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    
                    // Tag Filter Horizontal ScrollView
                    if !allTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                TagPill(title: "All", isSelected: selectedTag == nil) {
                                    withAnimation(.easeOut(duration: 0.2)) { selectedTag = nil }
                                }
                                
                                ForEach(allTags, id: \.self) { tag in
                                    TagPill(title: tag, isSelected: selectedTag == tag) {
                                        withAnimation(.easeOut(duration: 0.2)) { selectedTag = tag }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 10)
                    }
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Main Keys List
                    if filteredKeys.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: searchText.isEmpty ? "key.horizontal" : "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            
                            Text(searchText.isEmpty ? "No keys saved yet." : "No matching keys found.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            
                            if searchText.isEmpty {
                                Button("Add Your First Key") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        showingAddSheet = true
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                            }
                            Spacer()
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    Divider()
                    
                    // Footer Section
                    HStack {
                        Text("\(keys.count) keys stored")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("Keychain Secured")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.01))
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
        }
        .frame(width: 350, height: 420)
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
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue : Color.primary.opacity(0.06))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
            .onTapGesture(perform: action)
    }
}
