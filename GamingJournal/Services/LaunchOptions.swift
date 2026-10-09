import Foundation
import SwiftData

/// Launch arguments used by UI tests.
enum LaunchOptions {
    /// In-memory store and throwaway settings, so tests start clean and leave nothing behind.
    static let uiTestingArgument = "-uiTesting"
    /// Seeds the sample journal.
    static let demoDataArgument = "-demoData"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var seedsDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains(demoDataArgument)
    }

    /// `-appearance light|dark`: screenshots of both looks whatever the test machine uses.
    static var appearance: String? {
        isUITesting ? UserDefaults.standard.string(forKey: "appearance") : nil
    }

    /// `-largeText YES`: an accessibility text size, to check text wraps rather than clips.
    static var largeText: Bool {
        isUITesting && UserDefaults.standard.bool(forKey: "largeText")
    }

    /// `-compactWindow YES`: opens the Mac window at its smallest size.
    static var compactWindow: Bool {
        isUITesting && UserDefaults.standard.bool(forKey: "compactWindow")
    }

    /// Fresh, empty defaults for a UI-test launch.
    static func uiTestingDefaults() -> UserDefaults {
        let name = "GamingJournal.uiTesting"
        UserDefaults().removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }
}

/// Sample data for UI tests and previews.
enum DemoData {
    @MainActor
    static func seed(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let sample = journal(now: now, calendar: calendar)
        // UI-only fixture: enough text to exercise many spreads at any iPad size.
        if LaunchOptions.isUITesting && ProcessInfo.processInfo.arguments.contains("-longDemoData"),
           let first = sample.story.first {
            first.body += (1...35).map {
                "\n\nMilestone \($0). The mountain road wound through the snow. I stopped at the old watchtower and recorded the landmarks before continuing toward the river."
            }.joined()
        }
        if LaunchOptions.isUITesting && ProcessInfo.processInfo.arguments.contains("-missingPhoto") {
            sample.latestEntry?.photos = [EntryPhoto(imageData: nil, thumbnailData: nil)]
        }
        context.insert(sample)
        try? context.save()
    }

    /// Eira Stormborn's first days in Skyrim.
    static func journal(now: Date = .now, calendar: Calendar = .current) -> Journal {
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }
        let journal = Journal(characterName: "Eira Stormborn", epithet: "Nord", gameTitle: "Skyrim",
                              coverStyle: .ember, calendar: .tamriel, createdAt: daysAgo(5))
        journal.entries = [
            Entry(body: "The cart ride ended at a headsman's block. Then the sky tore open and a dragon came down on Helgen. I ran with a stranger named Ralof and did not look back at the smoke.",
                  inGameDate: "16th of Last Seed, 4E 201", writtenAt: daysAgo(4)),
            Entry(body: "Riverwood. The smith's wife fed me and asked no questions. I owe these people a warning, so tomorrow I walk to Whiterun and tell the Jarl what I saw.",
                  inGameDate: "17th of Last Seed, 4E 201", writtenAt: daysAgo(3)),
            Entry(body: "Bleak Falls Barrow was colder than any grave should be. I found the dragonstone, and a wall that spoke to me in a tongue I have never learned.",
                  inGameDate: "20th of Last Seed, 4E 201", writtenAt: daysAgo(1)),
        ]
        journal.updatedAt = daysAgo(1)
        return journal
    }
}
