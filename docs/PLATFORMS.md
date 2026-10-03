# iPad and native Mac

The universal iOS app targets iPhone and iPad (iOS/iPadOS 17+). CI runs the normal smoke suite on both, plus iPad rotation/spread acceptance, and exports screenshots. Portrait and narrow windows use one page; landscape windows at least 960 points wide use two. Simulator checks do not replace #30: real keyboard, VoiceOver, Stage Manager, camera, signing and two-device iCloud acceptance remain manual.

## Native Mac

Open `GamingJournal.xcodeproj` on a Mac and select **Hearthbound (Mac)**. This is a native macOS 14+ SwiftUI/AppKit target, not Catalyst. **Hearthbound (Mac Free Team)** uses the existing `.free` identities with iCloud disabled. CI builds/tests the standard Mac scheme; free-team signing needs a device-side check.

The Mac target shares models, migrations, local storage, optional iCloud sync, journal reading/writing, search, draft recovery, contents, bookmarks, JSON backup/import, Markdown/PDF export, photo processing and the visual theme. Native sheets, file photo import and system image sharing replace iOS presentation. The reader uses the shared pagination and arrow-key controls without a page curl. One resizable window is intentional to avoid simultaneous editors overwriting the same saved draft.

The iOS bundle IDs, widgets and cloud container have not been renamed. The native Mac app uses the same main bundle identity and CloudKit container. Signed distribution must provision the Mac app group, iCloud and push capabilities. CI uses unsigned, isolated in-memory app data and cannot validate signing, iCloud, Touch ID or notification delivery.

Initial Mac limits: no app-lock UI, camera capture or desktop widget extension. iOS locking stays unchanged. Mac lock/privacy coverage and desktop widgets need their own implementation and acceptance before being advertised. Test Shortcuts/Spotlight, notifications, Photos library authorization, native sharing and sandboxed file dialogs on a signed build. Confirm import/export round trips and cross-device edits/deletes/photos with a test iCloud account before release.

## Validation

CI first builds/tests the native Mac scheme with shared unit tests and Mac-specific UI smoke tests. It then runs iPhone and iPad on the same runner, reusing the iOS build and keeping simulator parallel testing disabled. Artifacts separate screenshots by platform. No release or tag is authorized by these changes.

## Writing and recovery

New entry text, date and place are kept locally while writing. **Keep Draft** returns to the book without publishing the entry; the shelf shows **Continue unfinished page**. Resolve an existing unfinished page before beginning another. Pictures are retained only by saving the entry, and edits to an existing entry are retained only by saving; the writer explains both limits. Keep Draft asks before leaving attached pictures behind.

Saving waits for picture imports to finish. Import progress and failed picture names are shown, and successful pictures stay available when another fails. On Mac, use Photos, the file picker or drop picture files onto the writer. Failed entry/journal saves keep the editor open for retry. PDF/Markdown write failures are reported separately from cancellation.

On Mac, the menus expose Settings (Command-comma), New Journal (Command-Shift-N), Write Entry (Command-N) and Find (Command-F). Commands are unavailable while editing a sheet. The bookshelf control returns from the reader; page arrows turn pages. New bookmarks and manual page turns preserve an entry text location during reflow; old bookmarks remain readable. The writing control has reserved space below the page, and unusually tall content includes a scroll hint.
