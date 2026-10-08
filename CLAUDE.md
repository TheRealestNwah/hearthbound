# Hearthbound — notes for Claude

iOS 17+ SwiftUI + SwiftData app: an in-game journal for each character you play, like the journal in an Elder Scrolls game. A shelf of journals (one per character); each reads like a book of dated entries on aged pages, turned with Prev / Next. Entries are just text, an in-game date and optional pictures. No accounts, no online game database.

The app is called **Hearthbound**. Its Xcode targets, schemes, bundle IDs, app group and iCloud container keep the old `GamingJournal` names on purpose: renaming them would cut off existing data, widgets and sync. Only user-facing text uses the new name.

## Layout
- `GamingJournal/Models/` — SwiftData models (versioned schema, CloudKit-compatible)
- `GamingJournal/Services/` — plain Swift logic (formatting, stats, export…); keep UI-free so it's unit-testable
- `GamingJournal/Views/<Feature>/` — SwiftUI views: `Shelf/` (home), `Journal/` (reader, writer), `Settings/`, `Theme/`
- `GamingJournalTests/` — XCTest unit tests
- The Xcode project uses synchronized folders: new files in these folders are picked up without editing `project.pbxproj`. Only new targets, entitlements or build settings need pbxproj edits.

## Rules
- **CI is the only build check.** Development happens on Windows, so nothing is compiled locally. Read the `xcodebuild-logs` artifact when a run fails.
- SwiftData models must stay CloudKit-safe: every property has a default or is optional, no `@Attribute(.unique)`, relationships optional. Add schema changes as a new `VersionedSchema` plus a migration stage.
- Put logic in `Services/` with tests; views stay thin. Page layout lives in `JournalPager`, in-game date stepping in `InGameDate`.
- Keep it simple: the direction is a plain in-game journal. The party, emotions, bonds, chapters, stats and play sessions were removed on purpose (#116–#119); don't bring them back without the owner asking.
- The `FreeTeam` build configuration (scheme **Hearthbound (Free Team)**) is for testing on a device with a free Apple ID: `.free` bundle IDs and app group, no iCloud or push, and the `FREE_TEAM` Swift condition. CI never builds it, so keep `#if FREE_TEAM` branches tiny, and add any new build setting or entitlement to it too.
- One issue per work item. When several items are green-lit together, build them on one branch and open one PR that closes all of them. A single item still gets its own PR. `main` is protected and requires the `Build & test (iOS Simulator)` check.

## Native Mac
- `Hearthbound (Mac)` is a native macOS 14+ SwiftUI/AppKit scheme sharing the app source folder. `Hearthbound (Mac Free Team)` mirrors free-team identities without cloud entitlements.
- Guard UIKit/AppKit differences at the platform boundary. Keep models, migrations and journal logic shared. See `docs/PLATFORMS.md` for features and manual acceptance.
- Mac currently has no app-lock UI, camera capture or widget extension. Do not imply those are supported.

## CI
- macOS runners are the bottleneck: only a few run at once, and every run holds one for ~5 min. Avoid pushing several PR branches at the same time. Push or rebase them one after another so they don't queue behind each other.
- CI runs on pull requests only (not on pushes to `main`). Docs-only PRs (`docs/`, `*.md`) skip the macOS job, and the skipped job still satisfies the required check. Use "Run workflow" (workflow_dispatch) to test `main` by hand.
- iPhone unit and UI smoke tests run in one `xcodebuild test-without-building` call on a simulator booted during the build. Parallel testing stays off, because cloning the simulator costs minutes while the suite takes seconds. Keep it that way when editing `.github/workflows/ci.yml`. The native Mac scheme runs its shared unit and Mac UI tests first on the same runner; iPhone follows, then iPad UI tests reuse the iOS build.

## Tone and theme
- The in-game journal look: aged paper with scorched edges, dark ink, red "rubric" ink for dates and actions; the shelf is dark wood with gilt. Pages stay paper in dark mode, just dimmer.
- Type is IM Fell English (SIL OFL, bundled in `GamingJournal/Fonts/` and `GamingJournalWidgets/Fonts/`, registered at launch by `BookFont.register()`) via `Theme.book` / `bookItalic` / `bookCaps`, scaled with Dynamic Type. It has no bold; small caps stand in.
- Use the tokens and components in `Views/Theme/` (`PaperBackground`, `ShelfBook`, `WaxSeal`, `PageRule`) rather than raw colours or fonts. `ThemeTests` checks WCAG AA contrast.
- Copy is in-world but clear ("Begin a new journal", "Take up the quill"). Every animation respects Reduce Motion.

## Conventions
- Issue and PR titles are plain sentence-case descriptions (no "M7:" / "R3:" prefixes). PR bodies start with `Closes #N` (one line per issue when a PR covers several), then `Roadmap: R3` when it applies.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).

## Codex
