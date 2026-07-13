import Combine
import Foundation

@MainActor
final class DocumentTab: ObservableObject, Identifiable {
    let id: UUID

    @Published private(set) var text: String
    @Published var displayName: String
    @Published private(set) var isDirty: Bool
    @Published var wrapsLines: Bool
    @Published var fontSize: Double
    @Published var externalConflict = false

    var fileBookmark: Data?
    var filePathFallback: String?
    var savedContentHash: String?
    var diskFingerprint: DiskFingerprint?
    let buffer: BufferRecord

    init(record: TabRecord, text: String) {
        id = record.id
        self.text = text
        displayName = record.displayName
        isDirty = record.isDirty
        wrapsLines = record.wrapsLines
        fontSize = record.fontSize
        fileBookmark = record.fileBookmark
        filePathFallback = record.filePathFallback
        savedContentHash = record.savedContentHash
        diskFingerprint = record.diskFingerprint
        buffer = record.buffer
    }

    convenience init(id: UUID = UUID(), displayName: String) {
        self.init(
            record: TabRecord(
                id: id,
                displayName: displayName,
                buffer: BufferRecord(fileName: "\(id.uuidString).txt"),
                fileBookmark: nil,
                filePathFallback: nil,
                savedContentHash: nil,
                diskFingerprint: nil,
                isDirty: false,
                wrapsLines: true,
                fontSize: 13
            ),
            text: ""
        )
    }

    var hasDiskFile: Bool {
        fileBookmark != nil || filePathFallback != nil
    }

    /// File-backed tabs show their filename; unsaved buffers preview their first line.
    var tabTitle: String {
        guard !hasDiskFile else { return displayName }
        let firstLine = text
            .prefix(while: { !$0.isNewline })
            .trimmingCharacters(in: .whitespaces)
        guard !firstLine.isEmpty else { return displayName }
        guard firstLine.count > Self.tabTitlePreviewLimit else { return firstLine }
        return String(firstLine.prefix(Self.tabTitlePreviewLimit)) + "…"
    }

    static let tabTitlePreviewLimit = 30

    var record: TabRecord {
        TabRecord(
            id: id,
            displayName: displayName,
            buffer: buffer,
            fileBookmark: fileBookmark,
            filePathFallback: filePathFallback,
            savedContentHash: savedContentHash,
            diskFingerprint: diskFingerprint,
            isDirty: isDirty,
            wrapsLines: wrapsLines,
            fontSize: fontSize
        )
    }

    func applyUserEdit(_ newText: String) {
        guard text != newText else { return }
        text = newText
        isDirty = PlainTextCodec.hash(newText) != savedContentHash
    }

    func applyOpenedFile(_ opened: OpenedPlainTextFile, url: URL) {
        text = opened.text
        displayName = url.lastPathComponent
        fileBookmark = opened.bookmark
        filePathFallback = url.path
        diskFingerprint = opened.fingerprint
        savedContentHash = PlainTextCodec.hash(opened.text)
        isDirty = false
        externalConflict = false
    }

    func markSaved(bookmark: Data?, fingerprint: DiskFingerprint, url: URL) {
        displayName = url.lastPathComponent
        fileBookmark = bookmark
        filePathFallback = url.path
        diskFingerprint = fingerprint
        savedContentHash = PlainTextCodec.hash(text)
        isDirty = false
        externalConflict = false
    }
}
