import Foundation

final class SessionStore: @unchecked Sendable {
    static let shared = SessionStore()

    private let rootURL: URL
    private let buffersURL: URL
    private let manifestURL: URL
    private let backupManifestURL: URL
    private let queue = DispatchQueue(label: "app.simplepad.session-store", qos: .userInitiated)
    private let fileManager: FileManager

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
        self.rootURL = baseURL
        buffersURL = baseURL.appendingPathComponent("Buffers", isDirectory: true)
        manifestURL = baseURL.appendingPathComponent("session.json")
        backupManifestURL = baseURL.appendingPathComponent("session.backup.json")
    }

    func load() -> RestoredSession {
        queue.sync {
            prepareDirectories()
            if let restored = restore(using: manifestURL) ?? restore(using: backupManifestURL) {
                return restored
            }
            return recoverOrphanedBuffers()
        }
    }

    func persist(tabs: [PersistedTabSnapshot], selectedTabID: UUID?) {
        queue.async { [self] in
            persistNow(tabs: tabs, selectedTabID: selectedTabID)
        }
    }

    func persistAndWait(tabs: [PersistedTabSnapshot], selectedTabID: UUID?) {
        queue.sync { [self] in
            persistNow(tabs: tabs, selectedTabID: selectedTabID)
        }
    }

    func flush() {
        queue.sync {}
    }

    private func persistNow(tabs: [PersistedTabSnapshot], selectedTabID: UUID?) {
        prepareDirectories()
        do {
            if fileManager.fileExists(atPath: manifestURL.path) {
                try? fileManager.removeItem(at: backupManifestURL)
                try? fileManager.copyItem(at: manifestURL, to: backupManifestURL)
            }

            for tab in tabs {
                let url = buffersURL.appendingPathComponent(tab.record.buffer.fileName)
                try PlainTextCodec.encode(tab.text).write(to: url, options: .atomic)
            }

            let manifest = SessionManifest(
                tabs: tabs.map(\.record),
                selectedTabID: selectedTabID
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)

            try data.write(to: manifestURL, options: .atomic)

            var wantedNames = Set(tabs.map(\.record.buffer.fileName))
            if
                let backupData = try? Data(contentsOf: backupManifestURL),
                let backup = try? JSONDecoder().decode(SessionManifest.self, from: backupData)
            {
                wantedNames.formUnion(backup.tabs.map(\.buffer.fileName))
            }
            let existing = (try? fileManager.contentsOfDirectory(
                at: buffersURL,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in existing where !wantedNames.contains(url.lastPathComponent) {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            NSLog("Simplepad could not persist its session: %@", error.localizedDescription)
        }
    }

    private func restore(using url: URL) -> RestoredSession? {
        guard
            let data = try? Data(contentsOf: url),
            let manifest = try? JSONDecoder().decode(SessionManifest.self, from: data),
            manifest.version == SessionManifest.currentVersion
        else { return nil }

        let restored = manifest.tabs.compactMap { record -> PersistedTabSnapshot? in
            let bufferURL = buffersURL.appendingPathComponent(record.buffer.fileName)
            guard
                let data = try? Data(contentsOf: bufferURL),
                let text = try? PlainTextCodec.decode(data)
            else { return nil }
            return PersistedTabSnapshot(record: record, text: text)
        }
        guard !restored.isEmpty || manifest.tabs.isEmpty else { return nil }
        return RestoredSession(tabs: restored, selectedTabID: manifest.selectedTabID)
    }

    private func recoverOrphanedBuffers() -> RestoredSession {
        let urls = ((try? fileManager.contentsOfDirectory(
            at: buffersURL,
            includingPropertiesForKeys: nil
        )) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }

        let tabs = urls.compactMap { url -> PersistedTabSnapshot? in
            guard
                url.pathExtension == "txt",
                let data = try? Data(contentsOf: url),
                let text = try? PlainTextCodec.decode(data)
            else { return nil }
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()
            let record = TabRecord(
                id: id,
                displayName: "Recovered",
                buffer: BufferRecord(fileName: url.lastPathComponent),
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
        return RestoredSession(tabs: tabs, selectedTabID: tabs.first?.record.id)
    }

    private func prepareDirectories() {
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: buffersURL, withIntermediateDirectories: true)
    }

    private static func defaultRootURL(fileManager: FileManager) -> URL {
        if let override = ProcessInfo.processInfo.environment["SIMPLEPAD_SESSION_ROOT"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("Simplepad", isDirectory: true)
    }
}
