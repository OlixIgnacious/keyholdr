import SwiftUI
import KeyholdrKit

/// Search field + note list, shown under the KEYS | NOTES switcher.
@MainActor
struct NotesListView: View {
    @ObservedObject var store: NotesStore
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(KHTheme.ink40)

                    TextField("Search notes…", text: $searchText)
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

                Button(action: newNote) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KHTheme.paper)
                        .frame(width: 30, height: 30)
                        .background(KHTheme.ink)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("New note (⌘N)")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if filteredNotes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredNotes) { note in
                            NoteRowView(
                                note: note,
                                onOpen: { open(note) },
                                onCopy: { store.copy(note.id) },
                                onDelete: { store.delete(note.id) }
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

    private var filteredNotes: [NoteItem] {
        store.notes.filter { $0.matches(searchText) }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(KHTheme.ink40)

            Text(searchText.isEmpty ? "No notes yet." : "No matching notes.")
                .font(.system(size: 13))
                .foregroundColor(KHTheme.ink60)

            if searchText.isEmpty {
                Button(action: newNote) {
                    HStack(spacing: 6) {
                        Text("Add your first note")
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

                Text("Paste anything — it autosaves. Notes are plain text, so keep secrets in Keys.")
                    .font(.system(size: 10))
                    .foregroundColor(KHTheme.ink40)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private func newNote() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            store.newNote()
        }
    }

    private func open(_ note: NoteItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            store.editingID = note.id
        }
    }
}

private struct NoteRowView: View {
    let note: NoteItem
    var onOpen: () -> Void
    var onCopy: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var isCopied = false
    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(note.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(KHTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(note.ageLabel())
                        .font(.khMonoLabel)
                        .tracking(0.5)
                        .foregroundColor(KHTheme.ink40)
                        .fixedSize()
                }

                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.khMonoSub)
                        .foregroundColor(KHTheme.ink40)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            if isHovered {
                Button(action: deleteTapped) {
                    if confirmingDelete {
                        Text("DELETE?")
                            .font(.khMonoLabel)
                            .tracking(0.5)
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(KHTheme.ink60)
                            .frame(width: 22, height: 22)
                    }
                }
                .buttonStyle(.plain)
                .help(confirmingDelete ? "Click again to delete" : "Delete note")
                .transition(.opacity)
            }

            Button(action: copy) {
                Text(isCopied ? "COPIED" : "COPY")
                    .font(.khMonoLabel)
                    .tracking(0.8)
                    .foregroundColor(isCopied || isHovered ? KHTheme.ink : KHTheme.ink40)
            }
            .buttonStyle(.plain)
            .help("Copy note")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(isHovered ? KHTheme.ink06 : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if !hovering { confirmingDelete = false }
        }
    }

    private func deleteTapped() {
        if confirmingDelete {
            onDelete()
        } else {
            confirmingDelete = true
        }
    }

    private func copy() {
        onCopy()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isCopied = false }
        }
    }
}

/// Full-popover editor for one note, presented like AddKeyView. Autosaves
/// through `NotesStore`; there is no save button.
@MainActor
struct NoteEditorView: View {
    @ObservedObject var store: NotesStore
    let noteID: UUID

    @FocusState private var isFocused: Bool
    @State private var isCopied = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            TextEditor(text: textBinding)
                .font(.system(size: 13))
                .foregroundColor(KHTheme.ink)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .khGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            footer
        }
        .onAppear {
            // Focus needs a runloop turn after the transition inserts the view.
            DispatchQueue.main.async { isFocused = true }
        }
    }

    private var note: NoteItem? {
        store.notes.first { $0.id == noteID }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { note?.text ?? "" },
            set: { store.setText($0, for: noteID) }
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            circleButton("chevron.left", help: "Back to notes (Esc)") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    store.closeEditor()
                }
            }

            Spacer()

            if let note, !note.isEmpty {
                Text("EDITED \(note.ageLabel())")
                    .font(.khMonoLabel)
                    .tracking(0.5)
                    .foregroundColor(KHTheme.ink40)
            }

            Spacer()

            circleButton(isCopied ? "checkmark" : "doc.on.doc", help: "Copy note", action: copy)

            if confirmingDelete {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        store.delete(noteID)
                    }
                }) {
                    Text("DELETE?")
                        .font(.khMonoLabel)
                        .tracking(0.5)
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Click again to delete")
            } else {
                circleButton("trash", help: "Delete note") {
                    confirmingDelete = true
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        confirmingDelete = false
                    }
                }
            }
        }
    }

    private func circleButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(KHTheme.ink60)
                .frame(width: 24, height: 24)
                .khGlass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "lock.open")
                    .font(.system(size: 9, weight: .medium))
                Text("UNENCRYPTED · KEEP SECRETS IN KEYS")
                    .font(.khMonoLabel)
                    .tracking(0.5)
            }
            .foregroundColor(KHTheme.ink40)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: store.isSaving ? "circle.dotted" : "checkmark")
                    .font(.system(size: 9, weight: .medium))
                Text(store.isSaving ? "SAVING" : "SAVED")
                    .font(.khMonoLabel)
                    .tracking(0.5)
            }
            .foregroundColor(KHTheme.ink60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(KHTheme.ink06).frame(height: 1)
        }
    }

    private func copy() {
        store.copy(noteID)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isCopied = false }
        }
    }
}
