import XCTest
@testable import GamingJournal

final class JournalPagerTests: XCTestCase {
    private func item(_ body: String, heading: String = "16th of Last Seed", place: String = "", photos: Bool = false) -> JournalPager.Item {
        JournalPager.Item(id: UUID(), heading: heading, place: place, body: body, hasPhotos: photos)
    }

    /// Words of `length` letters, so line counts are easy to reason about.
    private func words(_ count: Int, length: Int = 4) -> String {
        Array(repeating: String(repeating: "a", count: length), count: count).joined(separator: " ")
    }

    func testEmptyJournalStillHasOnePage() {
        let pages = JournalPager(charactersPerLine: 30, linesPerPage: 20).pages(for: [])
        XCTAssertEqual(pages.count, 1)
        XCTAssertTrue(pages[0].blocks.isEmpty)
    }

    func testWrapBreaksAtWordsAndSplitsOverlongWords() {
        let pager = JournalPager(charactersPerLine: 10, linesPerPage: 20)
        XCTAssertEqual(pager.wrap("aaaa bbbb cccc"), ["aaaa bbbb", "cccc"])
        XCTAssertEqual(pager.wrap("abcdefghijklmno"), ["abcdefghij", "klmno"])
        XCTAssertEqual(pager.wrap(""), [])
    }

    func testShortEntriesShareAPage() {
        let pager = JournalPager(charactersPerLine: 30, linesPerPage: 20)
        let pages = pager.pages(for: [item("One short line."), item("Another short line.")])
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].blocks.map(\.showsHeading), [true, true])
    }

    func testLongEntryCarriesOverWithoutRepeatingItsHeading() throws {
        // 9 words of 4 letters fill a 14-character line two at a time: 45 lines of text.
        let pager = JournalPager(charactersPerLine: 14, linesPerPage: 20)
        let long = item(words(90))
        let pages = pager.pages(for: [long])
        XCTAssertGreaterThan(pages.count, 1)
        XCTAssertEqual(pages.flatMap(\.blocks).filter(\.showsHeading).count, 1)
        XCTAssertTrue(pages.allSatisfy { $0.blocks.allSatisfy { $0.entryID == long.id } })
        XCTAssertEqual(pages.flatMap(\.blocks).map(\.part), Array(0..<pages.count))
        // Every word makes it onto a page, in order.
        let words = pages.flatMap(\.blocks).flatMap { $0.text.split(whereSeparator: \.isWhitespace) }
        XCTAssertEqual(words.count, 90)
    }

    func testNoPageOverflows() {
        let pager = JournalPager(charactersPerLine: 20, linesPerPage: 15)
        let items = (0..<12).map { index in item(words(5 + index * 7), place: index % 3 == 0 ? "Whiterun" : "", photos: index % 4 == 0) }
        for page in pager.pages(for: items) {
            var lines = 0
            for (position, block) in page.blocks.enumerated() {
                if block.showsHeading {
                    lines += (position == 0 ? 0 : JournalPager.entryGap) + JournalPager.headingLines
                    if !block.place.isEmpty { lines += JournalPager.placeLines }
                }
                lines += JournalPager.paragraphs(in: block.text).reduce(0) { $0 + pager.lineCount(of: $1) }
                if block.showsPhotos { lines += JournalPager.photoLines }
            }
            XCTAssertLessThanOrEqual(lines, pager.linesPerPage, "page \(page.index + 1) overflows")
        }
    }

    func testHeadingIsNeverLeftAloneAtTheFootOfAPage() {
        let pager = JournalPager(charactersPerLine: 20, linesPerPage: 12)
        // The first entry leaves one line free: too little for the next heading and its text.
        let first = item(words(4 * 9))
        let second = item("A new day.")
        let pages = pager.pages(for: [first, second])
        let secondStart = pages.first { $0.blocks.contains { $0.entryID == second.id } }
        XCTAssertEqual(secondStart?.blocks.first?.entryID, second.id)
        XCTAssertEqual(JournalPager.pageIndex(of: second.id, in: pages), secondStart?.index)
    }

    func testPictureOnlyEntryKeepsItsHeadingWithItsPictures() {
        let pager = JournalPager(charactersPerLine: 20, linesPerPage: 12)
        // Heading and 6 lines leave 4 free: room for a heading and two lines, not the pictures.
        let first = item(words(24))
        let pictures = item("", photos: true)
        let pages = pager.pages(for: [first, pictures])
        let blocks = pages.flatMap(\.blocks).filter { $0.entryID == pictures.id }
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.showsHeading, true)
        XCTAssertEqual(blocks.first?.showsPhotos, true)
        XCTAssertEqual(JournalPager.pageIndex(of: pictures.id, in: pages), 1)
    }

    func testPlaceGoesWithTheHeadingOnly() {
        let pager = JournalPager(charactersPerLine: 14, linesPerPage: 20)
        let blocks = pager.pages(for: [item(words(90), place: "Whiterun")]).flatMap(\.blocks)
        XCTAssertEqual(blocks.first?.place, "Whiterun")
        XCTAssertTrue(blocks.allSatisfy { $0.place == "Whiterun" })
        // The place takes a line, so the first page holds one line less of text.
        let withoutPlace = pager.pages(for: [item(words(90))]).flatMap(\.blocks)
        XCTAssertEqual(pager.wrap(blocks[0].text).count + 1, pager.wrap(withoutPlace[0].text).count)
    }

    func testPhotosFollowTheLastWordsOfTheirEntry() {
        let pager = JournalPager(charactersPerLine: 30, linesPerPage: 20)
        let entry = item("Found a strange stone.", photos: true)
        let blocks = pager.pages(for: [entry]).flatMap(\.blocks)
        XCTAssertEqual(blocks.last?.showsPhotos, true)
        XCTAssertEqual(blocks.filter(\.showsPhotos).count, 1)
    }

    func testParagraphBreaksSurvive() {
        let pager = JournalPager(charactersPerLine: 40, linesPerPage: 20)
        let pages = pager.pages(for: [item("First thought.\n\nSecond thought.")])
        XCTAssertEqual(pages[0].blocks[0].text, "First thought.\n\nSecond thought.")
    }

    func testFacingPagesOnlyOnWideLandscapeScreens() {
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 1180, height: 820), 2, "iPad landscape")
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 820, height: 1180), 1, "iPad portrait")
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 932, height: 430), 1, "iPhone landscape")
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 393, height: 852), 1, "iPhone portrait")
        XCTAssertEqual(JournalPager.spreadStart(of: 5, pagesPerSpread: 2), 4)
        XCTAssertEqual(JournalPager.spreadStart(of: 4, pagesPerSpread: 2), 4)
        XCTAssertEqual(JournalPager.spreadStart(of: 5, pagesPerSpread: 1), 5)
    }

    func testResizedWindowsSwitchSpreadsAtTheBoundary() {
        for width in [320.0, 504, 639, 820, 959] {
            XCTAssertEqual(JournalPager.pagesPerSpread(width: width, height: 700), 1)
        }
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 960, height: 700), 2)
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 1024, height: 1024), 1)
        XCTAssertEqual(JournalPager.pagesPerSpread(width: 1366, height: 900), 2)
    }

    func testSizeEstimateGivesSensibleCapacity() {
        let pager = JournalPager(width: 342, height: 657, fontSize: 19)
        XCTAssertEqual(pager.charactersPerLine, 37)
        XCTAssertEqual(pager.linesPerPage, 24)
    }

    func testStartPagesAndRibbonPages() throws {
        // 45 lines of text over 20-line pages: the long entry runs across three pages.
        let pager = JournalPager(charactersPerLine: 14, linesPerPage: 20)
        let first = item("Short.")
        let long = item(words(90))
        let pages = pager.pages(for: [first, long])
        let starts = JournalPager.startPages(in: pages)
        XCTAssertEqual(starts[first.id], 0)
        XCTAssertEqual(starts[long.id], JournalPager.pageIndex(of: long.id, in: pages))

        let parts = pages.flatMap(\.blocks).filter { $0.entryID == long.id }.map(\.part)
        let lastPart = try XCTUnwrap(parts.max())
        XCTAssertEqual(JournalPager.pageIndex(of: long.id, part: 0, in: pages), starts[long.id])
        XCTAssertEqual(JournalPager.pageIndex(of: long.id, part: lastPart, in: pages), pages.count - 1)
        // A part the entry no longer runs to lands on its last page.
        XCTAssertEqual(JournalPager.pageIndex(of: long.id, part: lastPart + 5, in: pages), pages.count - 1)
        XCTAssertNil(JournalPager.pageIndex(of: UUID(), part: 0, in: pages))
    }
    func testPageSlicesPreserveLongWordsWhitespaceAndUnicodeExactly() {
        let body = "abcdefghijklmno  https://example.com/averylongpath\n\n雪山の旅人👩🏽‍🚀は帰らない\tEnd."
        for pager in [JournalPager(charactersPerLine: 10, linesPerPage: 9),
                      JournalPager(width: 80, height: 200, fontSize: 19)] {
            let blocks = pager.pages(for: [item(body)]).flatMap(\.blocks)
            XCTAssertEqual(blocks.map(\.text).joined(), body)
            var offset = 0
            for block in blocks {
                XCTAssertEqual(block.textOffset, offset)
                offset += (block.text as NSString).length
            }
        }
    }

    func testSourceLocationSurvivesReflowInTheMiddleOfAnEntry() throws {
        let entry = item((0..<120).map { "Milestone \($0) beside the winding mountain road." }.joined(separator: "\n"))
        let narrow = JournalPager(charactersPerLine: 24, linesPerPage: 15).pages(for: [entry])
        let oldPage = narrow[narrow.count / 2]
        let mark = try XCTUnwrap(RibbonMark(page: oldPage))
        let offset = try XCTUnwrap(mark.textOffset)
        for size in [(48, 24), (18, 10), (70, 30)] {
            let pages = JournalPager(charactersPerLine: size.0, linesPerPage: size.1).pages(for: [entry])
            let index = try XCTUnwrap(JournalPager.pageIndex(of: entry.id, textOffset: offset, in: pages))
            let block = try XCTUnwrap(pages[index].blocks.first)
            XCTAssertLessThanOrEqual(block.textOffset, offset)
            XCTAssertGreaterThan(block.textOffset + (block.text as NSString).length, offset)
        }
    }

}
