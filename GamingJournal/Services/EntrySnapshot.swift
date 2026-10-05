import Foundation

/// An in-memory copy for Undo. Unlike a portable backup, this must preserve photo records
/// even when their image bytes are unavailable, without substituting thumbnails for originals.
struct EntrySnapshot: Equatable {
    struct Photo: Equatable {
        let id: UUID
        let imageData: Data?
        let thumbnailData: Data?
        let sortIndex: Int
        let createdAt: Date
    }

    let id: UUID
    let body: String
    let inGameDate: String
    let place: String
    let writtenAt: Date
    let createdAt: Date
    let updatedAt: Date
    let photos: [Photo]

    init(entry: Entry) {
        id = entry.id
        body = entry.body
        inGameDate = entry.inGameDate
        place = entry.place
        writtenAt = entry.writtenAt
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
        photos = entry.sortedPhotos.map {
            Photo(id: $0.id, imageData: $0.imageData, thumbnailData: $0.thumbnailData,
                  sortIndex: $0.sortIndex, createdAt: $0.createdAt)
        }
    }

    /// Recreates the entry and its photos; the caller inserts it and attaches its journal.
    func makeEntry() -> Entry {
        let entry = Entry(id: id, body: body, inGameDate: inGameDate, place: place,
                          writtenAt: writtenAt, createdAt: createdAt)
        entry.updatedAt = updatedAt
        entry.photos = photos.map {
            EntryPhoto(id: $0.id, imageData: $0.imageData, thumbnailData: $0.thumbnailData,
                       sortIndex: $0.sortIndex, createdAt: $0.createdAt)
        }
        return entry
    }
}
