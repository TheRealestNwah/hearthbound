import AppIntents
import SwiftUI
import WidgetKit

/// Mirror of the app's `QuickWriteRoster`: the journals the app keeps in the App Group.
struct Roster: Codable {
    static let key = "quickWriteRoster"

    struct Book: Codable {
        var id: UUID
        var characterName: String
        var epithet: String
        var gameTitle: String
    }

    var journals: [Book]

    static func load() -> Roster {
        guard let data = UserDefaults(suiteName: Snapshot.appGroup)?.data(forKey: key),
              let roster = try? JSONDecoder().decode(Roster.self, from: data)
        else { return Roster(journals: []) }
        return roster
    }
}

// MARK: Configuration

struct WidgetJournal: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journal")
    static let defaultQuery = WidgetJournalQuery()

    let id: UUID
    let characterName: String
    let gameTitle: String

    init(_ journal: Roster.Book) {
        id = journal.id
        characterName = journal.characterName
        gameTitle = journal.gameTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(characterName)", subtitle: "\(gameTitle)")
    }
}

struct WidgetJournalQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetJournal] {
        Roster.load().journals.filter { identifiers.contains($0.id) }.map(WidgetJournal.init)
    }

    func suggestedEntities() async throws -> [WidgetJournal] {
        Roster.load().journals.map(WidgetJournal.init)
    }

    func defaultResult() async -> WidgetJournal? {
        Roster.load().journals.first.map(WidgetJournal.init)
    }
}

struct WriteAsConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Write in"
    static let description = IntentDescription("Open a new page in a character's journal.")

    @Parameter(title: "Journal")
    var journal: WidgetJournal?
}

// MARK: Widget

struct WriteAsEntry: TimelineEntry {
    let date: Date
    let journal: WidgetJournal?
}

struct WriteAsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WriteAsEntry {
        WriteAsEntry(date: .now, journal: nil)
    }

    func snapshot(for configuration: WriteAsConfiguration, in context: Context) async -> WriteAsEntry {
        WriteAsEntry(date: .now, journal: await resolve(configuration))
    }

    func timeline(for configuration: WriteAsConfiguration, in context: Context) async -> Timeline<WriteAsEntry> {
        // The app reloads this widget whenever the journals change.
        Timeline(entries: [WriteAsEntry(date: .now, journal: await resolve(configuration))], policy: .never)
    }

    /// The chosen journal if it's still on the shelf, else the most recent one.
    private func resolve(_ configuration: WriteAsConfiguration) async -> WidgetJournal? {
        let journals = Roster.load().journals
        if let chosen = configuration.journal, let current = journals.first(where: { $0.id == chosen.id }) {
            return WidgetJournal(current)
        }
        return journals.first.map(WidgetJournal.init)
    }
}

/// A character's journal on the Home or Lock Screen (or the Mac desktop): tap to write in it.
struct WriteAsWidget: Widget {
    static let kind = "WriteAs"
    #if os(iOS)
    static let families: [WidgetFamily] = [.systemSmall, .accessoryCircular, .accessoryRectangular]
    #else
    static let families: [WidgetFamily] = [.systemSmall]
    #endif

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: WriteAsConfiguration.self, provider: WriteAsProvider()) { entry in
            WriteAsView(entry: entry)
                .containerBackground(for: .widget) { Page.background }
                .widgetURL(entry.journal.map { Snapshot.writeURL(for: $0.id) } ?? Snapshot.writeURL)
        }
        .configurationDisplayName("Write in…")
        .description("Open a new page in a character's journal.")
        .supportedFamilies(Self.families)
    }
}

struct WriteAsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WriteAsEntry

    private var name: String { entry.journal?.characterName ?? "Your journal" }

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "pencil.and.scribble")
                    Text(initials)
                        .font(.caption2.weight(.semibold))
                }
            }
            .accessibilityLabel("Write in \(name)'s journal")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Write in", systemImage: "pencil.and.scribble")
                    .font(.caption2)
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                if let game = entry.journal?.gameTitle, !game.isEmpty {
                    Text(game)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        #endif
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "pencil.and.scribble")
                    .font(.title2)
                    .foregroundStyle(Page.rubric)
                Spacer(minLength: 0)
                Text("The journal of")
                    .font(Page.bookItalic(13, relativeTo: .caption))
                    .foregroundStyle(Page.faded)
                Text(name)
                    .font(Page.book(18, relativeTo: .headline))
                    .foregroundStyle(Page.ink)
                    .lineLimit(2)
                if entry.journal == nil {
                    Text("Begin one in the app.")
                        .font(Page.bookItalic(12, relativeTo: .caption))
                        .foregroundStyle(Page.faded)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var initials: String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        return letters.compactMap { $0?.first.map(String.init) }.joined().uppercased()
    }
}

// MARK: Control

#if os(iOS)
/// Control Center and Lock Screen button that opens a new page (iOS 18).
@available(iOS 18.0, *)
struct WriteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "WriteControl") {
            ControlWidgetButton(action: OpenURLIntent(Snapshot.writeURL)) {
                Label("Write in Journal", systemImage: "pencil.and.scribble")
            }
        }
        .displayName("Write in Journal")
        .description("Open a new page in your latest journal.")
    }
}
#endif
