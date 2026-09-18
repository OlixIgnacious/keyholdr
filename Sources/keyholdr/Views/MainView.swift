import SwiftUI
import KeyholdrKit
import UniformTypeIdentifiers

@MainActor
struct MainView: View {
    @ObservedObject var securityManager: SecurityManager
    @State private var keys: [KeyItem] = []

    // Scratch notes live beside the vault, behind a KEYS | NOTES switcher.
    @StateObject private var notesStore = NotesStore()
    @AppStorage("selectedTab") private var selectedTab: VaultTab = .keys

    @State private var searchText = ""
    @State private var selectedTag: String? = nil

    // Add/Edit view states
    @State private var showingAddSheet = false
    @State private var editingItem: KeyItem? = nil
    @State private var editingSecret: String? = nil

    // Delete state
    @State private var itemToDelete: KeyItem? = nil

    // Vault export/import states
    @State private var transferMode: TransferMode? = nil
    @State private var transferError: String? = nil

    // MenuBarExtra windows do not route key equivalents to SwiftUI buttons,
    // so shortcuts are handled through a local event monitor instead.
    @State private var keyMonitor: Any? = nil

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingHelp = false

    @Environment(\.openURL) private var openURL
    private static let websiteURL = URL(string: "https://olixignacious.github.io/keyholdr-site/")!

    #if MAS_BUILD
    @State private var showingTerminalSetup = false
    #endif

    #if !MAS_BUILD
    @State private var cliInstalled = CLIInstaller.isInstalled
    @State private var cliInstallResult: String? = nil
    @AppStorage("hasDismissedCLIBanner") private var hasDismissedCLIBanner = false
    #endif

    var body: some View {
        ZStack {
            KHTheme.paper.ignoresSafeArea()

            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        hasSeenOnboarding = true
                        showingAddSheet = true
                    }
                }
                .transition(.opacity)
            } else if showingHelp {
                OnboardingView(
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showingHelp = false
                        }
                    },
                    ctaTitle: "Got it",
                    ctaShortcut: nil
                )
                .transition(.opacity)
            } else if showingAddSheet {
                AddKeyView(
                    existingKeys: keys,
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
                    existingKeys: keys,
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
            } else if let mode = transferMode {
                TransferView(
                    mode: mode,
                    errorText: transferError,
                    onConfirm: { passphrase in
                        switch mode {
                        case .exportAll:
                            performExport(passphrase: passphrase)
                        case .importFile(let url):
                            performImport(from: url, passphrase: passphrase)
                        }
                    },
                    onCancel: { closeTransfer() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else if let noteID = notesStore.editingID {
                NoteEditorView(store: notesStore, noteID: noteID)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                // Primary Key List Interface
                VStack(spacing: 0) {
                    tabSwitcher

                    if selectedTab == .notes {
                        NotesListView(store: notesStore)
                    } else {
                        keysTab
                    }

                    #if !MAS_BUILD
                    // CLI install banner — shown once to users without the CLI
                    if selectedTab == .keys && !cliInstalled && !hasDismissedCLIBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(KHTheme.ink40)
                            Text("Want Keyholdr in your terminal?")
                                .font(.khMonoLabel)
                                .tracking(0.3)
                                .foregroundColor(KHTheme.ink60)
                            Spacer()
                            Button(action: installCLI) {
                                Text("INSTALL CLI")
                                    .font(.khMonoLabel)
                                    .tracking(0.5)
                                    .foregroundColor(KHTheme.ink)
                            }
                            .buttonStyle(.plain)
                            Button(action: { hasDismissedCLIBanner = true }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(KHTheme.ink40)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(KHTheme.paperSoft)
                        .overlay(alignment: .top) {
                            Rectangle().fill(KHTheme.ink06).frame(height: 1)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    #endif

                    // Footer
                    HStack {
                        Text(footerCount)
                            .font(.khMonoLabel)
                            .tracking(0.5)
                            .foregroundColor(KHTheme.ink40)

                        Spacer()

                        Button(action: {
                            LaunchAtLogin.setEnabled(!launchAtLogin)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: launchAtLogin ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 9, weight: .medium))
                                Text("AUTOSTART")
                                    .font(.khMonoLabel)
                                    .tracking(0.5)
                            }
                            .foregroundColor(launchAtLogin ? KHTheme.ink60 : KHTheme.ink40)
                        }
                        .buttonStyle(.plain)
                        .help(launchAtLogin ? "Keyholdr starts at login — click to disable" : "Start Keyholdr at login")

                        #if !MAS_BUILD
                        Spacer().frame(width: 12)

                        Button(action: installCLI) {
                            HStack(spacing: 4) {
                                Image(systemName: cliInstalled ? "checkmark.circle.fill" : "terminal")
                                    .font(.system(size: 9, weight: .medium))
                                Text("CLI")
                                    .font(.khMonoLabel)
                                    .tracking(0.5)
                            }
                            .foregroundColor(cliInstalled ? KHTheme.ink60 : KHTheme.ink40)
                        }
                        .buttonStyle(.plain)
                        .help(cliInstalled
                              ? "keyholdr CLI is installed at ~/.local/bin/keyholdr"
                              : "Install the keyholdr CLI to ~/.local/bin")
                        .popover(isPresented: Binding(
                            get: { cliInstallResult != nil },
                            set: { if !$0 { cliInstallResult = nil } }
                        )) {
                            Text(cliInstallResult ?? "")
                                .font(.khMonoSub)
                                .foregroundColor(KHTheme.ink60)
                                .padding(12)
                                .frame(maxWidth: 260)
                        }

                        Spacer().frame(width: 12)
                        #endif

                        HStack(spacing: 5) {
                            Image(systemName: selectedTab == .notes ? "lock.open" : "lock")
                                .font(.system(size: 9, weight: .medium))
                            Text(selectedTab == .notes ? "PLAIN TEXT" : "LOCKED AT REST")
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

            // Delete confirmation — `.alert` doesn't reliably present inside a
            // MenuBarExtra(.window) popover, so this is a custom in-view modal.
            if let item = itemToDelete {
                deleteConfirmOverlay(for: item)
                    .transition(.opacity)
            }
        }
        .frame(width: 360, height: 480)
        .onAppear {
            loadKeysData()
            installKeyMonitor()
            // The user may have changed the login item in System Settings.
            launchAtLogin = LaunchAtLogin.isEnabled
        }
        .onDisappear {
            removeKeyMonitor()
            // The popover closing tears this view down; don't lose a pending autosave.
            notesStore.closeEditor()
        }
    }

    private var footerCount: String {
        switch selectedTab {
        case .keys: return "\(keys.count) \(keys.count == 1 ? "KEY" : "KEYS")"
        case .notes: return "\(notesStore.notes.count) \(notesStore.notes.count == 1 ? "NOTE" : "NOTES")"
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 2) {
            TabSegment(title: "KEYS", symbol: "key", count: keys.count, isSelected: selectedTab == .keys) {
                withAnimation(.easeOut(duration: 0.2)) { selectedTab = .keys }
            }
            TabSegment(title: "NOTES", symbol: "note.text", count: notesStore.notes.count, isSelected: selectedTab == .notes) {
                withAnimation(.easeOut(duration: 0.2)) { selectedTab = .notes }
            }
        }
        .padding(3)
        .background(KHTheme.field)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(KHTheme.ink12, lineWidth: 1).allowsHitTesting(false))
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    /// The KEYS tab: search, tag filters and the key list.
    private var keysTab: some View {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .khGlass(Capsule())

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
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                .help("Add new key (⌘N)")

                Menu {
                    Button("How Keyholdr Works…") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showingHelp = true
                        }
                    }
                    Button("Visit Website…") {
                        openURL(Self.websiteURL)
                    }
                    #if MAS_BUILD
                    Button("Terminal Setup…") {
                        showingTerminalSetup = true
                    }
                    #endif
                    Divider()
                    Button("Export Vault…") { beginExport() }
                        .disabled(keys.isEmpty)
                    Button("Import Vault…") { beginImport() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHTheme.ink60)
                        .frame(width: 30, height: 30)
                        .khGlass(Circle(), interactive: true)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 30, height: 30)
                .help("Export or import the vault")
                #if MAS_BUILD
                .popover(isPresented: $showingTerminalSetup) {
                    TerminalSetupView()
                }
                #endif
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
                            HStack(spacing: 6) {
                                Text("Add your first key")
                                    .font(.system(size: 12, weight: .medium))
                                Text("⌘N")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .opacity(0.6)
                            }
                            .foregroundColor(KHTheme.paper)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(KHTheme.ink)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Text("First copy requires Touch ID — choose Always Allow on the Keychain prompt.")
                            .font(.system(size: 10))
                            .foregroundColor(KHTheme.ink40)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
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
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func deleteConfirmOverlay(for item: KeyItem) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { itemToDelete = nil }

            VStack(alignment: .leading, spacing: 14) {
                Text("Delete \(item.platform) (\(item.label))?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(KHTheme.ink)

                Text("This permanently erases the secret from your macOS Keychain. This action cannot be undone.")
                    .font(.system(size: 12))
                    .foregroundColor(KHTheme.ink60)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel") {
                        itemToDelete = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(KHTheme.ink60)

                    Button("Delete") {
                        deleteKey(item)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
                }
            }
            .padding(16)
            .frame(width: 280)
            .background(KHTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(KHTheme.ink12, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 16, y: 4)
        }
    }

    private func loadKeysData() {
        keys = StorageManager.loadKeys()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let characters = event.charactersIgnoringModifiers?.lowercased()
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let handled = MainActor.assumeIsolated {
                handleKeyDown(keyCode: keyCode, characters: characters, modifiers: modifiers)
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    /// Returns true to swallow the event when it was handled.
    private func handleKeyDown(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        let isFormOpen = showingAddSheet || editingItem != nil

        // Escape — close the export/import form
        if keyCode == 53, transferMode != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                closeTransfer()
            }
            return true
        }

        // Escape — leave the note editor
        if keyCode == 53, notesStore.editingID != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                notesStore.closeEditor()
            }
            return true
        }

        // ⌘N — new note on the Notes tab
        if modifiers == .command, characters == "n", selectedTab == .notes, !isFormOpen, transferMode == nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if notesStore.editingID != nil { notesStore.closeEditor() }
                notesStore.newNote()
            }
            return true
        }

        // ⌘N — new key
        if modifiers == .command, characters == "n", selectedTab == .keys, !isFormOpen {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showingAddSheet = true
            }
            return true
        }

        // Escape — close the add/edit form
        if keyCode == 53, isFormOpen {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showingAddSheet = false
                editingItem = nil
                editingSecret = nil
            }
            return true
        }

        return false
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
                self.editingSecret = KeychainHelper.retrieve(for: item.id, context: securityManager.context) ?? ""
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

    // MARK: - Vault export / import

    private var vaultFileType: [UTType] {
        UTType(filenameExtension: VaultExport.fileExtension).map { [$0] } ?? []
    }

    private func beginExport() {
        transferError = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            transferMode = .exportAll
        }
    }

    private func beginImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = vaultFileType
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Keyholdr vault export"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        transferError = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            transferMode = .importFile(url)
        }
    }

    private func closeTransfer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            transferMode = nil
            transferError = nil
        }
    }

    private func performExport(passphrase: String) {
        Task {
            let success = await securityManager.authenticate(reason: "export all keys")
            guard success else { return }

            // Capture everything before the save panel: the popover may close
            // beneath us once the panel takes key focus.
            let entries = keys.map { ExportedKey(item: $0, secret: KeychainHelper.retrieve(for: $0.id, context: securityManager.context) ?? "") }
            do {
                let data = try VaultExport.export(entries, passphrase: passphrase)

                let panel = NSSavePanel()
                panel.allowedContentTypes = vaultFileType
                panel.nameFieldStringValue = "vault.\(VaultExport.fileExtension)"
                panel.message = "The file is encrypted with your passphrase"
                NSApp.activate(ignoringOtherApps: true)
                closeTransfer()
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try data.write(to: url)
            } catch {
                transferError = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func performImport(from url: URL, passphrase: String) {
        do {
            let data = try Data(contentsOf: url)
            let entries = try VaultExport.import(data, passphrase: passphrase)
            for entry in entries where !keys.contains(where: { $0.id == entry.item.id }) {
                KeychainHelper.save(secret: entry.secret, for: entry.item.id)
                keys.append(entry.item)
            }
            StorageManager.saveKeys(keys)
            closeTransfer()
        } catch VaultExportError.wrongPassphrase {
            transferError = "Wrong passphrase for this file."
        } catch {
            transferError = "That file doesn't look like a Keyholdr vault export."
        }
    }

    #if !MAS_BUILD
    private func installCLI() {
        guard !cliInstalled else {
            cliInstallResult = "Already installed at\n~/.local/bin/keyholdr"
            return
        }
        switch CLIInstaller.install() {
        case .alreadyInstalled:
            cliInstalled = true
            cliInstallResult = "Already installed at\n~/.local/bin/keyholdr"
        case .installed(let patched):
            cliInstalled = true
            hasDismissedCLIBanner = true
            if patched {
                cliInstallResult = "Installed ✓\n~/.local/bin added to PATH.\nRestart Terminal to pick it up."
            } else {
                cliInstallResult = "Installed ✓\n~/.local/bin/keyholdr\nMake sure ~/.local/bin is in your PATH."
            }
        case .failed(let reason):
            cliInstallResult = "Install failed:\n\(reason)"
        }
    }
    #endif

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

enum VaultTab: String {
    case keys, notes
}

private struct TabSegment: View {
    let title: String
    let symbol: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isSelected {
                selectedPill
            } else {
                content
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var content: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
            Text(title)
                .font(.khMonoLabel)
                .tracking(0.5)
            Text("\(count)")
                .font(.khMonoLabel)
                .foregroundColor(KHTheme.ink40)
        }
        .foregroundColor(isSelected ? KHTheme.ink : KHTheme.ink60)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .contentShape(Capsule())
    }

    /// The raised bubble behind the active segment: Liquid Glass on macOS 26+.
    @ViewBuilder
    private var selectedPill: some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(KHTheme.segment, in: Capsule())
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        }
    }
}
