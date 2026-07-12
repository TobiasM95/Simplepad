import Foundation
import XCTest
@testable import Simplepad

final class SessionStoreTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimplepadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func testRoundTripsMultipleTabsAndSelection() {
        let store = SessionStore(rootURL: rootURL)
        let first = snapshot(name: "One", text: "alpha")
        let second = snapshot(name: "Two", text: "beta")

        store.persistAndWait(tabs: [first, second], selectedTabID: second.record.id)
        let restored = store.load()

        XCTAssertEqual(restored.tabs.map(\.text), ["alpha", "beta"])
        XCTAssertEqual(restored.tabs.map(\.record.displayName), ["One", "Two"])
        XCTAssertEqual(restored.selectedTabID, second.record.id)
    }

    func testCorruptPrimaryManifestFallsBackToBackup() throws {
        let store = SessionStore(rootURL: rootURL)
        let first = snapshot(name: "First", text: "safe copy")
        store.persistAndWait(tabs: [first], selectedTabID: first.record.id)

        let second = snapshot(name: "Second", text: "new copy")
        store.persistAndWait(tabs: [second], selectedTabID: second.record.id)
        try Data("not-json".utf8).write(to: rootURL.appendingPathComponent("session.json"))

        let restored = store.load()
        XCTAssertEqual(restored.tabs.first?.text, "safe copy")
        XCTAssertEqual(restored.tabs.first?.record.id, first.record.id)
    }

    func testRecoversOrphanBufferWhenManifestsAreMissing() throws {
        let store = SessionStore(rootURL: rootURL)
        let tab = snapshot(name: "Lost metadata", text: "recover me")
        store.persistAndWait(tabs: [tab], selectedTabID: tab.record.id)
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent("session.json"))

        let restored = store.load()
        XCTAssertEqual(restored.tabs.first?.text, "recover me")
        XCTAssertEqual(restored.tabs.first?.record.displayName, "Recovered")
        XCTAssertEqual(restored.tabs.first?.record.isDirty, true)
    }

    func testCurrentManifestVersionIsWritten() throws {
        let store = SessionStore(rootURL: rootURL)
        let tab = snapshot(name: "Versioned", text: "text")
        store.persistAndWait(tabs: [tab], selectedTabID: tab.record.id)

        let data = try Data(contentsOf: rootURL.appendingPathComponent("session.json"))
        let manifest = try JSONDecoder().decode(SessionManifest.self, from: data)
        XCTAssertEqual(manifest.version, SessionManifest.currentVersion)
    }

    func testUnsupportedManifestVersionRecoversIntactBuffer() throws {
        let store = SessionStore(rootURL: rootURL)
        let tab = snapshot(name: "Future", text: "still safe")
        store.persistAndWait(tabs: [tab], selectedTabID: tab.record.id)

        let manifestURL = rootURL.appendingPathComponent("session.json")
        let data = try Data(contentsOf: manifestURL)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["version"] = SessionManifest.currentVersion + 1
        try JSONSerialization.data(withJSONObject: object).write(to: manifestURL)

        let restored = store.load()
        XCTAssertEqual(restored.tabs.first?.text, "still safe")
        XCTAssertEqual(restored.tabs.first?.record.displayName, "Recovered")
    }

    private func snapshot(name: String, text: String) -> PersistedTabSnapshot {
        let id = UUID()
        let record = TabRecord(
            id: id,
            displayName: name,
            buffer: BufferRecord(fileName: "\(id.uuidString).txt"),
            fileBookmark: nil,
            filePathFallback: nil,
            savedContentHash: nil,
            diskFingerprint: nil,
            isDirty: true,
            wrapsLines: true,
            fontSize: 13
        )
        return PersistedTabSnapshot(record: record, text: text)
    }
}
