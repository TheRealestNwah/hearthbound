import Foundation

/// A bookmark in an entry's source text. Older records use layout-dependent part numbers;
/// new records include a UTF-16 offset so resizing and text-size changes keep the passage.
struct RibbonMark: Codable, Equatable {
    var entryID: UUID
    var part: Int
    /// Older ribbons only have a part number; newly placed ribbons use a stable source offset.
    var textOffset: Int?

    /// The ribbon for the page a reader is on, or nil for a blank page.
    init?(page: JournalPager.Page) {
        guard let block = page.blocks.first else { return nil }
        entryID = block.entryID
        part = block.part
        textOffset = block.textOffset
    }

    init(entryID: UUID, part: Int, textOffset: Int? = nil) {
        self.entryID = entryID
        self.part = part
        self.textOffset = textOffset
    }
}

/// Keeps each journal's ribbon on this device, like the unfinished pages in `DraftShelf`.
struct RibbonShelf {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(for journalID: UUID) -> String {
        "ribbon.\(journalID.uuidString)"
    }

    func mark(for journalID: UUID) -> RibbonMark? {
        defaults.data(forKey: Self.key(for: journalID)).flatMap { try? JSONDecoder().decode(RibbonMark.self, from: $0) }
    }

    /// Lays the ribbon at `mark`, or takes it out with nil.
    func setMark(_ mark: RibbonMark?, for journalID: UUID) {
        guard let mark, let data = try? JSONEncoder().encode(mark) else {
            defaults.removeObject(forKey: Self.key(for: journalID))
            return
        }
        defaults.set(data, forKey: Self.key(for: journalID))
    }
}
