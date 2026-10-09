import Foundation

/// Moves a typed in-game date on by a day, so a new entry can start from "the next day". It
/// understands the Elder Scrolls calendar ("Sundas, 16th of Last Seed, 4E 201"), the Forgotten
/// Realms' Calendar of Harptos ("15 Mirtul, 1492 DR"), real-world dates as Fallout and the like
/// use them ("October 23, 2287") and simple day counts ("Day 12"); anything else is left for the
/// writer to change by hand.
enum InGameDate {
    struct Month {
        let name: String
        let days: Int
    }

    static let tamrielMonths: [Month] = [
        Month(name: "Morning Star", days: 31), Month(name: "Sun's Dawn", days: 28),
        Month(name: "First Seed", days: 31), Month(name: "Rain's Hand", days: 30),
        Month(name: "Second Seed", days: 31), Month(name: "Midyear", days: 30),
        Month(name: "Sun's Height", days: 31), Month(name: "Last Seed", days: 31),
        Month(name: "Hearthfire", days: 30), Month(name: "Frostfall", days: 31),
        Month(name: "Sun's Dusk", days: 30), Month(name: "Evening Star", days: 31),
    ]

    static let tamrielWeekdays = ["Sundas", "Morndas", "Tirdas", "Middas", "Turdas", "Fredas", "Loredas"]

    /// The day after `text`, or nil when the date isn't one it recognises.
    static func nextDay(after text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return nextTamrielDay(after: trimmed)
            ?? nextHarptosDay(after: trimmed)
            ?? nextGregorianDay(after: trimmed)
            ?? nextNumberedDay(after: trimmed)
    }

    /// The calendar `text` is written in, when it's one this can step on.
    static func calendar(of text: String) -> JournalCalendar? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if nextTamrielDay(after: trimmed) != nil { return .tamriel }
        if nextHarptosDay(after: trimmed) != nil { return .harptos }
        if nextGregorianDay(after: trimmed) != nil { return .realWorld }
        if nextNumberedDay(after: trimmed) != nil { return .dayCount }
        return nil
    }

    /// "1st", "2nd", "3rd", "4th", "11th", "22nd"…
    static func ordinal(_ day: Int) -> String {
        let suffix: String
        switch (day % 10, day % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(day)\(suffix)"
    }

    // MARK: Tamriel

    private static let tamrielPattern: NSRegularExpression = {
        let months = tamrielMonths.map { NSRegularExpression.escapedPattern(for: $0.name) }.joined(separator: "|")
        let weekdays = tamrielWeekdays.joined(separator: "|")
        // Optional weekday, day with an optional ordinal suffix, the month, then the rest (era, year).
        let pattern = "^(?:(\(weekdays)),\\s*)?(\\d{1,2})(?:st|nd|rd|th)?\\s+of\\s+(\(months))(.*)$"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let eraYear = try! NSRegularExpression(pattern: "(\\d+)\\s*E\\s*(?<year>\\d+)", options: [.caseInsensitive])

    private static func nextTamrielDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = tamrielPattern.firstMatch(in: text, range: range),
              let dayRange = Range(match.range(at: 2), in: text),
              let monthRange = Range(match.range(at: 3), in: text),
              let restRange = Range(match.range(at: 4), in: text),
              let day = Int(text[dayRange]),
              let monthIndex = tamrielMonths.firstIndex(where: { $0.name.caseInsensitiveCompare(String(text[monthRange])) == .orderedSame })
        else { return nil }

        var nextDay = day + 1
        var nextMonth = monthIndex
        var rest = String(text[restRange])
        if nextDay > tamrielMonths[monthIndex].days {
            nextDay = 1
            nextMonth = (monthIndex + 1) % tamrielMonths.count
            if nextMonth == 0 {
                rest = incrementingYear(in: rest)
            }
        }

        var result = "\(ordinal(nextDay)) of \(tamrielMonths[nextMonth].name)\(rest)"
        if let weekdayRange = Range(match.range(at: 1), in: text),
           let weekday = tamrielWeekdays.firstIndex(where: { $0.caseInsensitiveCompare(String(text[weekdayRange])) == .orderedSame }) {
            result = "\(tamrielWeekdays[(weekday + 1) % tamrielWeekdays.count]), \(result)"
        }
        return result
    }

    /// "…, 4E 201" becomes "…, 4E 202". `pattern` captures the year as `year`.
    private static func incrementingYear(in text: String, pattern: NSRegularExpression = eraYear) -> String {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              let yearRange = Range(match.range(withName: "year"), in: text),
              let year = Int(text[yearRange])
        else { return text }
        return text.replacingCharacters(in: yearRange, with: String(year + 1))
    }

    // MARK: Harptos

    /// The Forgotten Realms' months, 30 days each.
    static let harptosMonths = [
        "Hammer", "Alturiak", "Ches", "Tarsakh", "Mirtul", "Kythorn",
        "Flamerule", "Eleasis", "Eleint", "Marpenoth", "Uktar", "Nightal",
    ]

    /// Festival days that fall between two months, keyed by the month they follow. Shieldmeet,
    /// the leap day after Midsummer, is understood but never stepped onto.
    static let harptosFestivals: [String: String] = [
        "Hammer": "Midwinter", "Tarsakh": "Greengrass", "Flamerule": "Midsummer",
        "Eleint": "Highharvestide", "Uktar": "Feast of the Moon",
    ]

    private static let harptosPattern: NSRegularExpression = {
        let months = harptosMonths.joined(separator: "|")
        // Day with an optional ordinal suffix, an optional "of", the month, then the rest (year).
        let pattern = "^(\\d{1,2})(st|nd|rd|th)?\\s+(of\\s+)?(\(months))\\b(.*)$"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static let harptosFestivalPattern: NSRegularExpression = {
        let festivals = (Array(harptosFestivals.values) + ["Shieldmeet"]).map { NSRegularExpression.escapedPattern(for: $0) }
        return try! NSRegularExpression(pattern: "^(\(festivals.joined(separator: "|")))\\b(.*)$", options: [.caseInsensitive])
    }()

    private static let daleReckoningYear = try! NSRegularExpression(pattern: "(?<year>\\d+)\\s*DR", options: [.caseInsensitive])

    private static func nextHarptosDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if let match = harptosFestivalPattern.firstMatch(in: text, range: range),
           let festivalRange = Range(match.range(at: 1), in: text),
           let restRange = Range(match.range(at: 2), in: text) {
            let festival = text[festivalRange].lowercased()
            // Shieldmeet follows Midsummer, so both lead on to the month after Flamerule.
            let before = festival == "shieldmeet"
                ? "Flamerule"
                : harptosFestivals.first { $0.value.lowercased() == festival }?.key
            guard let before, let index = harptosMonths.firstIndex(of: before) else { return nil }
            return "1 \(harptosMonths[index + 1])\(text[restRange])"
        }

        guard let match = harptosPattern.firstMatch(in: text, range: range),
              let dayRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 4), in: text),
              let restRange = Range(match.range(at: 5), in: text),
              let day = Int(text[dayRange]), (1...30).contains(day),
              let monthIndex = harptosMonths.firstIndex(where: { $0.caseInsensitiveCompare(String(text[monthRange])) == .orderedSame })
        else { return nil }

        let month = harptosMonths[monthIndex]
        var rest = String(text[restRange])
        guard day == 30 else {
            let hasSuffix = match.range(at: 2).location != NSNotFound
            let of = match.range(at: 3).location != NSNotFound ? "of " : ""
            return "\(hasSuffix ? ordinal(day + 1) : String(day + 1)) \(of)\(month)\(rest)"
        }
        if let festival = harptosFestivals[month] {
            return festival + rest
        }
        let nextMonth = (monthIndex + 1) % harptosMonths.count
        if nextMonth == 0 {
            rest = incrementingYear(in: rest, pattern: daleReckoningYear)
        }
        return "1 \(harptosMonths[nextMonth])\(rest)"
    }

    // MARK: Real-world dates

    private static let gregorian = Calendar(identifier: .gregorian)
    private static let englishMonths = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    private static let englishWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// "October 23, 2287" (month first) or "23 October 2287" (day first), each with an optional
    /// weekday before it and an optional year after it.
    private static let gregorianPatterns: [NSRegularExpression] = {
        let months = englishMonths.joined(separator: "|")
        let weekdays = englishWeekdays.joined(separator: "|")
        let weekday = "(?:(?<weekday>\(weekdays)),?\\s+)?"
        let year = "(?:,?\\s+(?<year>\\d{3,5})\\b)?"
        return [
            "^\(weekday)(?<month>\(months))\\s+(?<day>\\d{1,2})(?<suffix>st|nd|rd|th)?\\b\(year)",
            "^\(weekday)(?<day>\\d{1,2})(?<suffix>st|nd|rd|th)?\\s+(?:of\\s+)?(?<month>\(months))\\b\(year)",
        ].map { try! NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static func nextGregorianDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = gregorianPatterns.lazy.compactMap({ $0.firstMatch(in: text, range: range) }).first,
              let dayRange = Range(match.range(withName: "day"), in: text),
              let monthRange = Range(match.range(withName: "month"), in: text),
              let day = Int(text[dayRange]),
              let monthIndex = englishMonths.firstIndex(where: { $0.caseInsensitiveCompare(String(text[monthRange])) == .orderedSame })
        else { return nil }
        let yearRange = Range(match.range(withName: "year"), in: text)
        let year = yearRange.flatMap { Int(text[$0]) }

        // Without a year, February is taken to have 28 days.
        guard let today = gregorian.date(from: DateComponents(year: year ?? 2001, month: monthIndex + 1, day: day)),
              gregorian.component(.day, from: today) == day,
              let tomorrow = gregorian.date(byAdding: .day, value: 1, to: today)
        else { return nil }
        let next = gregorian.dateComponents([.year, .month, .day], from: tomorrow)
        guard let nextDay = next.day, let nextMonth = next.month else { return nil }

        // Change each part where it's written, so the date keeps the writer's own style.
        // The day's ordinal suffix is replaced along with it ("4th" → "5th").
        let suffixRange = Range(match.range(withName: "suffix"), in: text)
        var changes: [(range: Range<String.Index>, text: String)] = [
            (dayRange.lowerBound..<(suffixRange?.upperBound ?? dayRange.upperBound),
             suffixRange != nil ? ordinal(nextDay) : String(nextDay)),
            (monthRange, englishMonths[nextMonth - 1]),
        ]
        if let yearRange, let nextYear = next.year, year != nil {
            changes.append((yearRange, String(nextYear)))
        }
        if let weekdayRange = Range(match.range(withName: "weekday"), in: text),
           let weekday = englishWeekdays.firstIndex(where: { $0.caseInsensitiveCompare(String(text[weekdayRange])) == .orderedSame }) {
            changes.append((weekdayRange, englishWeekdays[(weekday + 1) % englishWeekdays.count]))
        }
        var result = text
        for change in changes.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            result.replaceSubrange(change.range, with: change.text)
        }
        return result
    }

    // MARK: Day counts

    private static let dayPattern = try! NSRegularExpression(pattern: "^(day)\\s+(\\d+)(.*)$", options: [.caseInsensitive])

    private static func nextNumberedDay(after text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = dayPattern.firstMatch(in: text, range: range),
              let wordRange = Range(match.range(at: 1), in: text),
              let numberRange = Range(match.range(at: 2), in: text),
              let restRange = Range(match.range(at: 3), in: text),
              let number = Int(text[numberRange])
        else { return nil }
        return "\(text[wordRange]) \(number + 1)\(text[restRange])"
    }
}
