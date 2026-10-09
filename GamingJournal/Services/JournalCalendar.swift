import Foundation

/// The calendar a journal's game keeps. It only guides the writer, with a date hint and a first
/// date to start from; the in-game date itself stays free text, and choosing a calendar never
/// changes dates already written. `InGameDate` steps any of these on by a day.
enum JournalCalendar: String, CaseIterable, Identifiable, Codable {
    case freeText, tamriel, harptos, realWorld, dayCount

    var id: String { rawValue }

    var label: String {
        switch self {
        case .freeText: "Free text"
        case .tamriel: "Tamriel"
        case .harptos: "Forgotten Realms"
        case .realWorld: "Real-world"
        case .dayCount: "Day count"
        }
    }

    /// Which games keep it, or what it means.
    var detail: String {
        switch self {
        case .freeText: "Any game, dated your own way"
        case .tamriel: "The Elder Scrolls"
        case .harptos: "Calendar of Harptos, as in Baldur's Gate"
        case .realWorld: "Fallout and other games on Earth's calendar"
        case .dayCount: "Days since the story began"
        }
    }

    /// A date written the way this calendar reads, or nil for free text.
    var sample: String? {
        switch self {
        case .freeText: nil
        case .tamriel: "Sundas, 17th of Last Seed, 4E 201"
        case .harptos: "15 Mirtul, 1492 DR"
        case .realWorld: "October 23, 2287"
        case .dayCount: "Day 12"
        }
    }

    /// The hint in the writer's empty date field.
    var placeholder: String {
        guard let sample else { return "In-game date, e.g. 17th of Last Seed or Day 12" }
        return "In-game date, e.g. \(sample)"
    }

    /// Where a journal's first page starts, for the writer to change. Nil for free text.
    var firstDate: String? {
        switch self {
        case .freeText: nil
        case .tamriel: "Sundas, 17th of Last Seed, 4E 201"
        case .harptos: "1 Hammer, 1492 DR"
        case .realWorld: "October 23, 2287"
        case .dayCount: "Day 1"
        }
    }

    /// The calendar an already-written date is in, if it's one `InGameDate` can read.
    static func recognizing(_ date: String) -> JournalCalendar? {
        InGameDate.calendar(of: date)
    }

    /// A calendar suggested by the game's name, for a new journal. A short built-in list, not a
    /// game database: anything else stays free text.
    static func suggested(forGame game: String) -> JournalCalendar? {
        let name = SearchText.normalize(game)
        guard !name.isEmpty else { return nil }
        let hints: [(JournalCalendar, [String])] = [
            (.tamriel, ["skyrim", "oblivion", "morrowind", "elder scrolls", "daggerfall"]),
            (.harptos, ["baldur", "neverwinter", "icewind dale", "forgotten realms"]),
            (.realWorld, ["fallout"]),
        ]
        return hints.first { _, words in words.contains { name.contains($0) } }?.0
    }
}
