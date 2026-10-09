import XCTest
import SwiftData
@testable import GamingJournal

/// Each journal's in-game calendar (#232): the V2 → V3 migration and what the calendar guides.
@MainActor
final class JournalCalendarTests: XCTestCase {
    func testV2StoreOpensWithFreeTextCalendars() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("calendar-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let journalID = UUID()
        do {
            let v2 = try ModelContainer(
                for: Schema(versionedSchema: HearthboundSchemaV2.self),
                configurations: ModelConfiguration(url: url)
            )
            let context = ModelContext(v2)
            context.insert(HearthboundSchemaV2.Journal(id: journalID, characterName: "Eira", gameTitle: "Skyrim", coverStyle: .frost))
            try context.save()
        }

        let context = ModelContext(try Persistence.makeContainer(url: url))
        let journal = try XCTUnwrap(try context.fetch(FetchDescriptor<Journal>()).first)
        XCTAssertEqual(journal.id, journalID)
        XCTAssertEqual(journal.coverStyle, .frost)
        XCTAssertEqual(journal.calendarRaw, "")
        XCTAssertEqual(journal.calendar, .freeText)
    }

    func testEveryCalendarsDatesStepOn() throws {
        for calendar in JournalCalendar.allCases where calendar != .freeText {
            let sample = try XCTUnwrap(calendar.sample)
            let first = try XCTUnwrap(calendar.firstDate)
            XCTAssertEqual(JournalCalendar.recognizing(sample), calendar, sample)
            XCTAssertEqual(JournalCalendar.recognizing(first), calendar, first)
            XCTAssertNotNil(InGameDate.nextDay(after: first), first)
            XCTAssertTrue(calendar.placeholder.contains(sample))
        }
        XCTAssertNil(JournalCalendar.freeText.sample)
        XCTAssertNil(JournalCalendar.freeText.firstDate)
    }

    func testRecognizesTheCalendarADateIsWrittenIn() {
        XCTAssertEqual(JournalCalendar.recognizing("16th of Last Seed, 4E 201"), .tamriel)
        XCTAssertEqual(JournalCalendar.recognizing("Midsummer, 1492 DR"), .harptos)
        XCTAssertEqual(JournalCalendar.recognizing("23 October 2287"), .realWorld)
        XCTAssertEqual(JournalCalendar.recognizing(" Day 40 "), .dayCount)
        XCTAssertNil(JournalCalendar.recognizing("The third night of the siege"))
        XCTAssertNil(JournalCalendar.recognizing(""))
    }

    func testGameNameSuggestsACalendar() {
        XCTAssertEqual(JournalCalendar.suggested(forGame: "The Elder Scrolls V: Skyrim"), .tamriel)
        XCTAssertEqual(JournalCalendar.suggested(forGame: "Baldur's Gate 3"), .harptos)
        XCTAssertEqual(JournalCalendar.suggested(forGame: "FALLOUT 4"), .realWorld)
        XCTAssertNil(JournalCalendar.suggested(forGame: "The Witcher 3"))
        XCTAssertNil(JournalCalendar.suggested(forGame: "  "))
    }

    func testFirstPageStartsOnTheCalendarsOpeningDate() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira", calendar: .tamriel)
        context.insert(journal)
        XCTAssertEqual(EntryDraft.new(in: journal).inGameDate, "Sundas, 17th of Last Seed, 4E 201")

        // Once written, the next page follows the latest entry, not the calendar.
        let entry = Entry(body: "a", inGameDate: "Day 3")
        context.insert(entry)
        entry.journal = journal
        XCTAssertEqual(EntryDraft.new(in: journal).inGameDate, "Day 3")

        let plain = Journal(characterName: "Wanderer")
        context.insert(plain)
        XCTAssertEqual(EntryDraft.new(in: plain).inGameDate, "")
    }

    func testChangingTheCalendarLeavesWrittenDatesAlone() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira")
        context.insert(journal)
        let entry = Entry(body: "a", inGameDate: "The night Helgen burned")
        context.insert(entry)
        entry.journal = journal
        journal.calendar = .tamriel
        XCTAssertEqual(entry.inGameDate, "The night Helgen burned")
    }

    func testUndoRestoresTheCalendar() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira", calendar: .harptos)
        context.insert(journal)
        let restore = JournalStore.restoration(for: journal)
        journal.calendar = .dayCount
        restore()
        XCTAssertEqual(journal.calendar, .harptos)
    }

    func testBackupCarriesTheCalendar() throws {
        let context = ModelContext(try Persistence.makeContainer(inMemory: true))
        let journal = Journal(characterName: "Eira", calendar: .tamriel)
        let plain = Journal(characterName: "Wanderer")
        context.insert(journal)
        context.insert(plain)
        let backup = try JournalBackup.decode(JournalBackup(exporting: [journal, plain]).encoded())
        let tamriel = try XCTUnwrap(backup.journals.first { $0.id == journal.id })
        let free = try XCTUnwrap(backup.journals.first { $0.id == plain.id })
        XCTAssertEqual(tamriel.calendar, "tamriel")
        XCTAssertEqual(tamriel.makeJournal().calendar, .tamriel)
        XCTAssertNil(free.calendar)
        XCTAssertEqual(free.makeJournal().calendar, .freeText)
    }
}
