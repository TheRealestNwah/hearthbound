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

}
#endif
