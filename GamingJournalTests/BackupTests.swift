import XCTest
import SwiftData
@testable import GamingJournal

@MainActor
final class BackupTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        ModelContext(try Persistence.makeContainer(inMemory: true))
    }

    private func sampleJournal(in context: ModelContext) -> Journal {
        let journal = Journal(characterName: "Eira Stormborn", epithet: "Nord", gameTitle: "Skyrim", coverStyle: .frost)
        context.insert(journal)
        let entry = Entry(body: "The dragon came.", inGameDate: "16th of Last Seed")
        context.insert(entry)
        entry.journal = journal
        entry.photos = [EntryPhoto(imageData: Data([1, 2, 3]), thumbnailData: Data([4]))]
        return journal
    }

    func testRoundTripKeepsEverything() throws {
        let source = try makeContext()
        let journal = sampleJournal(in: source)
        let data = try JournalBackup(exporting: [journal]).encoded()
        let backup = try JournalBackup.decode(data)
        XCTAssertEqual(backup.version, 3)
        XCTAssertEqual(backup.journals.first?.characterName, "Eira Stormborn")
        XCTAssertEqual(backup.journals.first?.entries.first?.photos.first?.imageData, Data([1, 2, 3]))

        let target = try makeContext()
        let report = try JournalImporter.importBackup(backup, into: target)
        XCTAssertEqual(report, JournalImporter.Report(journalsAdded: 1, entriesAdded: 1, skipped: 0))
        let imported = try XCTUnwrap(try target.fetch(FetchDescriptor<Journal>()).first)
        XCTAssertEqual(imported.id, journal.id)
        XCTAssertEqual(imported.coverStyle, .frost)
        XCTAssertEqual(imported.story.first?.inGameDate, "16th of Last Seed")
        XCTAssertEqual(imported.story.first?.sortedPhotos.first?.thumbnailData, Data([4]))
    }

    func testBackupRefusesUnavailableOriginalsWithoutChangingPhotos() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        let entry = try XCTUnwrap(journal.story.first)
        let photo = try XCTUnwrap(entry.photos?.first)
        // Thumbnail-only, entirely unavailable, and empty original bytes must all stop export.
        let unavailable: [(Data?, Data?)] = [(nil, Data([4])), (nil, nil), (Data(), Data([4]))]
        for (image, thumbnail) in unavailable {
            photo.imageData = image
            photo.thumbnailData = thumbnail
            let before = EntrySnapshot(entry: entry)
            XCTAssertThrowsError(try JournalBackup(exporting: [journal]).encoded()) { error in
                XCTAssertEqual(error as? JournalBackup.BackupError, .unavailablePhoto)
            }
            XCTAssertEqual(EntrySnapshot(entry: entry), before)
        }

        // Export works again once the original is available, even without a thumbnail.
        photo.imageData = Data([1, 2, 3])
        photo.thumbnailData = nil
        let backup = try JournalBackup.decode(JournalBackup(exporting: [journal]).encoded())
        let restored = try XCTUnwrap(backup.journals.first?.entries.first).makeEntry()
        XCTAssertEqual(restored.sortedPhotos.map(\.id), [photo.id])
        XCTAssertEqual(restored.sortedPhotos.first?.imageData, Data([1, 2, 3]))
        XCTAssertNil(restored.sortedPhotos.first?.thumbnailData)
    }

    func testImportingTwiceAddsNothing() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        let backup = try JournalBackup(exporting: [journal])
        let report = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(report.journalsAdded, 0)
        XCTAssertEqual(report.entriesAdded, 0)
        XCTAssertEqual(report.skipped, 1)
        XCTAssertTrue(report.summary.hasPrefix("Nothing new to add."))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 1)
    }

    func testDeletedEntryCanBeRestoredWithItsIdentityDatesAndPictures() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        let original = try XCTUnwrap(journal.story.first)
        original.place = "Helgen"
        let record = EntrySnapshot(entry: original)
        try context.save()
        context.delete(original)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Entry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 0)

        let restored = record.makeEntry()
        context.insert(restored)
        restored.journal = journal
        try context.save()
        XCTAssertEqual(EntrySnapshot(entry: restored), record)
        XCTAssertEqual(journal.story.map(\.id), [record.id])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<EntryPhoto>()), 1)
    }

    func testNewEntriesJoinAJournalAlreadyPresent() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        var backup = try JournalBackup(exporting: [journal])
        backup.journals[0].entries.append(JournalBackup.EntryRecord(
            id: UUID(), body: "Riverwood.", inGameDate: "17th of Last Seed",
            writtenAt: .now, createdAt: .now, updatedAt: .now, photos: []
        ))
        let report = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(report.entriesAdded, 1)
        XCTAssertEqual(journal.story.count, 2)
    }

    func testImportedEntriesMoveTheirJournalUpTheShelf() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        journal.updatedAt = .distantPast
        let later = Date(timeIntervalSince1970: 2_000_000_000)
        var backup = try JournalBackup(exporting: [journal])
        backup.journals[0].entries.append(JournalBackup.EntryRecord(
            id: UUID(), body: "Whiterun.", inGameDate: "",
            writtenAt: later, createdAt: later, updatedAt: later, photos: []
        ))
        _ = try JournalImporter.importBackup(backup, into: context)
        XCTAssertEqual(journal.updatedAt, later)
    }

    func testOlderAndNewerFormatsAreRefusedClearly() throws {
        XCTAssertThrowsError(try JournalBackup.decode(Data(#"{"version": 2, "exportedAt": "2026-01-01T00:00:00Z", "sessions": []}"#.utf8))) { error in
            XCTAssertEqual(error as? JournalBackup.BackupError, .olderFormat)
        }
        XCTAssertThrowsError(try JournalBackup.decode(Data(#"{"version": 9}"#.utf8))) { error in
            XCTAssertEqual(error as? JournalBackup.BackupError, .unsupportedVersion(9))
        }
        XCTAssertThrowsError(try JournalBackup.decode(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? JournalBackup.BackupError, .unreadable)
        }
    }

    func testMarkdownReadsLikeTheBook() throws {
        let context = try makeContext()
        let journal = sampleJournal(in: context)
        let markdown = JournalMarkdown.render(journal)
        XCTAssertTrue(markdown.hasPrefix("# The Journal of Eira Stormborn\n*Nord · Skyrim*"))
        XCTAssertTrue(markdown.contains("## 16th of Last Seed\n\nThe dragon came."))
        XCTAssertTrue(markdown.contains("*1 picture in the app*"))
        XCTAssertEqual(JournalMarkdown.filename(for: Journal(characterName: "A/B")), "The Journal of AB")
    }
}
