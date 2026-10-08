#if os(macOS)
import XCTest

final class MacSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(demo: Bool = false, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "YES", "-onboarding.completed", "YES",
            "-ApplePersistenceIgnoreState", "YES", "-NSTreatUnknownArgumentsAsOpen", "NO"]
            + (demo ? ["-demoData", "YES"] : []) + arguments
        app.launch()
        app.activate()
        let opened = app.windows.buttons.matching(identifier: "Begin a new journal").firstMatch.waitForExistence(timeout: 20)
        capture("mac-launch", app)
        XCTAssertTrue(opened, app.debugDescription)
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testCreateJournalWriteAndReadEntry() {
        let app = launch()
        app.windows.buttons.matching(identifier: "Begin a new journal").firstMatch.click()
        let name = app.windows.textFields["characterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.click()
        name.typeText("Mac traveller")
        app.windows.buttons.matching(identifier: "Begin").firstMatch.click()
        let quill = app.windows.buttons.matching(identifier: "Write a new entry").firstMatch
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        capture("mac-empty-reader", app)
        // Exercise a real pointer click on the visible control. SwiftUI's overlay
        // accessibility hit-test can disagree with the native view hit-test.
        print("Reader controls hittable: back=\(app.windows.buttons.matching(identifier: "Back to journals").firstMatch.isHittable), quill=\(quill.isHittable)")
        quill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let body = app.windows.textViews["entryBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        body.click()
        body.typeText("A page written beside the campfire.")
        capture("mac-writer", app)
        app.windows.buttons.matching(identifier: "Done").firstMatch.click()
        XCTAssertTrue(app.windows.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "A page written beside")).firstMatch.waitForExistence(timeout: 15))
        capture("mac-reader", app)
    }
    func testShelfSearchContentsAndSettings() {
        let app = launch(demo: true)
        capture("mac-shelf", app)
        app.windows.buttons.matching(identifier: "Search").firstMatch.click()
        let search = app.windows.textFields["Search the journals"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.click()
        search.typeText("dragonstone")
        let result = app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "wall that spoke")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "contents").firstMatch.waitForExistence(timeout: 15))
        app.windows.buttons.matching(identifier: "contents").firstMatch.click()
        let first = app.windows.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        capture("mac-contents", app)
        first.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Back to journals").firstMatch.waitForExistence(timeout: 15))
        app.windows.buttons.matching(identifier: "Back to journals").firstMatch.click()
        app.windows.buttons.matching(identifier: "Settings").firstMatch.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Export Backup").firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Import Backup").firstMatch.exists)
        capture("mac-settings", app)
        app.windows.buttons.matching(identifier: "Close").firstMatch.click()
    }
    func testMenuCommandsAndDraftRecoveryAfterFailedSave() {
        let app = launch(demo: true, arguments: ["-failNextSave", "YES"])
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Export Backup").firstMatch.waitForExistence(timeout: 15))
        app.windows.buttons.matching(identifier: "Close").firstMatch.click()
        let journal = app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        journal.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Write a new entry").firstMatch.waitForExistence(timeout: 15))
        app.typeKey("n", modifierFlags: .command)
        let body = app.windows.textViews["entryBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        body.click()
        body.typeText("A Mac draft kept safe.")
        app.windows.buttons.matching(identifier: "keepDraft").firstMatch.click()
        let quill = app.windows.buttons.matching(identifier: "Write a new entry").firstMatch
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        quill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let resume = app.windows.buttons.matching(identifier: "Carry on writing").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        XCTAssertFalse(app.windows.buttons.matching(identifier: "Done").firstMatch.isEnabled)
        resume.click()
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: .command)
        let ok = app.windows.buttons.matching(identifier: "OK").firstMatch
        XCTAssertTrue(ok.waitForExistence(timeout: 15))
        ok.click()
        XCTAssertEqual(body.value as? String, "A Mac draft kept safe.")
        app.windows.buttons.matching(identifier: "Done").firstMatch.click()
        XCTAssertTrue(app.windows.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "A Mac draft kept safe.")).firstMatch.waitForExistence(timeout: 15))
        capture("qa-mac-saved-recovery", app)
    }

    func testUnavailablePictureExplainsItsState() {
        let app = launch(demo: true, arguments: ["-missingPhoto", "YES"])
        app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch.click()
        let picture = app.windows.buttons.matching(identifier: "Photo 1 of 1").firstMatch
        XCTAssertTrue(picture.waitForExistence(timeout: 15))
        picture.click()
        XCTAssertTrue(app.windows.staticTexts["Photo unavailable"].waitForExistence(timeout: 15))
        capture("qa-mac-unavailable-picture", app)
        app.windows.buttons.matching(identifier: "Close").firstMatch.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Write a new entry").firstMatch.waitForExistence(timeout: 15))
    }


    // MARK: Readability tour (#227)

    // Screenshots of every paper screen in each look, kept in the CI artifacts for inspection.
    // They're evidence for a person to read, not an automatic contrast check: ThemeTests covers
    // the colours. Each tour also checks every action can still be reached.
    func testReadabilityTourLight() { readabilityTour(appearance: "light") }
    func testReadabilityTourDark() { readabilityTour(appearance: "dark") }
    func testReadabilityTourCompactWindow() { readabilityTour(appearance: "dark", arguments: ["-compactWindow", "YES", "-largeText", "YES"]) }

    private func readabilityTour(appearance: String, arguments: [String] = []) {
        let tag = "tour-\(appearance)\(arguments.isEmpty ? "" : "-compact")"
        let app = launch(demo: true, arguments: ["-appearance", appearance] + arguments)
        capture("\(tag)-shelf", app)

        // Shelf search, with results and with none.
        app.windows.buttons.matching(identifier: "Search").firstMatch.click()
        let search = app.windows.textFields["Search the journals"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        capture("\(tag)-shelf-search-empty", app)
        search.click()
        search.typeText("dragonstone")
        capture("\(tag)-shelf-search-results", app)
        search.typeText("zzz")
        capture("\(tag)-shelf-search-none", app)
        app.windows.buttons.matching(identifier: "Close search").firstMatch.click()

        // New Journal, empty then filled with long names.
        app.windows.buttons.matching(identifier: "Begin a new journal").firstMatch.click()
        let name = app.windows.textFields["characterName"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        capture("\(tag)-new-journal-empty", app)
        XCTAssertFalse(app.windows.buttons.matching(identifier: "Begin").firstMatch.isEnabled)
        name.click()
        name.typeText("Seraphina Ashvale of the Twelve Lanterns")
        let epithet = app.windows.textFields["Race, class or title"]
        epithet.click()
        epithet.typeText("Breton spellsword and reluctant thane")
        app.windows.buttons.matching(identifier: "Frost").firstMatch.click()
        capture("\(tag)-new-journal-filled", app)
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Begin").firstMatch.isHittable)
        app.windows.buttons.matching(identifier: "Begin").firstMatch.click()

        // The new journal's empty reader, then back to the shelf with both covers.
        let quill = app.windows.buttons.matching(identifier: "Write a new entry").firstMatch
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        capture("\(tag)-reader-empty", app)
        app.windows.buttons.matching(identifier: "Back to journals").firstMatch.click()
        XCTAssertTrue(app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Seraphina")).firstMatch.waitForExistence(timeout: 15))
        capture("\(tag)-shelf-long-title", app)

        // Edit Journal.
        app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch.rightClick()
        app.menuItems["Edit"].click()
        XCTAssertTrue(app.windows.textFields["characterName"].waitForExistence(timeout: 15))
        capture("\(tag)-edit-journal", app)
        app.windows.buttons.matching(identifier: "Cancel").firstMatch.click()

        // Reader, writer, Contents and the share preview.
        app.windows.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch.click()
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        XCTAssertTrue(quill.isHittable)
        capture("\(tag)-reader", app)
        quill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let body = app.windows.textViews["entryBody"]
        XCTAssertTrue(body.waitForExistence(timeout: 15))
        capture("\(tag)-writer-empty", app)
        let date = app.windows.textFields["inGameDate"]
        date.click()
        date.typeKey("a", modifierFlags: .command)
        date.typeText("21st of Last Seed, 4E 201")
        let place = app.windows.textFields["place"]
        place.click()
        place.typeText("Dragonsreach")
        body.click()
        body.typeText("The Jarl listened, and then he sent me back out into the cold.")
        capture("\(tag)-writer-filled", app)
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Done").firstMatch.isHittable)
        app.windows.buttons.matching(identifier: "Done").firstMatch.click()
        XCTAssertTrue(quill.waitForExistence(timeout: 15))

        app.windows.buttons.matching(identifier: "contents").firstMatch.click()
        let contentsSearch = app.windows.textFields["Search this journal"]
        XCTAssertTrue(contentsSearch.waitForExistence(timeout: 15))
        capture("\(tag)-contents", app)
        contentsSearch.click()
        contentsSearch.typeText("nothing like this")
        capture("\(tag)-contents-none", app)
        app.windows.buttons.matching(identifier: "Close").firstMatch.click()

        let entry = app.windows.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "sent me back out")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        entry.rightClick()
        let share = app.menuItems["Share as Picture"]
        if share.waitForExistence(timeout: 5) {
            share.click()
            // Only the preview: nothing is sent anywhere.
            XCTAssertTrue(app.windows.buttons.matching(identifier: "Share").firstMatch.waitForExistence(timeout: 15))
            capture("\(tag)-share-preview", app)
            app.windows.buttons.matching(identifier: "Close").firstMatch.click()
        } else {
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }

        // Settings.
        app.windows.buttons.matching(identifier: "Back to journals").firstMatch.click()
        app.windows.buttons.matching(identifier: "Settings").firstMatch.click()
        XCTAssertTrue(app.windows.buttons.matching(identifier: "Export Backup").firstMatch.waitForExistence(timeout: 15))
        capture("\(tag)-settings", app)
        app.windows.buttons.matching(identifier: "Close").firstMatch.click()
    }

}
#endif
