import Testing
import Foundation
@testable import KeyholdrKit

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    // Swift Testing Documentation
    // https://developer.apple.com/documentation/testing
}

// MARK: - Notes

@Suite struct NoteItemTests {
    @Test func titleIsFirstNonBlankLine() {
        let note = NoteItem(text: "\n  Standup — Fri  \n- ship notes tab\n\n- fix login item")
        #expect(note.title == "Standup — Fri")
        #expect(note.preview == "- ship notes tab - fix login item")
    }

    @Test func emptyNoteHasPlaceholderTitle() {
        #expect(NoteItem(text: "").title == "Empty note")
        #expect(NoteItem(text: " \n\t\n").isEmpty)
        #expect(NoteItem(text: "").preview == "")
    }

    @Test func searchMatchesAnywhereIgnoringCase() {
        let note = NoteItem(text: "Groceries\noat milk, limes")
        #expect(note.matches("LIMES"))
        #expect(note.matches(""))
        #expect(!note.matches("coffee"))
    }

    @Test func ageLabels() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func label(secondsAgo: TimeInterval) -> String {
            NoteItem(text: "x", createdAt: now.addingTimeInterval(-secondsAgo)).ageLabel(now: now)
        }
        #expect(label(secondsAgo: 10) == "NOW")
        #expect(label(secondsAgo: 5 * 60) == "5M AGO")
        #expect(label(secondsAgo: 3 * 3_600) == "3H AGO")
    }
}

@Suite struct NoteStorageTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("keyholdr-tests-\(UUID().uuidString)")
            .appendingPathComponent("notes.json")
    }

    @Test func roundTripsAndSortsNewestFirst() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let older = NoteItem(text: "older", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = NoteItem(text: "newer", createdAt: Date(timeIntervalSince1970: 1_700_000_500))
        NoteStorage.saveNotes([older, newer], to: url)

        let loaded = NoteStorage.loadNotes(from: url)
        #expect(loaded == [newer, older])
    }

    @Test func missingFileLoadsEmpty() {
        #expect(NoteStorage.loadNotes(from: tempURL()).isEmpty)
    }

    @Test func corruptFileLoadsEmpty() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(NoteStorage.loadNotes(from: url).isEmpty)
    }

    @Test func upsertReplacesByIdAndPreservesOtherNotes() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let keep = NoteItem(text: "keep", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        var edit = NoteItem(text: "v1", createdAt: Date(timeIntervalSince1970: 1_700_000_100))
        NoteStorage.saveNotes([keep, edit], to: url)

        // Another process adds a note between our load and our write.
        let other = NoteItem(text: "from the app", createdAt: Date(timeIntervalSince1970: 1_700_000_200))
        NoteStorage.upsert(other, at: url)

        edit.text = "v2"
        edit.updatedAt = Date(timeIntervalSince1970: 1_700_000_300)
        NoteStorage.upsert(edit, at: url)

        let loaded = NoteStorage.loadNotes(from: url)
        #expect(loaded.count == 3)
        #expect(loaded.first { $0.id == edit.id }?.text == "v2")
        #expect(loaded.contains { $0.text == "from the app" })
        #expect(loaded.contains { $0.text == "keep" })
    }

    @Test func removeDeletesOnlyThatNote() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let a = NoteItem(text: "a", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let b = NoteItem(text: "b", createdAt: Date(timeIntervalSince1970: 1_700_000_100))
        NoteStorage.saveNotes([a, b], to: url)
        NoteStorage.remove(id: a.id, at: url)
        #expect(NoteStorage.loadNotes(from: url) == [b])
    }
}
