import Foundation

struct OpenedPlainTextFile {
    let text: String
    let bookmark: Data?
    let fingerprint: DiskFingerprint
}

enum FileAccess {
    static func open(_ url: URL) throws -> OpenedPlainTextFile {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let text = try PlainTextCodec.decode(data)
        return OpenedPlainTextFile(
            text: text,
            bookmark: try? bookmark(for: url),
            fingerprint: try fingerprint(for: url, data: data)
        )
    }

    static func write(_ text: String, to url: URL) throws -> (Data?, DiskFingerprint) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let data = PlainTextCodec.encode(text)
        try data.write(to: url, options: .atomic)
        return (try? bookmark(for: url), try fingerprint(for: url, data: data))
    }

    static func resolve(bookmark: Data?, fallbackPath: String?) -> URL? {
        if let bookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
        }
        return fallbackPath.map { URL(fileURLWithPath: $0) }
    }

    static func fingerprint(for url: URL, data suppliedData: Data? = nil) throws -> DiskFingerprint {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let data = try suppliedData ?? Data(contentsOf: url)
        return DiskFingerprint(
            byteCount: UInt64(values.fileSize ?? data.count),
            modificationDate: values.contentModificationDate ?? .distantPast,
            contentHash: PlainTextCodec.hash(data)
        )
    }

    static func hasChanged(from expected: DiskFingerprint?, at url: URL) -> Bool {
        guard let expected, let actual = try? fingerprint(for: url) else { return true }
        return actual != expected
    }

    private static func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.fileResourceIdentifierKey],
            relativeTo: nil
        )
    }
}
