# Hearthbound — iPhone, iPad and Mac

The journal your character keeps, like the one in an Elder Scrolls game. Start a journal for each character you play, and write their days in their own words: dated in the game's own calendar, on aged pages you turn like a book.

Everything lives on-device (SwiftData), with optional iCloud sync. No account and no online game database; you write everything yourself.

> **Built with AI.** Hearthbound's code, tests and documentation were written by
> Claude and OpenAI Codex, directed by the maintainer.
> See [AI disclosure](#ai-disclosure).

<p align="center">
  <img src="docs/screenshots/shelf.png" width="23%" alt="The shelf of journals">
  <img src="docs/screenshots/journal.png" width="23%" alt="A journal page with dated entries">
  <img src="docs/screenshots/contents.png" width="23%" alt="The contents page">
  <img src="docs/screenshots/writer.png" width="23%" alt="Writing a new entry">
</p>

<p align="center">
  <img src="docs/screenshots/ipad-journal.png" width="58%" alt="A journal on iPad">
  <img src="docs/screenshots/mac-journal.png" width="38%" alt="A journal on the native Mac app">
</p>

## Features

- **A shelf of journals**, one per character, each a leather-bound book with the character's name, race or class, and game. Search (magnifying glass), a new journal (+) and Settings sit in the top bar.
- **Pages you turn**: entries read like a book, under their in-game date ("16th of Last Seed, 4E 201") and optional place. The ← / → arrows, a swipe, or hardware arrow keys turn the page with a curl; Reduce Motion uses a plain slide for swipes and immediate button turns. Wide landscape iPads show two facing pages. VoiceOver supports heading navigation and page-turn gestures and announces the page number.
- **Find your place**: a **Contents** page lists every entry with its page number, and a **ribbon** marks your place so the journal reopens there (otherwise it opens on the latest page). Search from the shelf or Contents; matching words on the opened page are highlighted until you turn away.
- **A blank page to write on**: the in-game date (with a **Next day** button for Elder Scrolls, Harptos, real-world dates and numbered days), the place, the words (the keyboard's own mic dictates), and pictures from the library or camera. Tap an entry on the page to amend it. Unfinished pages are kept if the app closes; after deleting an entry, **Undo** briefly restores it with its pictures.
- **Around iOS**: a latest-entry widget, a "Write in…" widget for a chosen journal, a Control Center button, **Siri and Shortcuts** ("Write as Eira in Hearthbound"), **Spotlight**, and an optional evening **reminder**.
- **On This Day**: a widget opens an entry from the same date in a past year, or the oldest entry within three days of that date. The app prepares a week of memories when opened; reopen it to prepare another week. Expired memories clear automatically.
- **Face ID lock** (optional). While locked, widgets and Spotlight hide your writing.
- **Share and export**: share an entry's opening words and first picture as an aged-paper image, or export the complete journal as a **PDF book** or **Markdown**. PDF typesetting runs in the background with a progress indicator. A JSON **backup** of everything imports without duplicating.

**Look and feel**: aged paper and ink, red rubric dates, IM Fell English throughout (an old-book face by Igino Marini, SIL Open Font License); the shelf is dark wood with gilt. Pages stay paper in dark mode, dimmed like a book read by candlelight.

## Status

Rebuilt around one journal per character (#116–#119), with the approved September roadmap features implemented. See [the roadmap](docs/ROADMAP.md) and the [real-device checklist](https://github.com/TheRealestNwah/hearthbound/issues/30) for validation still needed. Simulator CI does not verify signing, camera capture, VoiceOver gestures or two-device iCloud sync.

## Requirements

- Xcode 16+
- iOS/iPadOS 17+, or macOS 14+ for the native Mac app

## Building

The app used to be called Gaming Journal. The Xcode project, targets, schemes, bundle IDs, app group and iCloud container keep the `GamingJournal` names, so existing data, widgets and sync keep working.

Open `GamingJournal.xcodeproj` and run the `GamingJournal` scheme, or from the command line:

```sh
xcodebuild test -project GamingJournal.xcodeproj -scheme GamingJournal \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

The project uses Xcode's synchronized folders, so new files under `GamingJournal/` and `GamingJournalTests/` are picked up automatically.

## Native Mac

Select **Hearthbound (Mac)** and the **My Mac** destination in Xcode. The native SwiftUI/AppKit app shares the journal data model and core features with iOS. It uses a resizable window, desktop sheets, arrow-key page turns, picture import from files, and native sharing. Command-Return saves writing.

```sh
xcodebuild test -project GamingJournal.xcodeproj -scheme "Hearthbound (Mac)" \
  -destination 'platform=macOS' -parallel-testing-enabled NO
```

The first Mac version does not offer app locking, camera capture or desktop widgets. Signing, Photos/Spotlight/Shortcuts, reminders and iCloud require hands-on acceptance before release. See [platform support and validation](docs/PLATFORMS.md). **Hearthbound (Mac Free Team)** provides the separate `.free` configuration without iCloud or push; its signing is not checked by CI.

## Running on your own device

With a paid Apple Developer team, pick it under Signing & Capabilities for the **GamingJournal** and **GamingJournalWidgets** targets and run the `GamingJournal` scheme.

With a free Apple ID, use the **Hearthbound (Free Team)** scheme instead:

1. Add your Apple ID in Xcode → Settings → Accounts.
2. Choose the **Hearthbound (Free Team)** scheme and your iPhone as the destination.
3. Under Signing & Capabilities, set Team to "(Your Name) Personal Team" for **GamingJournal** and **GamingJournalWidgets**.
4. Turn on Developer Mode on the iPhone (Settings → Privacy & Security), then Run. The first time, trust your profile under Settings → General → VPN & Device Management.

Step 3 has to happen in Xcode at least once: picking the team there is what registers the `.free` app group with Apple. Until then, command-line builds fail with "Provisioning profile … doesn't match the entitlements file's value for the com.apple.security.application-groups entitlement". Afterwards you can build and install without opening Xcode (replace the team ID and device ID with yours; `xcrun devicectl list devices` shows the device ID):

```sh
xcodebuild -project GamingJournal.xcodeproj -scheme "Hearthbound (Free Team)" -configuration FreeTeam \
  -destination "id=<device-id>" -derivedDataPath build DEVELOPMENT_TEAM=<team-id> -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> build/Build/Products/FreeTeam-iphoneos/GamingJournal.app
```

The Free Team build uses its own `.free` bundle IDs and app group, so a free team never claims the real identifiers. It leaves out iCloud and push, so the iCloud Sync setting is hidden, and apps signed by a free team stop opening after 7 days until you run them from Xcode again.

## iCloud sync

Sync is optional and off by default (Settings → iCloud Sync, applied on next launch). It mirrors the SwiftData store to the user's private CloudKit database (`iCloud.com.gamingjournal.GamingJournal`).

To use it you need:

- A paid Apple Developer team selected under Signing & Capabilities for the app and widget targets. The iCloud, Push Notifications and App Groups capabilities are already declared in the entitlements files.
- A real device (or simulator) signed in to iCloud. If the synced store can't be opened, the app falls back to on-device storage and says so in Settings.

CI builds without signing, so it only checks that sync compiles. Syncing between two devices has to be verified by hand.

## CI

GitHub Actions builds and runs shared unit tests, iPhone and iPad UI smoke tests, iPad rotation checks, and native Mac UI checks on every code pull request. Platform screenshots are attached to the run. PRs that only touch docs skip the build. To test `main` by hand, use "Run workflow".

## AI disclosure

Hearthbound was built with [Claude Code](https://claude.com/claude-code) and
[OpenAI Codex](https://openai.com/codex/). These tools contributed code, tests and
documentation under the direction of the maintainer
([@TheRealestNwah](https://github.com/TheRealestNwah)), who decides the product
direction and releases. Git history records the changes; the device checklist
tracks hands-on validation still outstanding.

## Support

Everything on my GitHub is free of charge and open source. If you find it
useful and want to leave a tip or buy me a coffee, you can do that at
[ko-fi.com/morrowheat23](https://ko-fi.com/morrowheat23). It's appreciated,
never expected.

## License

MIT — see [LICENSE](LICENSE).
