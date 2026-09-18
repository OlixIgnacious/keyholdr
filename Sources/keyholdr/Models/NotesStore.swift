import SwiftUI
import AppKit
import KeyholdrKit

/// Owns the scratch notes and their autosave. Edits are written on a short
/// debounce, and `flush()` writes immediately — `MainView` is torn down every
/// time the popover closes, so anything still pending must be flushed then.
@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [NoteItem]
    /// The note open in the editor, if any.
    @Published var editingID: UUID?
    /// True between an edit and the write that persists it.
    @Published private(set) var isSaving = false

    private var saveTask: Task<Void, Never>?
    private static let saveDelay: Duration = .milliseconds(400)

    init() {
        notes = NoteStorage.loadNotes()
    }

    var editingNote: NoteItem? {
        guard let id = editingID else { return nil }
        return notes.first { $0.id == id }
    }

    // MARK: - Editing

    func newNote() {
        let note = NoteItem()
        notes.insert(note, at: 0)
        editingID = note.id
    }

    func setText(_ text: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }),
              notes[index].text != text else { return }
        notes[index].text = text
        notes[index].updatedAt = Date()
        scheduleSave()
    }

    /// Leaves the editor. A note that was never typed into is discarded, and
    /// the list re-sorts so the note just edited moves to the top.
    func closeEditor() {
        if let note = editingNote, note.isEmpty {
            notes.removeAll { $0.id == note.id }
        }
        editingID = nil
        notes.sort { $0.updatedAt > $1.updatedAt }
        flush()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if editingID == id { editingID = nil }
        flush()
    }

    func copy(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
    }

    // MARK: - Persistence

    private func scheduleSave() {
        isSaving = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Writes immediately. Blank notes are never persisted.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        NoteStorage.saveNotes(notes.filter { !$0.isEmpty })
        isSaving = false
    }
}
