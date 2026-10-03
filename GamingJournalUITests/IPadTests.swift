#if os(iOS)
import XCTest
import UIKit

final class IPadTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad-specific layout acceptance")
        XCUIDevice.shared.orientation = .portrait
    }
    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLargeTextReaderKeepsNavigationAndWritingReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-onboarding.completed", "YES",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        journal.tap()
        let quill = app.buttons["Write a new entry"]
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
        XCTAssertTrue(quill.isHittable)
        XCTAssertTrue(app.buttons["Back to journals"].isHittable)
        XCTAssertTrue(app.buttons["contents"].isHittable)
        let entry = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "never learned")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        // This short entry should fit within a screen at the largest text size.
        // Applying Dynamic Type twice makes it several screens tall.
        XCTAssertLessThan(entry.frame.height, app.frame.height)
        capture("ipad-large-text-dark-reader", app)
        quill.tap()
        XCTAssertTrue(app.textViews["entryBody"].waitForExistence(timeout: 15))
        let body = app.textViews["entryBody"]
        body.tap()
        body.typeText("A readable page.")
        XCTAssertTrue(app.buttons["Done"].isHittable)
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertTrue(app.textFields["inGameDate"].isHittable)
        XCTAssertGreaterThan(body.frame.height, 80)
        capture("ipad-large-text-writer", app)
        app.buttons["Done"].tap()
        XCTAssertTrue(quill.waitForExistence(timeout: 15))
    }

    func testRotationKeepsLatestEntryAndChangesToFacingPages() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-longDemoData", "-onboarding.completed", "YES"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        capture("ipad-portrait-shelf", app)
        journal.tap()
        let ending = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "never learned")).firstMatch
        XCTAssertTrue(ending.waitForExistence(timeout: 15))
        capture("ipad-portrait-reader", app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let position = app.staticTexts["pagePosition"]
        let landscape = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [landscape], timeout: 15)
        XCTAssertTrue(ending.exists)
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        capture("ipad-landscape-spread", app)
        app.buttons["contents"].tap()
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        let firstPage = expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: app.buttons["Previous page"])
        wait(for: [firstPage], timeout: 15)
        let spread = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "pages 1–2"), evaluatedWith: position)
        wait(for: [spread], timeout: 15)
        capture("ipad-landscape-first-spread", app)
        XCUIDevice.shared.orientation = .portrait
        let single = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "page 1 of"), evaluatedWith: position)
        wait(for: [single], timeout: 15)
        XCTAssertFalse(app.buttons["Previous page"].isEnabled)
    }
    func testRotationPreservesAManuallyChosenPassage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData", "-longDemoData", "-onboarding.completed", "YES"]
        app.launch()
        let journal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eira Stormborn")).firstMatch
        XCTAssertTrue(journal.waitForExistence(timeout: 20))
        journal.tap()
        app.buttons["contents"].tap()
        let first = app.buttons.matching(identifier: "contentsEntry").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        let next = app.buttons["Next page"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()
        let turned = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "page 2 of"), evaluatedWith: app.staticTexts["pagePosition"])
        wait(for: [turned], timeout: 15)
        let passage = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Milestone")).firstMatch
        XCTAssertTrue(passage.waitForExistence(timeout: 15))
        let text = passage.label
        let expression = try NSRegularExpression(pattern: "Milestone [0-9]+\\.")
        let match = try XCTUnwrap(expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)))
        let marker = (text as NSString).substring(with: match.range)
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height }, evaluatedWith: app)
        wait(for: [landscape], timeout: 15)
        let retained = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
        XCTAssertTrue(retained.waitForExistence(timeout: 15))
        XCTAssertTrue(retained.isHittable)
        // This passage moves into the first landscape spread. Cached UIKit hosts must
        // show that spread's opening too, rather than stale text with a new page number.
        let spread = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "pages 1–2"), evaluatedWith: app.staticTexts["pagePosition"])
        wait(for: [spread], timeout: 15)
        let opening = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "The cart ride ended")).firstMatch
        XCTAssertTrue(opening.waitForExistence(timeout: 15))
        XCTAssertTrue(opening.isHittable)
        let quill = app.buttons["Write a new entry"]
        // The dedicated writing area must sit below the page viewport, not over its text.
        let viewport = app.scrollViews.matching(identifier: "pageViewport").firstMatch
        XCTAssertTrue(viewport.exists)
        XCTAssertGreaterThanOrEqual(quill.frame.minY, viewport.frame.maxY)
        capture("ipad-reflow-middle-passage", app)
        XCUIDevice.shared.orientation = .portrait
        let restoredPage = expectation(for: NSPredicate(format: "label BEGINSWITH %@", "page 2 of"), evaluatedWith: app.staticTexts["pagePosition"])
        wait(for: [restoredPage], timeout: 15)
        XCTAssertTrue(retained.waitForExistence(timeout: 15))
        XCTAssertTrue(retained.isHittable)
        capture("ipad-reflow-return-to-portrait", app)
    }

}
#endif
