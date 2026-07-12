import Foundation

struct DiskFingerprint: Codable, Equatable, Sendable {
    let byteCount: UInt64
    let modificationDate: Date
    let contentHash: String
}

struct BufferRecord: Codable, Equatable, Sendable {
    let fileName: String
}

struct TabRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var displayName: String
    var buffer: BufferRecord
    var fileBookmark: Data?
    var filePathFallback: String?
    var savedContentHash: String?
    var diskFingerprint: DiskFingerprint?
    var isDirty: Bool
    var wrapsLines: Bool
    var fontSize: Double
}

struct SessionManifest: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var tabs: [TabRecord]
    var selectedTabID: UUID?

    init(tabs: [TabRecord], selectedTabID: UUID?) {
        version = Self.currentVersion
        self.tabs = tabs
        self.selectedTabID = selectedTabID
    }
}

struct PersistedTabSnapshot: Sendable {
    let record: TabRecord
    let text: String
}

struct RestoredSession: Sendable {
    let tabs: [PersistedTabSnapshot]
    let selectedTabID: UUID?
}

