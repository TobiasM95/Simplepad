import Foundation
import XCTest
@testable import Simplepad

final class FileAccessTests: XCTestCase {
    func testFingerprintChangesWithFileContents() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplepadFingerprint-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data("first".utf8).write(to: url)
        let first = try FileAccess.fingerprint(for: url)
        try Data("second and longer".utf8).write(to: url)
        let second = try FileAccess.fingerprint(for: url)

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first.contentHash, second.contentHash)
    }

    func testChangeDetectionTreatsDeletedFileAsChanged() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplepadDeleted-\(UUID().uuidString).txt")
        try Data("temporary".utf8).write(to: url)
        let fingerprint = try FileAccess.fingerprint(for: url)

        XCTAssertFalse(FileAccess.hasChanged(from: fingerprint, at: url))
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(FileAccess.hasChanged(from: fingerprint, at: url))
    }

    func testWriteAndOpenRoundTripPlainUTF8() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplepadRoundTrip-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let (bookmark, writtenFingerprint) = try FileAccess.write("hello 👋", to: url)
        let opened = try FileAccess.open(url)

        XCTAssertEqual(opened.text, "hello 👋")
        XCTAssertEqual(opened.fingerprint, writtenFingerprint)
        if let bookmark {
            XCTAssertEqual(
                FileAccess.resolve(bookmark: bookmark, fallbackPath: url.path)?.standardizedFileURL,
                url.standardizedFileURL
            )
        }
    }

    func testOpenRejectsNonUTF8WithoutChangingFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplepadInvalid-\(UUID().uuidString).txt")
        let invalid = Data([0xFF, 0xFE, 0x00])
        try invalid.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try FileAccess.open(url))
        XCTAssertEqual(try Data(contentsOf: url), invalid)
    }
}
