import Foundation

/// A scratch-pad note. Plain text, stored unencrypted in notes.json — notes
/// are deliberately not secrets, so they never touch the Keychain.
public struct NoteItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), text: String = "", createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Display

    /// First non-blank line, trimmed.
    public var title: String {
        firstLineAndRest.title ?? "Empty note"
    }

    /// The rest of the text after the title line, collapsed onto one line.
    public var preview: String {
        firstLineAndRest.rest
    }

    /// Matches on the whole text, case- and diacritic-insensitively.
    public func matches(_ query: String) -> Bool {
        query.isEmpty || text.localizedCaseInsensitiveContains(query)
    }

    /// Short relative label for list rows: "NOW", "5M AGO", "3H AGO",
    /// "YESTERDAY", "MON" within the week, else "12 SEP".
    public func ageLabel(now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(updatedAt)
        switch seconds {
        case ..<60: return "NOW"
        case ..<3_600: return "\(Int(seconds / 60))M AGO"
        case ..<86_400: return "\(Int(seconds / 3_600))H AGO"
        default: break
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: updatedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days == 1 { return "YESTERDAY" }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(days < 7 ? "EEE" : "d MMM")
        return formatter.string(from: updatedAt).uppercased()
    }

    private var firstLineAndRest: (title: String?, rest: String) {
        var lines = text.split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        lines.removeAll { $0.isEmpty }
        guard let first = lines.first else { return (nil, "") }
        let rest = lines.dropFirst().joined(separator: " ")
        return (first, rest)
    }
}

/// Reads and writes notes.json next to keys.json. Unlike `StorageManager`
/// there is no Keychain mirror: notes aren't secrets, and the Keychain isn't
/// built for many or large blobs.
public enum NoteStorage {
    private static var fileURL: URL {
        StorageManager.directoryURL.appendingPathComponent("notes.json")
    }

    /// Newest-edited first. A missing or corrupt file yields no notes.
    public static func loadNotes() -> [NoteItem] {
        loadNotes(from: fileURL)
    }

    public static func saveNotes(_ notes: [NoteItem]) {
        saveNotes(notes, to: fileURL)
    }

    static func loadNotes(from url: URL) -> [NoteItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([NoteItem].self, from: data)
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Error loading notes: \(error)")
            return []
        }
    }

    static func saveNotes(_ notes: [NoteItem], to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(notes).write(to: url, options: .atomic)
        } catch {
            print("Error saving notes: \(error)")
        }
    }
}
