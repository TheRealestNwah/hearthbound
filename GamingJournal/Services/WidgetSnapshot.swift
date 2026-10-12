import Foundation
import WidgetKit

/// What the widgets show, written by the app to the shared App Group. The widget extension has a
/// mirror of this type (`GamingJournalWidgets/Snapshot.swift`); keep the two in step.
struct WidgetSnapshot: Codable, Equatable {
    /// The shared App Group, from the `APP_GROUP` build setting (`Config/Identity.xcconfig`) by way of
    /// the `AppGroup` Info.plist key, so builds signed with another bundle ID prefix find their own group.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String ?? "group.com.gamingjournal.GamingJournal"
    static let key = "widgetSnapshot"
    /// Opens a new page: in the journal a link names, or else the most recent one.
    static let writeURL = URL(string: "gamingjournal://write")!

    /// The journal a write link points at, if it names one.
    static func journalID(inWriteURL url: URL) -> UUID? {
        guard url.scheme == writeURL.scheme, url.host == writeURL.host else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "journal" }?.value
            .flatMap(UUID.init(uuidString:))
    }

    static func isEntryURL(_ url: URL) -> Bool {
        url.scheme == entryURL.scheme && url.host == entryURL.host
    }

    static func isWriteURL(_ url: URL) -> Bool {
        url.scheme == writeURL.scheme && url.host == writeURL.host
    }

    /// Opens the journal at one entry's page.
    static let entryURL = URL(string: "gamingjournal://entry")!

    static func entryURL(for entryID: UUID) -> URL {
        var components = URLComponents(url: entryURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: entryID.uuidString)]
        return components.url!
    }

    /// The entry an entry link points at.
    static func entryID(inEntryURL url: URL) -> UUID? {
        guard url.scheme == entryURL.scheme, url.host == entryURL.host else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "id" }?.value
            .flatMap(UUID.init(uuidString:))
    }

    static func writeURL(for journalID: UUID) -> URL {
        var components = URLComponents(url: writeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "journal", value: journalID.uuidString)]
        return components.url!
    }

    /// The most recent entry across all journals.
    struct LatestEntry: Codable, Equatable {
        var journalID: UUID
        var characterName: String
        var heading: String
        /// Where the entry was written in the game, if it says.
        var place: String?
        /// Opening of the body, trimmed for a small widget.
        var excerpt: String
        var writtenAt: Date
        /// Set for memories, which open at their entry.
        var entryID: UUID?

        static let excerptLength = 160

        init(journalID: UUID, characterName: String, heading: String, place: String? = nil, excerpt: String, writtenAt: Date) {
            self.journalID = journalID
            self.characterName = characterName
            self.heading = heading
            self.place = place
            self.excerpt = excerpt
            self.writtenAt = writtenAt
        }

        init(entry: Entry) {
            journalID = entry.journal?.id ?? UUID()
            characterName = entry.journal?.characterName ?? ""
            heading = entry.heading()
            place = entry.place.isEmpty ? nil : entry.place
            let body = entry.body.replacingOccurrences(of: "\n", with: " ")
            excerpt = body.count > Self.excerptLength
                ? String(body.prefix(Self.excerptLength)).trimmingCharacters(in: .whitespaces) + "…"
                : body
            writtenAt = entry.writtenAt
            entryID = entry.id
        }
    }

    /// What the "On this day" widget shows on `day`: an entry written on that date in an earlier
    /// year, or failing that, within a few days of it.
    struct DayMemory: Codable, Equatable {
        /// Start of the day this memory is for.
        var day: Date
        var entry: LatestEntry
    }

    var generatedAt: Date
    var latestEntry: LatestEntry?
    /// A memory for each of the coming days that has one, so the widget moves on at midnight
    /// without the app. Nil when there are none (or the journal is locked).
    var memories: [DayMemory]? = nil

    /// How far either side of the date a memory may come from when nothing was written on it.
    static let memorySlack = 3

    /// Picks a memory for each of `days` days from `today`: an entry from an earlier year written
    /// on the same month and day (most recent year first), else the oldest entry within
    /// `memorySlack` days of its anniversary.
    static func memories(from entries: [Entry], today: Date, days: Int = 7, calendar: Calendar = .current) -> [DayMemory] {
        let start = calendar.startOfDay(for: today)
        return (0..<days).compactMap { offset -> DayMemory? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let yearBefore = calendar.date(byAdding: .day, value: -(365 - memorySlack), to: day)
            else { return nil }
            let year = calendar.component(.year, from: day)
            let best = entries
                // Written in an earlier year, not just last week across New Year.
                .filter { $0.writtenAt < yearBefore }
                .compactMap { entry -> (entry: Entry, distance: Int)? in
                    let parts = calendar.dateComponents([.month, .day], from: entry.writtenAt)
                    // The anniversary nearest the day, which may fall in the year either side.
                    let distances = [year - 1, year, year + 1].compactMap { anniversaryYear -> Int? in
                        guard let sameDay = calendar.date(from: DateComponents(year: anniversaryYear, month: parts.month, day: parts.day)) else { return nil }
                        return calendar.dateComponents([.day], from: day, to: sameDay).day.map(abs)
                    }
                    guard let distance = distances.min(), distance <= memorySlack else { return nil }
                    return (entry, distance)
                }
                .min { left, right in
                    if (left.distance == 0) != (right.distance == 0) { return left.distance == 0 }
                    if left.distance == 0 { return left.entry.writtenAt > right.entry.writtenAt }
                    return left.entry.writtenAt < right.entry.writtenAt
                }
            return best.map { DayMemory(day: day, entry: LatestEntry(entry: $0.entry)) }
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> WidgetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetSnapshot.self, from: data)
    }

    /// Stores the snapshot for the widgets and asks them to refresh, skipping both when nothing
    /// they display has changed.
    func publish(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let defaults, let data = try? encoded() else { return }
        if let old = defaults.data(forKey: Self.key).flatMap({ try? Self.decode($0) }), old.sameContent(as: self) {
            return
        }
        defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Equal apart from `generatedAt`.
    func sameContent(as other: WidgetSnapshot) -> Bool {
        var copy = other
        copy.generatedAt = generatedAt
        return copy == self
    }
}
