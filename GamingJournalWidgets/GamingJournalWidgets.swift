import WidgetKit
import SwiftUI

@main
struct GamingJournalWidgetBundle: WidgetBundle {
    var body: some Widget {
        LatestEntryWidget()
        OnThisDayWidget()
        WriteAsWidget()
        #if os(iOS)
        if #available(iOS 18.0, *) {
            WriteControl()
        }
        #endif
    }
}

// MARK: Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : Snapshot.load()))
    }

    /// The app reloads the timeline whenever the latest entry changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: Snapshot.load())], policy: .never))
    }
}

// MARK: Latest entry

struct LatestEntryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LatestEntry", provider: SnapshotProvider()) { entry in
            LatestEntryView(entry: entry)
                .containerBackground(for: .widget) { Page.background }
                .widgetURL(entry.snapshot?.latestEntry.map { Snapshot.writeURL(for: $0.journalID) } ?? Snapshot.writeURL)
        }
        .configurationDisplayName("From the Journal")
        .description("The latest entry. Tap to write the next one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LatestEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let latest = entry.snapshot?.latestEntry {
            VStack(alignment: .leading, spacing: 5) {
                Text(latest.heading)
                    .font(Page.bookCaps(14, relativeTo: .caption))
                    .foregroundStyle(Page.rubric)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let place = latest.place, family != .systemSmall {
                    Text(place)
                        .font(Page.bookItalic(12, relativeTo: .caption))
                        .foregroundStyle(Page.faded)
                        .lineLimit(1)
                }
                Text(latest.excerpt)
                    .font(Page.book(family == .systemSmall ? 14 : 15))
                    .foregroundStyle(Page.ink)
                    .lineLimit(family == .systemSmall ? 5 : 4)
                Spacer(minLength: 0)
                Text("— \(latest.characterName)")
                    .font(Page.bookItalic(12, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundStyle(Page.rubric)
                Text("Begin a journal")
                    .font(Page.book(14))
                    .foregroundStyle(Page.ink)
            }
        }
    }
}

// MARK: On this day

struct MemoryEntry: TimelineEntry {
    let date: Date
    let memory: Snapshot.DayMemory?
}

/// Shows the memory the app picked for each coming day, moving on at midnight.
struct MemoryProvider: TimelineProvider {
    static let placeholder = Snapshot.DayMemory(day: .now, entry: Snapshot.placeholder.latestEntry!)

    func placeholder(in context: Context) -> MemoryEntry {
        MemoryEntry(date: .now, memory: Self.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoryEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.entries(from: Snapshot.load()).first ?? MemoryEntry(date: .now, memory: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoryEntry>) -> Void) {
        completion(Timeline(entries: Self.entries(from: Snapshot.load()), policy: .atEnd))
    }

    /// Seven days and a final empty day, so the last memory never stays on screen past its date.
    static func entries(from snapshot: Snapshot?, now: Date = .now, calendar: Calendar = .current) -> [MemoryEntry] {
        let today = calendar.startOfDay(for: now)
        let memories = snapshot?.memories ?? []
        return (0...7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let memory = offset < 7 ? memories.first { calendar.isDate($0.day, inSameDayAs: day) } : nil
            return MemoryEntry(date: offset == 0 ? now : day, memory: memory)
        }
    }
}

struct OnThisDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OnThisDay", provider: MemoryProvider()) { entry in
            OnThisDayView(entry: entry)
                .containerBackground(for: .widget) { Page.background }
                .widgetURL(entry.memory?.entry.entryID.map(Snapshot.entryURL(for:)))
        }
        .configurationDisplayName("On This Day")
        .description("What your characters wrote on this day in years past.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OnThisDayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MemoryEntry

    var body: some View {
        if let memory = entry.memory {
            VStack(alignment: .leading, spacing: 5) {
                Text(Self.when(memory))
                    .font(Page.bookItalic(12, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                    .lineLimit(1)
                Text(memory.entry.heading)
                    .font(Page.bookCaps(14, relativeTo: .caption))
                    .foregroundStyle(Page.rubric)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(memory.entry.excerpt)
                    .font(Page.book(family == .systemSmall ? 14 : 15))
                    .foregroundStyle(Page.ink)
                    .lineLimit(family == .systemSmall ? 4 : 3)
                Spacer(minLength: 0)
                Text("— \(memory.entry.characterName)")
                    .font(Page.bookItalic(12, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(Page.rubric)
                Text("Nothing was written on this day in years past.")
                    .font(Page.bookItalic(13, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// "One year ago today", "3 years ago this week".
    static func when(_ memory: Snapshot.DayMemory, calendar: Calendar = .current) -> String {
        let years = max(1, calendar.dateComponents([.year], from: memory.entry.writtenAt, to: memory.day.addingTimeInterval(4 * 86_400)).year ?? 1)
        let span = calendar.isDate(memory.entry.writtenAt, equalTo: memory.day, toGranularity: .day) || sameMonthAndDay(memory.entry.writtenAt, memory.day, calendar: calendar)
            ? "today" : "this week"
        return years == 1 ? "One year ago \(span)" : "\(years) years ago \(span)"
    }

    private static func sameMonthAndDay(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        let first = calendar.dateComponents([.month, .day], from: a)
        let second = calendar.dateComponents([.month, .day], from: b)
        return first.month == second.month && first.day == second.day
    }
}
