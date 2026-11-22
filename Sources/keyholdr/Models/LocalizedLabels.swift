import Foundation
import KeyholdrKit

// Localized counterparts of the short labels KeyholdrKit builds. Kit stays in
// English because the CLI uses it too, and the CLI's output must not change.
// Translations live in Localizable.xcstrings (see scripts/sync-strings.sh).

extension KeyItem {
    /// "12d", "3w", "6mo", "2y" — same thresholds as `compactAge`.
    var localizedCompactAge: String {
        let days = Int(Date().timeIntervalSince(secretLastChanged) / 86_400)
        switch days {
        case ..<14: return String(localized: "\(max(days, 0))d", comment: "Compact age in days")
        case ..<60: return String(localized: "\(days / 7)w", comment: "Compact age in weeks")
        case ..<548: return String(localized: "\(days / 30)mo", comment: "Compact age in months")
        default: return String(localized: "\(days / 365)y", comment: "Compact age in years")
        }
    }

    /// "12 days", "3 weeks", "6 months", "2 years" — the long form of
    /// `localizedCompactAge`, for prose such as the rotation tooltip.
    var localizedAgeDescription: String {
        let days = Int(Date().timeIntervalSince(secretLastChanged) / 86_400)
        switch days {
        case ..<14: return String(localized: "\(max(days, 0)) days", comment: "Duration; plural forms in the catalog")
        case ..<60: return String(localized: "\(days / 7) weeks", comment: "Duration; plural forms in the catalog")
        case ..<548: return String(localized: "\(days / 30) months", comment: "Duration; plural forms in the catalog")
        default: return String(localized: "\(days / 365) years", comment: "Duration; plural forms in the catalog")
        }
    }
}

extension NoteItem {
    /// `title`, with the placeholder for a blank note translated.
    var localizedTitle: String {
        isEmpty ? String(localized: "Empty note") : title
    }

    /// Same buckets as `ageLabel`: "NOW", "5M AGO", "3H AGO", "YESTERDAY",
    /// a weekday within the week, else a short date.
    func localizedAgeLabel(now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(updatedAt)
        switch seconds {
        case ..<60:
            return String(localized: "NOW", comment: "Note edited less than a minute ago")
        case ..<3_600:
            return String(localized: "\(Int(seconds / 60))M AGO", comment: "Note age in minutes")
        case ..<86_400:
            return String(localized: "\(Int(seconds / 3_600))H AGO", comment: "Note age in hours")
        default:
            break
        }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: updatedAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days == 1 { return String(localized: "YESTERDAY", comment: "Note edited yesterday") }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        // Month and weekday names in the app's language (not a language the app
        // has no translation for), in the order of the user's region.
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let region = Locale.current.region.map { "_\($0.identifier)" } ?? ""
        formatter.locale = Locale(identifier: language + region)
        formatter.setLocalizedDateFormatFromTemplate(days < 7 ? "EEE" : "d MMM")
        return formatter.string(from: updatedAt).uppercased()
    }
}
