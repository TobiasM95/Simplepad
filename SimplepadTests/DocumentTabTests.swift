import XCTest
@testable import Simplepad

@MainActor
final class DocumentTabTests: XCTestCase {
    func testUserEditTracksSavedHash() {
        let tab = DocumentTab(displayName: "Untitled")
        tab.savedContentHash = PlainTextCodec.hash("saved")

        tab.applyUserEdit("changed")
        XCTAssertTrue(tab.isDirty)

        tab.applyUserEdit("saved")
        XCTAssertFalse(tab.isDirty)
    }

    func testUntitledTabHasPersistentBufferName() {
        let tab = DocumentTab(displayName: "Untitled")
        XCTAssertEqual(tab.buffer.fileName, "\(tab.id.uuidString).txt")
        XCTAssertFalse(tab.hasDiskFile)
    }

    func testTabTitleFallsBackToDisplayNameWhenBufferIsEmpty() {
        let tab = DocumentTab(displayName: "Untitled 1")
        XCTAssertEqual(tab.tabTitle, "Untitled 1")

        tab.applyUserEdit("   \nsecond line")
        XCTAssertEqual(tab.tabTitle, "Untitled 1")
    }

    func testTabTitleShowsFirstLineOfUnsavedBuffer() {
        let tab = DocumentTab(displayName: "Untitled 1")
        tab.applyUserEdit("Shopping list\nmilk\neggs")
        XCTAssertEqual(tab.tabTitle, "Shopping list")
    }

    func testTabTitleTrimsWhitespaceAndTruncatesLongFirstLines() {
        let tab = DocumentTab(displayName: "Untitled 1")
        tab.applyUserEdit("  " + String(repeating: "a", count: 40) + "\nrest")
        XCTAssertEqual(tab.tabTitle, String(repeating: "a", count: 30) + "…")

        tab.applyUserEdit(String(repeating: "b", count: 30))
        XCTAssertEqual(tab.tabTitle, String(repeating: "b", count: 30))
    }

    func testTabTitleUsesFileNameForFileBackedTabs() {
        let tab = DocumentTab(displayName: "notes.txt")
        tab.filePathFallback = "/tmp/notes.txt"
        tab.applyUserEdit("first line of the file")
        XCTAssertEqual(tab.tabTitle, "notes.txt")
    }
}

