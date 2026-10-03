import XCTest
import SwiftData
@testable import GamingJournal

@MainActor
final class JournalStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    override func setUp() {
        defaults = UserDefaults(suiteName: "JournalStoreTests")
        defaults.removePersistentDomain(forName: "JournalStoreTests")
    }
    override func tearDown() { defaults.removePersistentDomain(forName: "JournalStoreTests") }

    func testFailedNewEntryRetainsDraftAndRetryDoesNotDuplicate() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        try context.save()
        let shelf = DraftShelf(defaults: defaults)
        let draft = EntryDraft(body: "A page that must survive.")
        shelf.keep(draft, for: journal.id)
        XCTAssertThrowsError(try JournalStore.save(draft, entry: nil, in: journal, context: context, drafts: shelf) { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertEqual(shelf.saved(for: journal.id)?.body, draft.body)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 0)
        try JournalStore.save(draft, entry: nil, in: journal, context: context, drafts: shelf)
        XCTAssertNil(shelf.saved(for: journal.id))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).map(\.body), [draft.body])
    }

    func testFailedEditRestoresSavedTextAndPictures() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        let entry = Entry(body: "Original")
        context.insert(entry)
        entry.journal = journal
        entry.photos = [EntryPhoto(imageData: Data([1]), thumbnailData: Data([2]))]
        try context.save()
        var draft = EntryDraft(entry: entry)
        draft.body = "Changed"
        draft.photos = []
        XCTAssertThrowsError(try JournalStore.save(draft, entry: entry, in: journal, context: context) { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertEqual(entry.body, "Original")
        XCTAssertEqual(entry.sortedPhotos.count, 1)
        XCTAssertEqual(entry.sortedPhotos.first?.imageData, Data([1]))
        XCTAssertEqual(draft.body, "Changed", "The editor copy remains available for retry")
        try JournalStore.save(draft, entry: entry, in: journal, context: context)
        XCTAssertEqual(entry.body, "Changed")
        XCTAssertTrue(entry.sortedPhotos.isEmpty)
    }

    func testFailedJournalDeleteRestoresJournalAndEntries() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = DemoData.journal()
        context.insert(journal)
        try context.save()
        XCTAssertThrowsError(try JournalStore.commit(in: context, save: { _ in throw CocoaError(.fileWriteOutOfSpace) },
                                                   restore: JournalStore.restoration(for: journal, includingEntries: true)) {
            context.delete(journal)
        })
        XCTAssertEqual(try context.fetch(FetchDescriptor<Journal>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Entry>()).count, 3)
        XCTAssertEqual(journal.story.count, 3)
    }

    func testSavedEntrySurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("journals.store")
        do {
            let context = ModelContext(try Persistence.makeContainer(url: url))
            let journal = Journal(characterName: "Traveller")
            context.insert(journal)
            try context.save()
            try JournalStore.save(EntryDraft(body: "Still here after relaunch."), entry: nil, in: journal, context: context)
        }
        let reopened = ModelContext(try Persistence.makeContainer(url: url))
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<Entry>()).map(\.body), ["Still here after relaunch."])
    }

    func testCancellationIsDistinctFromExportFailure() {
        XCTAssertTrue(FileOperation.isCancellation(CocoaError(.userCancelled)))
        XCTAssertFalse(FileOperation.isCancellation(CocoaError(.fileWriteNoPermission)))
    }
}
