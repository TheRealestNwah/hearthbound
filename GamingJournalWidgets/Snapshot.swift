import CoreText
import Foundation
import SwiftUI

/// Mirror of the app's `WidgetSnapshot`, which the app writes into the shared App Group.
struct Snapshot: Codable {
    #if FREE_TEAM && os(macOS)
    /// A free team can only share a Mac group named after its own team ID, which the build fills in.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String ?? "group.com.gamingjournal.GamingJournal.free"
    #elseif FREE_TEAM
    static let appGroup = "group.com.gamingjournal.GamingJournal.free"
    #else
    static let appGroup = "group.com.gamingjournal.GamingJournal"
    #endif
    static let key = "widgetSnapshot"
    static let writeURL = URL(string: "gamingjournal://write")!

    /// Mirror of the app's `WidgetSnapshot.entryURL(for:)`.
    static func entryURL(for entryID: UUID) -> URL {
        var components = URLComponents(string: "gamingjournal://entry")!
        components.queryItems = [URLQueryItem(name: "id", value: entryID.uuidString)]
        return components.url!
    }

    /// Mirror of the app's `WidgetSnapshot.writeURL(for:)`.
    static func writeURL(for journalID: UUID) -> URL {
        var components = URLComponents(url: writeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "journal", value: journalID.uuidString)]
        return components.url!
    }

    struct LatestEntry: Codable {
        var journalID: UUID
        var characterName: String
        var heading: String
        var place: String?
        var excerpt: String
        var writtenAt: Date
        var entryID: UUID?
    }

    struct DayMemory: Codable {
        var day: Date
        var entry: LatestEntry
    }

    var generatedAt: Date
    var latestEntry: LatestEntry?
    var memories: [DayMemory]?

    static let placeholder = Snapshot(
        generatedAt: .now,
        latestEntry: LatestEntry(
            journalID: UUID(),
            characterName: "Eira Stormborn",
            heading: "17th of Last Seed, 4E 201",
            place: "Riverwood",
            excerpt: "Riverwood. The smith's wife fed me and asked no questions.",
            writtenAt: .now
        )
    )

    static func load() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Snapshot.self, from: data)
    }
}

/// The app's page colours and book face (IM Fell English, bundled with the extension), for widgets.
enum Page {
    /// Registers the bundled fonts once per extension process.
    static let fontsRegistered: Bool = {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    static let paper = [Color(red: 0.94, green: 0.89, blue: 0.78), Color(red: 0.86, green: 0.77, blue: 0.60)]
    static let ink = Color(red: 0.18, green: 0.13, blue: 0.09)
    static let faded = Color(red: 0.37, green: 0.27, blue: 0.19)
    static let rubric = Color(red: 0.48, green: 0.18, blue: 0.11)

    static func book(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        _ = fontsRegistered
        return .custom("IM_FELL_English_Roman", size: size, relativeTo: style)
    }

    static func bookItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        _ = fontsRegistered
        return .custom("IM_FELL_English_Italic", size: size, relativeTo: style)
    }

    static func bookCaps(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        _ = fontsRegistered
        return .custom("IM_FELL_English_SC", size: size, relativeTo: style)
    }

    static var background: some View {
        LinearGradient(colors: paper, startPoint: .top, endPoint: .bottom)
    }
}
