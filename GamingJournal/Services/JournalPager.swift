import Foundation
import CoreText

/// Lays journal entries onto book pages using the bundled font's measured line breaks.
/// Source slices preserve every character and provide stable locations when pages reflow.
/// The character-capacity initializer supports deterministic non-rendering tests.
struct JournalPager {
    /// What goes onto the pages, in reading order.
    struct Item: Equatable {
        var id: UUID
        var heading: String
        /// Shown under the heading; empty when the entry names no place.
        var place: String = ""
        var body: String
        var hasPhotos: Bool
    }

    /// One entry's share of a page.
    struct Block: Equatable, Identifiable {
        var entryID: UUID
        /// 0 for where the entry starts, then 1, 2… as it carries on over pages.
        var part: Int
        /// The date heading shows where the entry starts, not where it carries on.
        var showsHeading: Bool
        var heading: String
        var place: String = ""
        var text: String
        /// The entry's pictures follow its last words.
        var showsPhotos: Bool
        /// UTF-16 offset in the original entry body, stable across page sizes.
        var textOffset: Int = 0

        var id: String { "\(entryID)-\(part)" }
    }

    struct Page: Equatable, Identifiable {
        /// 0-based position in the book.
        var index: Int
        var blocks: [Block]

        var id: Int { index }
    }

    /// Lines a date heading takes, with the space above it.
    static let headingLines = 2
    /// The extra line a place under the heading takes.
    static let placeLines = 1
    /// Extra lines between entries; the heading's own space already separates them.
    static let entryGap = 0
    /// Lines a row of photo thumbnails takes.
    static let photoLines = 5

    var charactersPerLine: Int
    var linesPerPage: Int
    private var measuredWidth: Double?
    private var measuredFontSize: Double = 19

    init(charactersPerLine: Int, linesPerPage: Int) {
        self.charactersPerLine = max(8, charactersPerLine)
        // Room for at least a heading, a little text and the photos.
        self.linesPerPage = max(Self.headingLines + Self.photoLines + 2, linesPerPage)
    }

    /// Estimates line capacity from the page's text area and the body font size.
    init(width: Double, height: Double, fontSize: Double) {
        // Slightly generous per-character and per-line sizes for IM Fell with the page's line
        // spacing, so an estimate fills a page without overfilling it.
        self.init(
            charactersPerLine: Int(width / (fontSize * 0.48)),
            linesPerPage: Int(height / (fontSize * 1.42))
        )
        measuredWidth = max(1, width)
        measuredFontSize = fontSize
    }

    /// The pages for `items`; always at least one, so an empty journal still opens on a page.
    func pages(for items: [Item]) -> [Page] {
        var pages: [Page] = []
        var blocks: [Block] = []
        var used = 0

        func turnPage() {
            pages.append(Page(index: pages.count, blocks: blocks))
            blocks = []
            used = 0
        }

        for item in items {
            let source = item.body as NSString
            let lines = sourceLines(in: item.body)
            let keptLines = lines.isEmpty ? (item.hasPhotos ? Self.photoLines : 0) : min(2, lines.count)
            let gap = blocks.isEmpty ? 0 : Self.entryGap
            let headingLines = Self.headingLines + (item.place.isEmpty ? 0 : Self.placeLines)
            if !blocks.isEmpty && used + gap + headingLines + keptLines > linesPerPage {
                turnPage()
            }
            used += (blocks.isEmpty ? 0 : Self.entryGap) + headingLines
            var showsHeading = true
            var part = 0
            var start = 0
            var end = 0

            func placeBlock(showsPhotos: Bool) {
                blocks.append(Block(entryID: item.id, part: part, showsHeading: showsHeading,
                                    heading: item.heading, place: item.place,
                                    text: source.substring(with: NSRange(location: start, length: end - start)),
                                    showsPhotos: showsPhotos, textOffset: start))
                showsHeading = false
                part += 1
                start = end
            }

            var cursor = 0
            while cursor < lines.count {
                let available = linesPerPage - used
                if available <= 0 {
                    placeBlock(showsPhotos: false)
                    turnPage()
                    continue
                }
                let count = min(available, lines.count - cursor)
                end = lines[cursor + count - 1].upperBound
                cursor += count
                used += count
                if cursor < lines.count {
                    placeBlock(showsPhotos: false)
                    turnPage()
                }
            }
            if item.hasPhotos && used + Self.photoLines > linesPerPage {
                if end > start || showsHeading { placeBlock(showsPhotos: false) }
                turnPage()
            }
            if item.hasPhotos { used += Self.photoLines }
            if end > start || showsHeading || item.hasPhotos {
                placeBlock(showsPhotos: item.hasPhotos)
            }
        }

        if !blocks.isEmpty || pages.isEmpty {
            turnPage()
        }
        return pages
    }

    /// How many pages lie open at once in a space of `width` × `height` points: two facing pages
    /// on a wide landscape screen (an iPad), otherwise one.
    static func pagesPerSpread(width: Double, height: Double) -> Int {
        width >= 960 && width > height ? 2 : 1
    }

    /// The first page of the spread holding `page`.
    static func spreadStart(of page: Int, pagesPerSpread: Int) -> Int {
        page - page % max(1, pagesPerSpread)
    }

    /// The page an entry starts on.
    static func pageIndex(of entryID: UUID, in pages: [Page]) -> Int? {
        pages.first { page in page.blocks.contains { $0.entryID == entryID } }?.index
    }

    /// The page holding part `part` of an entry. If the entry now runs to fewer parts (a larger
    /// text size, say), the page holding its last part.
    static func pageIndex(of entryID: UUID, part: Int, in pages: [Page]) -> Int? {
        pages.last { page in page.blocks.contains { $0.entryID == entryID && $0.part <= part } }?.index
    }

    /// Resolve an original text location after reflow. Empty/photo-only tails also have offsets.
    static func pageIndex(of entryID: UUID, textOffset: Int, in pages: [Page]) -> Int? {
        pages.last { page in
            page.blocks.contains { $0.entryID == entryID && $0.textOffset <= textOffset }
        }?.index
    }

    /// The page each entry starts on, for a table of contents.
    static func startPages(in pages: [Page]) -> [UUID: Int] {
        var starts: [UUID: Int] = [:]
        for page in pages {
            for block in page.blocks where starts[block.entryID] == nil {
                starts[block.entryID] = page.index
            }
        }
        return starts
    }

    // MARK: Measuring

    /// Keep source slices, including whitespace: synthetic line breaks must never change words.
    /// Core Text measures the same bundled face used by the reader. The character-capacity
    /// initializer stays deterministic for unit tests and callers without a rendered page size.
    private func sourceLines(in text: String) -> [Range<Int>] {
        if let width = measuredWidth {
            let font = CTFontCreateWithName("IM_FELL_English_Roman" as CFString, measuredFontSize, nil)
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font
            ])
            let typesetter = CTTypesetterCreateWithAttributedString(attributed as CFAttributedString)
            let length = (text as NSString).length
            var cursor = 0
            var result: [Range<Int>] = []
            while cursor < length {
                let suggested = CTTypesetterSuggestLineBreak(typesetter, cursor, width)
                let count = suggested > 0 ? suggested : (text as NSString).rangeOfComposedCharacterSequence(at: cursor).length
                let end = min(length, cursor + count)
                result.append(cursor..<end)
                cursor = end
            }
            return result
        }
        var result: [Range<Int>] = []
        var start = text.startIndex
        while start < text.endIndex {
            var end = start
            var lastSpace: String.Index?
            var count = 0
            while end < text.endIndex && count < charactersPerLine {
                let character = text[end]
                end = text.index(after: end)
                count += 1
                if character.isWhitespace { lastSpace = end }
                if character.isNewline { break }
            }
            if end < text.endIndex, !text[text.index(before: end)].isNewline,
               !text[end].isWhitespace, let space = lastSpace {
                end = space
            }
            // Trailing spaces belong to this slice, but must not use the next line's capacity.
            while end < text.endIndex, text[end].isWhitespace, !text[end].isNewline,
                  !text[text.index(before: end)].isNewline {
                end = text.index(after: end)
            }
            result.append(start.utf16Offset(in: text)..<end.utf16Offset(in: text))
            start = end
        }
        return result
    }

    static func paragraphs(in text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func lineCount(of paragraph: String) -> Int {
        wrap(paragraph).count
    }

    /// Greedy word wrap into lines of at most `charactersPerLine` characters. A word longer than a
    /// line is broken across lines.
    func wrap(_ paragraph: String) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in paragraph.split(whereSeparator: \.isWhitespace).map(String.init) {
            var word = word
            while word.count > charactersPerLine {
                if !line.isEmpty {
                    lines.append(line)
                    line = ""
                }
                lines.append(String(word.prefix(charactersPerLine)))
                word = String(word.dropFirst(charactersPerLine))
            }
            if line.isEmpty {
                line = word
            } else if line.count + 1 + word.count <= charactersPerLine {
                line += " " + word
            } else {
                lines.append(line)
                line = word
            }
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }
}

extension JournalPager.Item {
    init(entry: Entry, locale: Locale = .current) {
        id = entry.id
        heading = entry.heading(locale: locale)
        place = entry.place
        body = entry.body
        hasPhotos = !(entry.photos ?? []).isEmpty
    }
}
