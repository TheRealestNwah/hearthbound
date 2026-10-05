import XCTest
import SwiftData
@testable import GamingJournal

@MainActor
final class EntrySnapshotTests: XCTestCase {
    func testDeleteUndoPreservesUnavailablePhotosAfterReopeningStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("undo.store")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let entryID = UUID()
        let photoIDs = (0..<4).map { _ in UUID() }
        let snapshot: EntrySnapshot
        let journalID: UUID

        do {
            let context = ModelContext(try Persistence.makeContainer(url: url))
            let journal = Journal(characterName: "Eira", createdAt: date)
            journalID = journal.id
            context.insert(journal)
            let entry = Entry(id: entryID, body: "Keep every picture.", inGameDate: "Day 3", place: "Helgen",
                              writtenAt: date.addingTimeInterval(60), createdAt: date)
            entry.updatedAt = date.addingTimeInterval(120)
            context.insert(entry)
            entry.journal = journal
            entry.photos = [
                EntryPhoto(id: photoIDs[0], imageData: Data([1, 2, 3]), thumbnailData: Data([4]), sortIndex: 0, createdAt: date),
                EntryPhoto(id: photoIDs[1], imageData: nil, thumbnailData: Data([5]), sortIndex: 2, createdAt: date),
                EntryPhoto(id: photoIDs[2], imageData: nil, thumbnailData: nil, sortIndex: 4, createdAt: date),
                EntryPhoto(id: photoIDs[3], imageData: Data([6]), thumbnailData: nil, sortIndex: 6, createdAt: date),
            ]
            try context.save()
            snapshot = EntrySnapshot(entry: entry)
            try JournalStore.commit(in: context, restore: JournalStore.restoration(for: journal, includingEntries: true)) {
                context.delete(entry)
            }
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 0)

            let restored = try JournalStore.commit(in: context, restore: JournalStore.restoration(for: journal)) {
                let restored = snapshot.makeEntry()
                context.insert(restored)
                restored.journal = journal
                return restored
            }
            XCTAssertEqual(EntrySnapshot(entry: restored), snapshot)
            XCTAssertEqual(journal.story.map(\.id), [snapshot.id])
        }

        let reopened = ModelContext(try Persistence.makeContainer(url: url))
        let restored = try XCTUnwrap(try reopened.fetch(FetchDescriptor<Entry>()).first)
        XCTAssertEqual(EntrySnapshot(entry: restored), snapshot)
        XCTAssertEqual(restored.id, entryID)
        XCTAssertEqual(restored.sortedPhotos.map(\.id), photoIDs)
        XCTAssertEqual(restored.sortedPhotos.map(\.imageData), [Data([1, 2, 3]), nil, nil, Data([6])])
        XCTAssertEqual(restored.sortedPhotos.map(\.thumbnailData), [Data([4]), Data([5]), nil, nil])
        XCTAssertEqual(restored.sortedPhotos.map(\.sortIndex), [0, 2, 4, 6])
        XCTAssertEqual(restored.sortedPhotos.map(\.createdAt), Array(repeating: date, count: 4))
        XCTAssertEqual(restored.journal?.id, journalID)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<Entry>()), 1)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<EntryPhoto>()), 4)
        for photo in restored.sortedPhotos { XCTAssertEqual(photo.entry?.id, snapshot.id) }
    }
}
