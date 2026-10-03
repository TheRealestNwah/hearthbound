import Foundation
import SwiftData

/// User-initiated mutations either save completely or restore the last saved state.
/// Flush pre-existing edits first so rolling back a failed operation does not discard them.
@MainActor
enum JournalStore {
    static func commit<T>(in context: ModelContext,
                          save: (ModelContext) throws -> Void = { try $0.save() },
                          restore: () -> Void = {},
                          changes: () throws -> T) throws -> T {
        if context.hasChanges { try context.save() }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            let value = try changes()
            try save(context)
            return value
        } catch {
            context.rollback()
            // SwiftData may leave observable values and inverse arrays cached after rollback.
            // Restore the operation's small value snapshot, never a replacement model graph.
            restore()
            throw error
        }
    }

    /// Values changed by an entry edit. Keep original photo objects and bytes untouched.
    private struct EntryValues {
        let entry: Entry
        let body: String
        let inGameDate: String
        let place: String
        let writtenAt: Date
        let updatedAt: Date
        let journal: Journal?
        let photos: [EntryPhoto]?
        let order: [(EntryPhoto, Int)]
        init(_ entry: Entry) {
            self.entry = entry
            body = entry.body
            inGameDate = entry.inGameDate
            place = entry.place
            writtenAt = entry.writtenAt
            updatedAt = entry.updatedAt
            journal = entry.journal
            photos = entry.photos
            order = (entry.photos ?? []).map { ($0, $0.sortIndex) }
        }
        func restore() {
            entry.body = body
            entry.inGameDate = inGameDate
            entry.place = place
            entry.writtenAt = writtenAt
            entry.updatedAt = updatedAt
            entry.journal = journal
            entry.photos = photos
            for (photo, index) in order { photo.sortIndex = index }
        }
    }

    static func save(_ draft: EntryDraft, entry: Entry?, in journal: Journal,
                     context: ModelContext, drafts: DraftShelf = DraftShelf(),
                     persist: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let original = entry.map(EntryValues.init)
        let entries = journal.entries
        let updatedAt = journal.updatedAt
        try commit(in: context, save: persist, restore: {
            original?.restore()
            journal.entries = entries
            journal.updatedAt = updatedAt
        }) {
            let destination: Entry
            var page = draft
            if let entry {
                destination = entry
            } else {
                destination = Entry()
                context.insert(destination)
                page.writtenAt = .now
            }
            page.apply(to: destination, in: journal)
        }
        if entry == nil { drafts.discard(for: journal.id) }
    }

    /// Journal metadata and inverse relationships, for creation/deletion/undo operations.
    /// Entry snapshots are only needed for a cascading journal delete.
    static func restoration(for journal: Journal, includingEntries: Bool = false) -> () -> Void {
        let name = journal.characterName
        let epithet = journal.epithet
        let game = journal.gameTitle
        let cover = journal.coverStyleRaw
        let updated = journal.updatedAt
        let entries = journal.entries
        let values = includingEntries ? (entries ?? []).map(EntryValues.init) : []
        return {
            journal.characterName = name
            journal.epithet = epithet
            journal.gameTitle = game
            journal.coverStyleRaw = cover
            journal.updatedAt = updated
            journal.entries = entries
            for entry in values { entry.restore() }
        }
    }

}

/// User cancellation is not a failed export/import.
enum FileOperation {
    static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}
