# iPad and native Mac

The universal iOS app targets iPhone and iPad (iOS/iPadOS 17+). CI runs the normal smoke suite on both, plus iPad rotation/spread acceptance, and exports screenshots. Portrait and narrow windows use one page; landscape windows at least 960 points wide use two. Simulator checks do not replace #30: real keyboard, VoiceOver, Stage Manager, camera, signing and two-device iCloud acceptance remain manual.

## Native Mac

Open `GamingJournal.xcodeproj` on a Mac and select **Hearthbound (Mac)**. This is a native macOS 14+ SwiftUI/AppKit target, not Catalyst. **Hearthbound (Mac Free Team)** uses the existing `.free` identities with iCloud disabled. CI builds/tests the standard Mac scheme; free-team signing needs a device-side check.

The Mac target shares models, migrations, local storage, optional iCloud sync, journal reading/writing, search, draft recovery, contents, bookmarks, JSON backup/import, Markdown/PDF export, photo processing and the visual theme. Native sheets, file photo import and system image sharing replace iOS presentation. The reader uses the shared pagination and arrow-key controls without a page curl. One resizable window is intentional to avoid simultaneous editors overwriting the same saved draft.

The iOS bundle IDs, widgets and cloud container have not been renamed. The native Mac app uses the same main bundle identity and CloudKit container. Signed distribution must provision the Mac app group, iCloud and push capabilities. CI uses unsigned, isolated in-memory app data and cannot validate signing, iCloud, Touch ID or notification delivery.

Mac limits: no camera capture or Control Center button.

Mac desktop widgets (#239) come from `GamingJournalMacWidgets`, a macOS app-extension target built from the same `GamingJournalWidgets` folder as iOS and embedded in both Mac schemes. It offers Write in…, the latest entry and On This Day at the system sizes. The Lock Screen accessory sizes and the Control Center button stay iOS-only. Clicking a widget opens the app through the `gamingjournal://` links. When the journal lock is on, the widgets show no writing, as on iOS.

The widgets read the snapshot the app writes into the app group's shared `UserDefaults`. The paid Mac build uses `group.com.gamingjournal.GamingJournal`. A free personal team can't be granted a `group.`-prefixed group on Mac (#234), so **Hearthbound (Mac Free Team)** uses `$(TeamIdentifierPrefix)com.gamingjournal.GamingJournal.free`, which macOS allows without a provisioning profile. The `APP_GROUP` build setting fills in the `AppGroup` Info.plist key, so the code knows the team-specific name. The journal store stays in the app's own container (`groupContainer: .none`), where free-build journals were saved before the group existed. Check on a Mac: the widgets appear in the gallery, show the latest entry and memories, open the right journal or entry when clicked, and go blank when the lock is on.

The Mac journal lock (#238) shares iOS's `AppLock` and asks for Touch ID or the login password. When on, the app opens sealed and seals again when it's hidden, its window is minimised or closed, the screen locks or sleeps, or another user takes over; switching to another app leaves it open. While sealed, the window and every open sheet show the closed shelf, their content is disabled and hidden from VoiceOver, and the journal menu commands are off. It needs no entitlement, so the Mac Free Team scheme can test it. Check on a Mac: each sealing trigger, that the unlock prompt comes back once (not in a loop) after a cancel, that a sheet left open (the writer, Settings) is covered, and whether the Dock thumbnail of a minimised window shows a page. Test Shortcuts/Spotlight, notifications, Photos library authorization, native sharing and sandboxed file dialogs on a signed build. Confirm import/export round trips and cross-device edits/deletes/photos with a test iCloud account before release.

## Validation

CI first builds/tests the native Mac scheme with shared unit tests and Mac-specific UI smoke tests. It then runs iPhone and iPad on the same runner, reusing the iOS build and keeping simulator parallel testing disabled. Artifacts separate screenshots by platform. No release or tag is authorized by these changes.

## Writing and recovery

Each journal has a **Calendar** in its editor: Tamriel, Forgotten Realms, Real-world, Day count or Free text. It sets the date hint, gives the first page a starting date, and is suggested from the game's name for a new journal ("Skyrim" picks Tamriel). Dates stay free text, **Next day** steps any recognised date, and changing the calendar never alters written pages. Journals from before calendars show the calendar their latest date is written in when edited.

New entry text, date and place are kept locally while writing. **Keep Draft** returns to the book without publishing the entry; the shelf shows **Continue unfinished page**. Resolve an existing unfinished page before beginning another. Pictures are retained only by saving the entry, and edits to an existing entry are retained only by saving; the writer explains both limits. Keep Draft asks before leaving attached pictures behind.

Saving waits for picture imports to finish. Import progress and failed picture names are shown, and successful pictures stay available when another fails. On Mac, use Photos, the file picker or drop picture files onto the writer. Failed entry/journal saves keep the editor open for retry. PDF/Markdown write failures are reported separately from cancellation.

On Mac, the menus expose Settings (Command-comma), New Journal (Command-Shift-N), Write Entry (Command-N) and Find (Command-F). Commands are unavailable while editing a sheet. The bookshelf control returns from the reader; page arrows turn pages. New bookmarks and manual page turns preserve an entry text location during reflow; old bookmarks remain readable. The writing control has reserved space below the page, and unusually tall content includes a scroll hint.

## Shelf

Each cover shows the character in gilt on a title plate, with the latest entry's in-game date beneath; the journal opened last on this device carries a ribbon. Choosing a journal brings the book forward and swings its cover open onto the reader in about half a second. Reduce Motion skips this and opens the reader directly, and UI tests skip it too so their screenshots never catch it mid-way, so check the movement by hand on iPhone, iPad and Mac. An empty shelf offers a blank book to **Begin a new journal**.
