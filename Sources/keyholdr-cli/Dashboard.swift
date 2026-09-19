import AppKit
import Foundation
import KeyholdrKit
import KeyholdrTUI
import LocalAuthentication

/// The full-screen KEYS | NOTES interface behind bare `keyholdr`. State and
/// actions live here; drawing is in `Dashboard+View.swift`.
///
/// Secret access follows the one-liners exactly: copy and reveal go through
/// the same biometric gate, and adding/deleting keys goes through the same
/// `addKey` / `deleteKeys` rules as `keyholdr add` and `keyholdr rm`.
final class Dashboard {
    enum Tab { case keys, notes }

    enum Confirm {
        case deleteKeys([KeyItem])
        case deleteNote(NoteItem)
    }

    struct AddForm {
        static let titles = ["PLATFORM", "LABEL", "TAGS · COMMA SEPARATED", "SECRET · HIDDEN"]
        var fields = [TextBuffer(), TextBuffer("default"), TextBuffer(), TextBuffer()]
        var focus = 0
        var error: String?
    }

    struct NoteEditor {
        var note: NoteItem
        var buffer: TextBuffer
        let isNew: Bool
        var scrollTop = 0
    }

    enum Modal {
        case none
        case confirm(Confirm)
        case addKey(AddForm)
        case editNote(NoteEditor)
    }

    struct Toast {
        var text: String
        var isError: Bool
        var until: Date
    }

    struct Reveal {
        var id: UUID
        var secret: String
        var until: Date
    }

    static let revealSeconds: TimeInterval = 10
    static let toastSeconds: TimeInterval = 3

    let terminal = Terminal()

    var tab: Tab = .keys
    var modal: Modal = .none
    var allKeys: [KeyItem] = []
    var allNotes: [NoteItem] = []
    var keyFilter: TextBuffer
    var noteFilter = TextBuffer()
    var keyIndex = 0
    var noteIndex = 0
    var keyTop = 0
    var noteTop = 0
    var marked = Set<UUID>()
    var reveal: Reveal?
    var toast: Toast?
    /// Shown in the status row while a blocking call (Touch ID) is running.
    var busy: String?
    /// Printed to the normal screen after quitting, so copies leave a trace.
    private var lastCopy: String?

    init(initialFilter: String = "") {
        keyFilter = TextBuffer(initialFilter)
        reloadKeys()
        reloadNotes()
    }

    // MARK: - Run loop

    /// Runs until the user quits. Returns a one-line summary of the last
    /// copy, if any, for the caller to print once the terminal is restored.
    func run() -> String? {
        terminal.start()
        defer { terminal.stop() }

        draw()
        loop: while true {
            switch terminal.nextEvent(timeoutMs: 250) {
            case .terminate, .eof:
                commitEditorIfOpen()
                break loop
            case .resize:
                terminal.write("\u{1B}[2J")
                draw()
            case .tick:
                if expireTransients() { draw() }
            case .key(let key):
                if handle(key) { break loop }
                _ = expireTransients()
                draw()
            }
        }
        return lastCopy
    }

    func draw() {
        terminal.write(render(size: terminal.size))
    }

    /// Drops expired toasts and reveals. Returns true if anything changed.
    private func expireTransients() -> Bool {
        var changed = false
        let now = Date()
        if let toast, toast.until <= now { self.toast = nil; changed = true }
        if let reveal, reveal.until <= now { self.reveal = nil; changed = true }
        return changed
    }

    // MARK: - Data

    func reloadKeys() {
        allKeys = StorageManager.loadKeys()
            .sorted { $0.platform.localizedCaseInsensitiveCompare($1.platform) == .orderedAscending }
        marked = marked.intersection(Set(allKeys.map(\.id)))
        clampSelection()
    }

    func reloadNotes() {
        allNotes = NoteStorage.loadNotes()
        clampSelection()
    }

    var visibleKeys: [KeyItem] {
        let query = keyFilter.string.lowercased()
        guard !query.isEmpty else { return allKeys }
        return allKeys.filter {
            $0.platform.lowercased().contains(query)
                || $0.label.lowercased().contains(query)
                || $0.tags.joined(separator: " ").lowercased().contains(query)
        }
    }

    var visibleNotes: [NoteItem] {
        allNotes.filter { $0.matches(noteFilter.string) }
    }

    var selectedKey: KeyItem? {
        let keys = visibleKeys
        return keys.indices.contains(keyIndex) ? keys[keyIndex] : nil
    }

    var selectedNote: NoteItem? {
        let notes = visibleNotes
        return notes.indices.contains(noteIndex) ? notes[noteIndex] : nil
    }

    private func clampSelection() {
        keyIndex = min(keyIndex, max(visibleKeys.count - 1, 0))
        noteIndex = min(noteIndex, max(visibleNotes.count - 1, 0))
    }

    // MARK: - Key handling

    /// Returns true when the UI should quit.
    private func handle(_ key: Key) -> Bool {
        switch modal {
        case .none:
            return handleMain(key)
        case .confirm(let confirm):
            handleConfirm(key, confirm)
        case .addKey(var form):
            modal = handleAddForm(key, &form) ? .addKey(form) : .none
        case .editNote(var editor):
            modal = handleEditor(key, &editor) ? .editNote(editor) : .none
        }
        return false
    }

    private func handleMain(_ key: Key) -> Bool {
        switch key {
        case .ctrl("c"), .ctrl("d"):
            return true
        case .escape:
            if !currentFilter.isEmpty {
                clearFilter()
            } else {
                return true
            }
        case .tab, .backTab, .left, .right:
            switchTab()
        case .up: move(by: -1)
        case .down: move(by: 1)
        case .pageUp: move(by: -pageSize)
        case .pageDown: move(by: pageSize)
        case .home: move(to: 0)
        case .end: move(to: Int.max)
        case .enter: copySelection()
        case .ctrl("n"):
            tab == .keys ? openAddForm() : openEditor(for: nil)
        case .ctrl("x"):
            requestDelete()
        case .ctrl("r"):
            if tab == .keys { revealSelectedKey() }
        case .ctrl("e"):
            if tab == .notes, let note = selectedNote { openEditor(for: note) }
        case .char(" ") where tab == .keys:
            toggleMark()
        case .char, .paste, .backspace, .ctrl("u"), .ctrl("w"):
            editFilter(key)
        default:
            break
        }
        return false
    }

    private var pageSize: Int { max(terminal.size.rows - 8, 1) }

    private var currentFilter: TextBuffer { tab == .keys ? keyFilter : noteFilter }

    private func editFilter(_ key: Key) {
        if tab == .keys {
            keyFilter.apply(key)
            keyIndex = 0
            keyTop = 0
        } else {
            noteFilter.apply(key)
            noteIndex = 0
            noteTop = 0
        }
        reveal = nil
    }

    private func clearFilter() {
        if tab == .keys { keyFilter.setText(""); keyIndex = 0; keyTop = 0 }
        else { noteFilter.setText(""); noteIndex = 0; noteTop = 0 }
    }

    private func switchTab() {
        tab = tab == .keys ? .notes : .keys
        reveal = nil
        toast = nil
    }

    private func move(by delta: Int) {
        move(to: (tab == .keys ? keyIndex : noteIndex) + delta)
    }

    private func move(to target: Int) {
        let count = tab == .keys ? visibleKeys.count : visibleNotes.count
        let clamped = min(max(target, 0), max(count - 1, 0))
        if tab == .keys {
            if clamped != keyIndex { reveal = nil }
            keyIndex = clamped
        } else {
            noteIndex = clamped
        }
    }

    private func toggleMark() {
        guard let key = selectedKey else { return }
        if marked.contains(key.id) { marked.remove(key.id) } else { marked.insert(key.id) }
        // fzf-style: marking advances to the next row.
        move(by: 1)
    }

    // MARK: - Actions

    /// ⏎ copies the selection. When nothing matches what was typed, it instead
    /// creates something from that text — a modifier-free way to add a key or
    /// note, since ⌘N belongs to the terminal app (VS Code opens a new file).
    private func copySelection() {
        switch tab {
        case .keys:
            if visibleKeys.isEmpty { openAddForm(platform: keyFilter.string) } else { copyKeys() }
        case .notes:
            if visibleNotes.isEmpty { openEditor(for: nil, initialText: noteFilter.string) } else { copyNote() }
        }
    }

    private func copyKeys() {
        let targets = marked.isEmpty
            ? [selectedKey].compactMap { $0 }
            : allKeys.filter { marked.contains($0.id) }
        guard !targets.isEmpty else { return }

        let names = targets.map { "\($0.platform) (\($0.label))" }.joined(separator: ", ")
        guard let context = authenticateInUI(
            reason: targets.count == 1 ? "copy the secret for \(names)" : "copy \(targets.count) secrets"
        ) else { return }

        // Each Keychain item has its own access list, so macOS may ask for the
        // login password once per key until "Always Allow" is chosen. Say so
        // while those dialogs are up, so they aren't a surprise.
        busy = "macOS may ask for your login password — choose Always Allow"
        draw()
        defer { busy = nil }

        // Copy every secret that can be read, and say precisely which can't —
        // one unreadable key must not sink the rest of a multi-select.
        var secrets: [String] = []
        var failed: [(key: KeyItem, status: OSStatus)] = []
        for key in targets {
            let result = KeychainHelper.lookup(for: key.id, context: context.context)
            if let secret = result.secret { secrets.append(secret) } else { failed.append((key, result.status)) }
        }

        func label(_ key: KeyItem) -> String { "\(key.platform) (\(key.label))" }

        guard !secrets.isEmpty else {
            let reason = KeychainHelper.explain(failed[0].status)
            showToast(targets.count == 1
                      ? "Couldn't read \(label(failed[0].key)): \(reason)"
                      : "Couldn't read any of the \(targets.count) secrets: \(reason)", isError: true)
            return
        }
        setClipboard(secrets.joined(separator: "\n"))

        if failed.isEmpty {
            let what = targets.count == 1 ? names : "\(targets.count) secrets — \(names)"
            lastCopy = "Copied \(what) to the clipboard."
            showToast("Copied \(what)", isError: false)
            marked.removeAll()
        } else {
            let skipped = failed.map { label($0.key) }.joined(separator: ", ")
            lastCopy = "Copied \(secrets.count) of \(targets.count) secrets to the clipboard. "
                + "Couldn't read: " + failed.map { "\(label($0.key)) — \(KeychainHelper.explain($0.status))" }.joined(separator: "; ") + "."
            showToast("Copied \(secrets.count) of \(targets.count) · couldn't read: \(skipped)", isError: true)
            // Leave the unreadable ones marked, so it's clear which they are.
            marked = Set(failed.map(\.key.id))
        }
    }

    private func copyNote() {
        guard let note = selectedNote else { return }
        setClipboard(note.text)
        showToast("Copied note “\(Text.truncate(note.title, to: 30))”", isError: false)
    }

    private func revealSelectedKey() {
        guard let key = selectedKey else { return }
        if reveal?.id == key.id { reveal = nil; return } // toggle off

        guard let context = authenticateInUI(reason: "reveal the secret for \(key.platform)") else { return }
        let result = KeychainHelper.lookup(for: key.id, context: context.context)
        guard let secret = result.secret else {
            showToast("Couldn't read \(key.platform) (\(key.label)): \(KeychainHelper.explain(result.status))", isError: true)
            return
        }
        reveal = Reveal(id: key.id, secret: secret, until: Date().addingTimeInterval(Self.revealSeconds))
    }

    private func requestDelete() {
        switch tab {
        case .keys:
            let targets = marked.isEmpty
                ? [selectedKey].compactMap { $0 }
                : allKeys.filter { marked.contains($0.id) }
            guard !targets.isEmpty else { return }
            modal = .confirm(.deleteKeys(targets))
        case .notes:
            guard let note = selectedNote else { return }
            modal = .confirm(.deleteNote(note))
        }
    }

    private func handleConfirm(_ key: Key, _ confirm: Confirm) {
        switch key {
        case .char("y"), .char("Y"):
            switch confirm {
            case .deleteKeys(let targets):
                deleteKeys(targets)
                reveal = nil
                reloadKeys()
                showToast(targets.count == 1
                          ? "Deleted \(targets[0].platform) (\(targets[0].label))"
                          : "Deleted \(targets.count) keys", isError: false)
            case .deleteNote(let note):
                NoteStorage.remove(id: note.id)
                reloadNotes()
                showToast("Deleted note", isError: false)
            }
            modal = .none
        case .char("n"), .char("N"), .escape, .ctrl("c"):
            modal = .none
        default:
            break
        }
    }

    // MARK: - Add-key form

    private func openAddForm(platform: String = "") {
        var form = AddForm()
        form.fields[0] = TextBuffer(platform.trimmingCharacters(in: .whitespaces))
        // Land on the first empty field.
        form.focus = platform.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 3
        modal = .addKey(form)
    }

    /// Returns true while the form should stay open.
    private func handleAddForm(_ key: Key, _ form: inout AddForm) -> Bool {
        switch key {
        case .escape, .ctrl("c"):
            return false
        case .tab, .down:
            form.focus = (form.focus + 1) % form.fields.count
        case .backTab, .up:
            form.focus = (form.focus + form.fields.count - 1) % form.fields.count
        case .enter, .ctrl("s"):
            // ⏎ advances through the fields and saves from the last one.
            if form.focus < form.fields.count - 1, key == .enter {
                form.focus += 1
            } else {
                return !submit(&form)
            }
        default:
            form.fields[form.focus].apply(key)
            form.error = nil
        }
        return true
    }

    /// Saves the key. Returns true on success (closing the form).
    private func submit(_ form: inout AddForm) -> Bool {
        let platform = form.fields[0].string.trimmingCharacters(in: .whitespaces)
        let label = form.fields[1].string.trimmingCharacters(in: .whitespaces)
        let secret = form.fields[3].string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !platform.isEmpty else { form.error = "Platform is required."; form.focus = 0; return false }
        guard !secret.isEmpty else { form.error = "Secret is required."; form.focus = 3; return false }

        do {
            let item = try addKey(
                platform: platform,
                label: label.isEmpty ? "default" : label,
                tags: parseTags(form.fields[2].string),
                secret: secret
            )
            keyFilter.setText("")
            reloadKeys()
            keyIndex = visibleKeys.firstIndex { $0.id == item.id } ?? 0
            showToast("Added \(item.platform) (\(item.label))", isError: false)
            return true
        } catch {
            form.error = message(for: error)
            return false
        }
    }

    // MARK: - Note editor

    private func openEditor(for note: NoteItem?, initialText: String = "") {
        let target = note ?? NoteItem()
        let text = note == nil ? initialText : target.text
        if note == nil, !initialText.isEmpty { noteFilter.setText("") } // the new note must be visible afterwards
        modal = .editNote(NoteEditor(note: target, buffer: TextBuffer(text, multiline: true), isNew: note == nil))
    }

    /// Returns true while the editor should stay open.
    private func handleEditor(_ key: Key, _ editor: inout NoteEditor) -> Bool {
        switch key {
        case .escape, .ctrl("c"):
            commit(&editor)
            return false
        case .ctrl("s"):
            commit(&editor)
            editor.note.text = editor.buffer.string
            showToast("Saved", isError: false)
        default:
            editor.buffer.apply(key)
        }
        return true
    }

    /// Persists the edited text; empty notes are discarded, as in the app.
    private func commit(_ editor: inout NoteEditor) {
        let text = editor.buffer.string
        var note = editor.note
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !editor.isNew { NoteStorage.remove(id: note.id) }
        } else {
            if text != note.text { note.text = text; note.updatedAt = Date() }
            NoteStorage.upsert(note)
        }
        reloadNotes()
        if let index = visibleNotes.firstIndex(where: { $0.id == note.id }) { noteIndex = index }
    }

    private func commitEditorIfOpen() {
        if case .editNote(var editor) = modal { commit(&editor) }
    }

    // MARK: - Helpers

    func showToast(_ text: String, isError: Bool) {
        // Errors stay longer: they carry names and reasons worth reading.
        toast = Toast(text: text, isError: isError, until: Date().addingTimeInterval(isError ? 8 : Self.toastSeconds))
    }

    private func setClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// `context` is nil when LocalAuthentication is unavailable (CI, VMs),
    /// where Keychain reads need none.
    struct AuthContext { let context: LAContext? }

    /// Runs the biometric gate from inside the UI: shows a status line first
    /// (the call blocks), and reports failure as a toast, never on stderr.
    private func authenticateInUI(reason: String) -> AuthContext? {
        busy = "Touch ID — \(reason)…"
        draw()
        defer { busy = nil }
        switch authenticate(reason: reason) {
        case .authenticated(let context):
            return AuthContext(context: context)
        case .denied:
            showToast("Authentication failed.", isError: true)
            return nil
        }
    }
}
