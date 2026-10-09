import Foundation

/// Remembers which journal was opened last on this device, so the shelf can lay a ribbon on its
/// cover. Kept locally, like the ribbons in `RibbonShelf`.
struct ShelfMemory {
    static let key = "shelf.lastOpened"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastOpened: UUID? {
        defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:))
    }

    func noteOpened(_ journalID: UUID) {
        guard lastOpened != journalID else { return }
        defaults.set(journalID.uuidString, forKey: Self.key)
    }

    /// Forgets a journal that's gone from the shelf.
    func forget(_ journalID: UUID) {
        guard lastOpened == journalID else { return }
        defaults.removeObject(forKey: Self.key)
    }
}
