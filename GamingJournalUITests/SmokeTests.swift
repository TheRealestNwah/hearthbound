#if os(iOS)
import XCTest

/// Quick checks of the core flows, run on every pull request.
final class SmokeTests: XCTestCase {
    /// How long to wait for each screen or row. Waits end as soon as it appears, so this only
    /// matters on a slow, busy CI runner, where 5 seconds proved too short (#81).
    private static let step: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(demoData: Bool = false, skipOnboarding: Bool = true, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
            + (demoData ? ["-demoData"] : [])
            + (skipOnboarding ? ["-onboarding.completed", "YES"] : []) + arguments
        app.launch()
        if !skipOnboarding { return app }
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: 20))
        return app
    }

    /// Keep real app renders available in CI even when the smoke tests pass.
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Rows combine their text into one accessibility label, so match on part of it.
    private func element(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Waits for a sheet to finish sliding away. While it closes, the reader behind it is
    /// still scaled down and its controls can't be tapped.
    private func waitForSheetToClose(_ marker: XCUIElement) {
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: marker)
        wait(for: [closed], timeout: Self.step)
    }

    /// Taps a field and types into it. A tap that lands while a sheet is still sliding in can miss
    /// the field, so tap again (a few times at most) until it reports keyboard focus (#111).
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: Self.step))
        for _ in 0..<3 {
            field.tap()
            if hasKeyboardFocus(field, within: 1) { break }
        }
        field.typeText(text)
    }

    private func hasKeyboardFocus(_ field: XCUIElement, within timeout: TimeInterval) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        repeat {
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date.now < deadline
        return false
    }

    func testOnboardingLeadsToTheShelf() {
        let app = launch(skipOnboarding: false)
        let start = app.buttons["Open the first page"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        start.tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }

    func testBeginningAJournalAndWritingAnEntry() {
        let app = launch()
        app.buttons["Begin a new journal"].tap()

        type("Eira Stormborn", into: app.textFields["characterName"])
        app.navigationBars["New Journal"].buttons["Begin"].tap()

        let quill = app.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "The Journal of Eira Stormborn", in: app).exists)
        quill.tap()

        type("16th of Last Seed", into: app.textFields["inGameDate"])
        type("Praise the sun", into: app.textViews["entryBody"])
        capture("04-writer", in: app)
        app.buttons["Done"].tap()

        XCTAssertTrue(element(containing: "Praise the sun", in: app).waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "16th of Last Seed", in: app).exists)
    }

    func testDemoJournalOpensOnItsLatestPage() {
        let app = launch(demoData: true)
        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()

        // The latest page ends with the latest entry (which may have started on the page before).
        let ending = element(containing: "never learned", in: app)
        XCTAssertTrue(ending.waitForExistence(timeout: Self.step), "Latest page not shown: " + app.debugDescription)
        capture("05-journal-latest-page", in: app)
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        app.buttons["Back to journals"].tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }

    func testSearchOpensTheJournalAtTheEntry() {
        let app = launch(demoData: true)
        app.buttons["Search"].tap()
        type("dragonstone", into: app.textFields["Search the journals"])
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "wall that spoke")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: Self.step), "No search result: " + app.debugDescription)
        result.tap()
        XCTAssertTrue(app.buttons["Write a new entry"].waitForExistence(timeout: Self.step))
        XCTAssertTrue(element(containing: "The Journal of Eira Stormborn", in: app).exists)
    }

    func testContentsTurnsToTheFirstEntry() {
        let app = launch(demoData: true)
        capture("01-shelf", in: app)
        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()
        let contents = app.buttons["contents"]
        XCTAssertTrue(contents.waitForExistence(timeout: Self.step))
        contents.tap()

        XCTAssertTrue(app.navigationBars["Contents"].waitForExistence(timeout: Self.step))
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: Self.step))
        capture("03-contents", in: app)
        first.tap()

        // The sheet closes on the first page.
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["Contents"])
        wait(for: [closed], timeout: Self.step)
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
        capture("02-journal-first-page", in: app)

        // Tapping an entry opens it to amend (#170).
        element(containing: "headsman", in: app).tap()
        XCTAssertTrue(app.textViews["entryBody"].waitForExistence(timeout: Self.step))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Previous page"].waitForExistence(timeout: Self.step))
    }

    func testClosingAWrittenPageAsksFirst() {
        let app = launch(demoData: true)
        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()
        app.buttons["Write a new entry"].tap()
        type("Half a thought", into: app.textViews["entryBody"])
        app.buttons["Cancel"].tap()

        // Written words aren't thrown away without asking (#179).
        let discard = app.buttons["Discard Page"]
        XCTAssertTrue(discard.waitForExistence(timeout: Self.step))
        discard.tap()
        XCTAssertTrue(app.buttons["Write a new entry"].waitForExistence(timeout: Self.step))
        XCTAssertFalse(element(containing: "Half a thought", in: app).exists)
    }

    func testSettingsOpenFromTheShelf() {
        let app = launch()
        // The shelf's own heading is the only title: the bar stays inline-height rather than
        // growing a large title above it (#167). The hidden title is still read by VoiceOver.
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
        XCTAssertLessThan(app.navigationBars.firstMatch.frame.height, 70)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: Self.step))
        app.navigationBars["Settings"].buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
    }
    func testKeepDraftRequiresRecoveryDecisionAndResumesFromShelf() {
        let app = launch(demoData: true)
        element(containing: "Eira Stormborn", in: app).tap()
        app.buttons["Write a new entry"].tap()
        type("A thought to finish tomorrow.", into: app.textViews["entryBody"])
        app.buttons["keepDraft"].tap()
        XCTAssertTrue(app.buttons["Back to journals"].waitForExistence(timeout: Self.step))
        app.buttons["Back to journals"].tap()
        let resume = app.buttons["resumeDraft"]
        XCTAssertTrue(resume.waitForExistence(timeout: Self.step))
        resume.tap()
        let carryOn = app.buttons["Carry on writing"]
        XCTAssertTrue(carryOn.waitForExistence(timeout: Self.step))
        XCTAssertFalse(app.buttons["Done"].isEnabled)
        XCTAssertFalse(app.textViews["entryBody"].isEnabled)
        capture("qa-unfinished-page", in: app)
        carryOn.tap()
        XCTAssertEqual(app.textViews["entryBody"].value as? String, "A thought to finish tomorrow.")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
        XCTAssertFalse(resume.exists)
    }

    func testSaveFailureKeepsWritingAndRetrySucceeds() {
        let app = launch(demoData: true, arguments: ["-failNextSave", "YES"])
        element(containing: "Eira Stormborn", in: app).tap()
        app.buttons["Write a new entry"].tap()
        type("Keep me after a failed save.", into: app.textViews["entryBody"])
        app.buttons["Done"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: Self.step))
        app.alerts.buttons["OK"].tap()
        XCTAssertEqual(app.textViews["entryBody"].value as? String, "Keep me after a failed save.")
        app.buttons["Done"].tap()
        XCTAssertTrue(element(containing: "Keep me after a failed save.", in: app).waitForExistence(timeout: Self.step))
    }

    func testSaveWaitsForPictureImportAndShowsFailure() {
        let app = launch(demoData: true, arguments: ["-delayedPhotoImport", "YES"])
        element(containing: "Eira Stormborn", in: app).tap()
        app.buttons["Write a new entry"].tap()
        type("Words remain when a picture fails.", into: app.textViews["entryBody"])
        app.buttons["Test picture import"].tap()
        XCTAssertFalse(app.buttons["Done"].isEnabled)
        XCTAssertFalse(app.buttons["keepDraft"].isEnabled)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: Self.step))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Done"].isEnabled)
        XCTAssertEqual(app.textViews["entryBody"].value as? String, "Words remain when a picture fails.")
        app.buttons["Done"].tap()
    }


    // MARK: Readability tour (#227)

    // Screenshots of each paper screen in both looks and at an accessibility text size, kept in
    // the CI artifacts for a person to inspect (ThemeTests checks the colours). Runs on iPhone and
    // iPad. Each tour also checks the screen's actions stay reachable.
    func testReadabilityTourLight() { readabilityTour("light") }
    func testReadabilityTourDark() { readabilityTour("dark") }
    func testReadabilityTourLargeText() {
        readabilityTour("dark", arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
    }

    private func readabilityTour(_ appearance: String, arguments: [String] = []) {
        let tag = "tour-\(appearance)\(arguments.isEmpty ? "" : "-large")"
        let app = launch(demoData: true, arguments: ["-appearance", appearance] + arguments)
        XCTAssertTrue(app.buttons["Begin a new journal"].waitForExistence(timeout: Self.step))
        capture("\(tag)-shelf", in: app)

        app.buttons["Search"].tap()
        type("zzz", into: app.textFields["Search the journals"])
        capture("\(tag)-shelf-search-none", in: app)
        app.buttons["Close search"].tap()

        app.buttons["Begin a new journal"].tap()
        let name = app.textFields["characterName"]
        XCTAssertTrue(name.waitForExistence(timeout: Self.step))
        capture("\(tag)-new-journal-empty", in: app)
        type("Seraphina Ashvale of the Twelve Lanterns", into: name)
        capture("\(tag)-new-journal-filled", in: app)
        XCTAssertTrue(app.buttons["Begin"].isHittable)
        app.buttons["Cancel"].tap()
        waitForSheetToClose(name)

        let journal = element(containing: "Eira Stormborn", in: app)
        XCTAssertTrue(journal.waitForExistence(timeout: Self.step))
        journal.tap()
        let quill = app.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: Self.step))
        XCTAssertTrue(quill.isHittable)
        capture("\(tag)-reader", in: app)

        quill.tap()
        XCTAssertTrue(app.textViews["entryBody"].waitForExistence(timeout: Self.step))
        capture("\(tag)-writer-empty", in: app)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        app.buttons["Cancel"].tap()
        waitForSheetToClose(app.textViews["entryBody"])

        app.buttons["contents"].tap()
        let search = app.textFields["Search this journal"]
        XCTAssertTrue(search.waitForExistence(timeout: Self.step))
        capture("\(tag)-contents", in: app)
        type("nothing like this", into: search)
        capture("\(tag)-contents-none", in: app)
        app.buttons["Close"].tap()
        waitForSheetToClose(search)

        app.buttons["Back to journals"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Export Backup"].waitForExistence(timeout: Self.step))
        capture("\(tag)-settings", in: app)
        app.buttons["Close"].tap()
    }

}

#endif
