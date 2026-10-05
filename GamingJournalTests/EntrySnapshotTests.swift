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
        let snapshot: EntrySnapshot
        let journalID: UUID

        do {
            let context = ModelContext(try Persistence.makeContainer(url: url))
            let journal = Journal(characterName: "Eira", createdAt: date)
            journalID = journal.id
            context.insert(journal)
            let entry = Entry(body: "Keep every picture.", inGameDate: "Day 3", place: "Helgen",
                              writtenAt: date.addingTimeInterval(60), createdAt: date)
            entry.updatedAt = date.addingTimeInterval(120)
            context.insert(entry)
            entry.journal = journal
            entry.photos = [
                EntryPhoto(imageData: Data([1, 2, 3]), thumbnailData: Data([4]), sortIndex: 0, createdAt: date),
                EntryPhoto(imageData: nil, thumbnailData: Data([5]), sortIndex: 2, createdAt: date),
                EntryPhoto(imageData: nil, thumbnailData: nil, sortIndex: 4, createdAt: date),
                EntryPhoto(imageData: Data([6]), thumbnailData: nil, sortIndex: 6, createdAt: date),
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
        XCTAssertEqual(restored.journal?.id, journalID)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<Entry>()), 1)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<EntryPhoto>()), 4)
        for photo in restored.sortedPhotos { XCTAssertEqual(photo.entry?.id, snapshot.id) }
    }
}
