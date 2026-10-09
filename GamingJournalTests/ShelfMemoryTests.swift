import XCTest
@testable import GamingJournal

final class ShelfMemoryTests: XCTestCase {
    private let suite = "ShelfMemoryTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testRemembersTheJournalOpenedLast() {
        let memory = ShelfMemory(defaults: defaults)
        let first = UUID(), second = UUID()
        XCTAssertNil(memory.lastOpened)

        memory.noteOpened(first)
        XCTAssertEqual(memory.lastOpened, first)
        memory.noteOpened(second)
        XCTAssertEqual(memory.lastOpened, second)
    }

    func testForgetsOnlyTheJournalItRemembers() {
        let memory = ShelfMemory(defaults: defaults)
        let kept = UUID()
        memory.noteOpened(kept)

        memory.forget(UUID())
        XCTAssertEqual(memory.lastOpened, kept)
        memory.forget(kept)
        XCTAssertNil(memory.lastOpened)
    }
}
