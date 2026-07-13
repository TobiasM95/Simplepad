import Foundation
import XCTest

final class SimplepadUITests: XCTestCase {
    private var app: XCUIApplication!
    private var sessionPath: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        sessionPath = NSTemporaryDirectory() + "SimplepadUITests-\(UUID().uuidString)"
        app.launchEnvironment["SIMPLEPAD_SESSION_ROOT"] = sessionPath
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        try? FileManager.default.removeItem(atPath: sessionPath)
    }

    func testNewTabShortcutCreatesAnotherTab() {
        XCTAssertTrue(app.textViews["editor"].waitForExistence(timeout: 3))
        app.typeKey("t", modifierFlags: .command)

        let tabs = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tab-select-'")
        )
        XCTAssertEqual(tabs.count, 2)
    }

    func testFileAndViewMenusExposeMinimalCommands() {
        app.menuBars.menuBarItems["File"].click()
        XCTAssertTrue(app.menuItems["New Tab"].exists)
        XCTAssertTrue(app.menuItems["Open…"].exists)
        XCTAssertTrue(app.menuItems["Save"].exists)

        app.typeKey(.escape, modifierFlags: [])
        app.menuBars.menuBarItems["View"].click()
        XCTAssertTrue(app.menuItems["Zoom In"].exists)
        XCTAssertTrue(app.menuItems["Line Wrap"].exists)
    }

    func testBufferReturnsAfterRelaunch() {
        let editor = app.textViews["editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click()
        editor.typeText("persistent plain text")
        app.terminate()

        app.launch()
        let restoredEditor = app.textViews["editor"]
        XCTAssertTrue(restoredEditor.waitForExistence(timeout: 3))
        XCTAssertTrue((restoredEditor.value as? String)?.contains("persistent plain text") == true)
    }

    func testEditorIsFocusedOnLaunchAndAfterCreatingTab() {
        let editor = app.textViews["editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        app.typeText("startup focus")
        XCTAssertTrue((editor.value as? String)?.contains("startup focus") == true)

        app.typeKey("t", modifierFlags: .command)
        app.typeText("new tab focus")
        XCTAssertTrue((app.textViews["editor"].value as? String)?.contains("new tab focus") == true)
    }

    func testUnsavedTabTitleShowsFirstLineOfBuffer() {
        let editor = app.textViews["editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.click()
        editor.typeText("Meeting notes\nagenda item")

        let tab = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tab-select-'")
        ).firstMatch
        XCTAssertTrue(tab.label.contains("Meeting notes"))
        XCTAssertFalse(tab.label.contains("agenda"))
    }

    func testClosingUntitledTabRequiresConfirmation() {
        app.menuBars.menuBarItems["File"].click()
        app.menuItems["Close Tab"].click()
        let dialog = app.dialogs.firstMatch
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        XCTAssertTrue(dialog.buttons["Close Tab"].exists)

        dialog.buttons["Cancel"].click()
        XCTAssertTrue(app.textViews["editor"].exists)
    }
}
