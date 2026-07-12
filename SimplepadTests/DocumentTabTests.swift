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
}

