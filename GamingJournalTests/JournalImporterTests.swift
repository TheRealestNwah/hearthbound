import XCTest
import SwiftData
@testable import GamingJournal

@MainActor
final class JournalImporterTests: XCTestCase {
    private func sampleJournal(in context: ModelContext) throws -> Journal {
        let journal = Journal(characterName: "Eira", createdAt: Date(timeIntervalSince1970: 1_000))
        context.insert(journal)
        let entry = Entry(body: "Original", createdAt: journal.createdAt)
        context.insert(entry)
        entry.journal = journal
        entry.photos = [EntryPhoto(imageData: Data([1, 2, 3]), thumbnailData: Data([4]))]
        try context.save()
        return journal
    }

    /// Includes a duplicate, a new illustrated entry in the existing journal, and a new journal.
    private func backupAddingEntries(to journal: Journal) throws -> JournalBackup {
        var backup = try JournalBackup(exporting: [journal])
        var added = backup.journals[0].entries[0]
        added.id = UUID()
        added.body = "Imported into existing journal"
        added.updatedAt = Date(timeIntervalSince1970: 2_000_000_000)
        added.photos[0].id = UUID()
        backup.journals[0].entries.append(added)
        var other = backup.journals[0]
        other.id = UUID()
        other.characterName = "New journal"
        added.id = UUID()
        added.body = "Imported into new journal"
        added.photos[0].id = UUID()
        other.entries = [added]
        backup.journals.append(other)
        return backup
    }

    func testFailedImportRollsBackAndRetriesAfterReopeningStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("import.store")
        let backup: JournalBackup
        let baseline: [JournalBackup.JournalRecord]

        do {
            let context = ModelContext(try Persistence.makeContainer(url: url))
            let journal = try sampleJournal(in: context)
            baseline = try JournalBackup(exporting: [journal]).journals
            backup = try backupAddingEntries(to: journal)
            context.autosaveEnabled = true
            var reachedSave = false
            XCTAssertThrowsError(try JournalImporter.importBackup(backup, into: context) { saving in
                reachedSave = true
                XCTAssertFalse(saving.autosaveEnabled)
                XCTAssertEqual(try saving.fetchCount(FetchDescriptor<Journal>()), 2)
                XCTAssertEqual(try saving.fetchCount(FetchDescriptor<Entry>()), 3)
                throw CocoaError(.fileWriteOutOfSpace)
            }) { error in
                XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
                XCTAssertEqual((error as NSError).code, CocoaError.Code.fileWriteOutOfSpace.rawValue)
            }
            XCTAssertTrue(reachedSave)
            XCTAssertTrue(context.autosaveEnabled)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 1)
            XCTAssertEqual(try JournalBackup(exporting: [journal]).journals, baseline)
            // A later unrelated save must not persist any part of the failed import.
            try context.save()
        }

        let reopened = ModelContext(try Persistence.makeContainer(url: url))
        XCTAssertEqual(try JournalBackup(exporting: reopened.fetch(FetchDescriptor<Journal>())).journals, baseline)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<Entry>()), 1)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<EntryPhoto>()), 1)
        let report = try JournalImporter.importBackup(backup, into: reopened)
        XCTAssertEqual(report, JournalImporter.Report(journalsAdded: 1, entriesAdded: 2, skipped: 1))
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<Journal>()), 2)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<Entry>()), 3)
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<EntryPhoto>()), 3)
        let entries = try reopened.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(Set(entries.map(\.id)), Set(backup.journals.flatMap(\.entries).map(\.id)))
        XCTAssertTrue(entries.allSatisfy { $0.sortedPhotos.first?.imageData == Data([1, 2, 3]) })
        XCTAssertEqual(try JournalImporter.importBackup(backup, into: reopened),
                       JournalImporter.Report(journalsAdded: 0, entriesAdded: 0, skipped: 3))
    }

    func testFailedImportPreservesUnrelatedPendingEditsAndSameContextRetry() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let journal = try sampleJournal(in: context)
        let backup = try backupAddingEntries(to: journal)
        let entry = try XCTUnwrap(journal.story.first)
        journal.characterName = "Edited before import"
        entry.body = "Unrelated pending writing"
        let unrelated = Journal(characterName: "Also pending")
        context.insert(unrelated)
        let snapshot = EntrySnapshot(entry: entry)
        let updatedAt = journal.updatedAt

        XCTAssertThrowsError(try JournalImporter.importBackup(backup, into: context) { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        })
        XCTAssertEqual(journal.characterName, "Edited before import")
        XCTAssertEqual(journal.updatedAt, updatedAt)
        XCTAssertEqual(journal.story.map(\.id), [entry.id])
        XCTAssertEqual(EntrySnapshot(entry: entry), snapshot)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Journal>()), 2)

        // Pre-existing changes were saved before import began, not discarded with its rollback.
        let observer = ModelContext(container)
        let savedJournals = try observer.fetch(FetchDescriptor<Journal>())
        XCTAssertEqual(Set(savedJournals.map(\.characterName)), ["Edited before import", "Also pending"])
        XCTAssertEqual(try observer.fetch(FetchDescriptor<Entry>()).map(\.body), [snapshot.body])

        XCTAssertEqual(try JournalImporter.importBackup(backup, into: context),
                       JournalImporter.Report(journalsAdded: 1, entriesAdded: 2, skipped: 1))
        XCTAssertEqual(journal.characterName, "Edited before import")
        XCTAssertEqual(entry.body, snapshot.body)
        XCTAssertEqual(journal.story.count, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 3)
    }
}
