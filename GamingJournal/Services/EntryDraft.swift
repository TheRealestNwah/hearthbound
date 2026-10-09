import Foundation
import SwiftData

/// A photo in the writer: either already stored on the entry (same id) or newly picked.
struct DraftPhoto: Identifiable, Equatable {
    var id = UUID()
    var imageData: Data
    var thumbnailData: Data
}

/// Editable copy of an entry, so the writer can be cancelled without touching the model.
struct EntryDraft: Equatable {
    var body = ""
    var inGameDate = ""
    var place = ""
    var writtenAt = Date.now
    var photos: [DraftPhoto] = []

    init(body: String = "", inGameDate: String = "", place: String = "", writtenAt: Date = .now) {
        self.body = body
        self.inGameDate = inGameDate
        self.place = place
        self.writtenAt = writtenAt
    }

    /// A fresh page, dated and placed like the journal's latest entry so the writer only has to
    /// nudge it. A journal's first page starts on its calendar's opening date, if it has one.
    static func new(in journal: Journal, now: Date = .now) -> EntryDraft {
        guard let latest = journal.latestEntry else {
            return EntryDraft(inGameDate: journal.calendar.firstDate ?? "", writtenAt: now)
        }
        return EntryDraft(inGameDate: latest.inGameDate, place: latest.place, writtenAt: now)
    }

    init(entry: Entry) {
        body = entry.body
        inGameDate = entry.inGameDate
        place = entry.place
        writtenAt = entry.writtenAt
        // A photo missing its image (not yet downloaded, or damaged) stays in the draft, shown by
        // its thumbnail or a placeholder, so saving doesn't take it for removed. Saving only
        // reorders photos already on the entry; it never writes these bytes back.
        photos = entry.sortedPhotos.map { photo in
            DraftPhoto(
                id: photo.id,
                imageData: photo.imageData ?? photo.thumbnailData ?? Data(),
                thumbnailData: photo.thumbnailData ?? photo.imageData ?? Data()
            )
        }
    }

    /// Something worth keeping: some writing, or at least a picture.
    var isValid: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }

    // MARK: Saving

    func makeEntry(in journal: Journal, now: Date = .now) -> Entry {
        let entry = Entry(createdAt: now)
        apply(to: entry, in: journal, now: now)
        return entry
    }

    /// Writes the draft into `entry`. The entry must already be in a context (or be inserted
    /// alongside the journal) for photo removal to take effect.
    func apply(to entry: Entry, in journal: Journal, now: Date = .now) {
        entry.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.inGameDate = inGameDate.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        entry.place = place.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        entry.writtenAt = writtenAt
        entry.updatedAt = now
        entry.journal = journal
        applyPhotos(to: entry)
        journal.touch(now)
    }

    private func applyPhotos(to entry: Entry) {
        let existing = entry.photos ?? []
        let keptIDs = Set(photos.map(\.id))
        for photo in existing where !keptIDs.contains(photo.id) {
            photo.modelContext?.delete(photo)
        }
        var remaining = existing.filter { keptIDs.contains($0.id) }
        for (index, draftPhoto) in photos.enumerated() {
            if let photo = remaining.first(where: { $0.id == draftPhoto.id }) {
                photo.sortIndex = index
            } else {
                remaining.append(EntryPhoto(
                    id: draftPhoto.id,
                    imageData: draftPhoto.imageData,
                    thumbnailData: draftPhoto.thumbnailData,
                    sortIndex: index
                ))
            }
        }
        entry.photos = remaining
    }
}
