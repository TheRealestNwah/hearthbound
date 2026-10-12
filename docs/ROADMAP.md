# Roadmap

## Vision

The journal your character keeps, like the in-game journal in Skyrim or Morrowind. One journal per character; each is a book of dated entries on aged pages, turned like a book. Writing is a blank page: the in-game date, the words, maybe a picture. Nothing else on screen.

All data is entered by hand; there is no online game database and no account.

## Data model

| Model | Key fields |
|---|---|
| **Journal** (one character) | character name, race/class/title, game, cover colour |
| **Entry** | text, in-game date, place, date written, pictures |

A journal's ribbon is kept per device in UserDefaults, not in the model.

## Built

| Item | Issue |
|------|-------|
| Journals and entries on a fresh, simpler data model | #116 |
| Journal shelf, paged reader and writer in the in-game journal style | #117 |
| Widgets, Siri, Spotlight, reminders, backup and export for journals | #118 |
| Remove the party, emotions, bonds, chapters, stats and play sessions | #119 |
| IM Fell English, the old-book font | #121 |
| Search entries across journals | #123 |
| Contents page to jump to an entry | #124 |
| Ribbon bookmark so a journal reopens where you left off | #125 |
| Pictures in the PDF book export | #126 |
| More in-game calendars for Next day (Harptos, real-world dates) | #144 |
| Share an entry as a picture of its page | #145 |
| Two facing pages on iPad | #146 |
| A place line under an entry's date | #147 |
| Take a picture with the camera in the writer | #148 |
| Show what was written a year ago | #149 |
| Undo tearing out an entry | #150 |
| Change the date an entry is filed under | #151 |
| Highlight search words on the page a result opens | #152 |
| Turn pages with the arrow keys | #153 |
| Turn pages with a page curl | #154 |
| Export the PDF book without freezing the app | #155 |
| Make the reader easier to use with VoiceOver | #156 |
| Lock the native Mac app with Touch ID or the login password | #238 |
| Desktop widgets for the native Mac app | #239 |

## Platform expansion

- #185: iPad smoke tests, rotation/facing-page acceptance and screenshot artifacts in CI.
- #186: native macOS 14+ SwiftUI/AppKit target sharing the journal implementation. See [platform details and limits](PLATFORMS.md).

## Validation still needed

The approved September 2026 feature list is implemented. Simulator CI checks builds, service
tests and core UI flows; it does not prove real-device behavior. The remaining acceptance work
is tracked in [#30](https://github.com/TheRealestNwah/hearthbound/issues/30): camera and photo
permissions, widget timelines and links, hardware keyboard navigation, VoiceOver, page curls,
iPad resizing, signing, and two-device iCloud sync. The Free Team scheme is not built
by CI.

The On This Day widget prepares seven days of memories when the app opens or its writing
changes. It clears expired memories; reopen the app to prepare the next week. Exact anniversaries
take priority, otherwise it shows the oldest entry within three days of the date in an earlier year.

No approved feature remains unimplemented on this roadmap. New features need a scoped issue.

## Ideas

Not planned yet; each needs the owner's go-ahead. None are waiting right now.

Removed on purpose, not coming back unless the owner asks: party, emotions, bonds, chapters, stats and play sessions.

Needs a human: on-device checks of widgets, photo picking and iCloud sync (#30).

## History

Before September 2026 Hearthbound was a notebook app with a party of characters, bonds, chapters, play sessions and stats (roadmap items R1–R27, issues #32–#76). The rebuild (#116–#119) replaced it with one plain journal per character; see the git history for the old roadmap.
