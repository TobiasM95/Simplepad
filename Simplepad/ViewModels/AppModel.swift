import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var tabs: [DocumentTab] = []
    @Published var selectedTabID: UUID?

    private let store: SessionStore
    private var untitledCounter = 0

    init(store: SessionStore = .shared) {
        self.store = store
        restoreSession()
        if tabs.isEmpty {
            newTab()
        }
    }

    var selectedTab: DocumentTab? {
        tabs.first { $0.id == selectedTabID }
    }

    func newTab() {
        untitledCounter += 1
        let tab = DocumentTab(displayName: "Untitled \(untitledCounter)")
        tabs.append(tab)
        selectedTabID = tab.id
        persist()
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open UTF-8 Text File"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text, .data]
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(openFile)
    }

    func openFile(_ url: URL) {
        let normalizedPath = url.standardizedFileURL.path
        if let existing = tabs.first(where: {
            $0.filePathFallback.map { URL(fileURLWithPath: $0).standardizedFileURL.path } == normalizedPath
        }) {
            selectedTabID = existing.id
            return
        }

        do {
            let opened = try FileAccess.open(url)
            let tab = DocumentTab(displayName: url.lastPathComponent)
            tab.applyOpenedFile(opened, url: url)
            tabs.append(tab)
            selectedTabID = tab.id
            persist()
        } catch {
            showError(title: "Couldn’t Open File", error: error)
        }
    }

    func updateText(in tab: DocumentTab, to text: String) {
        tab.applyUserEdit(text)
        persist()
    }

    func select(_ tab: DocumentTab) {
        selectedTabID = tab.id
        persist()
    }

    func requestClose(_ tab: DocumentTab? = nil) {
        guard let tab = tab ?? selectedTab else { return }
        if tab.isDirty || !tab.hasDiskFile {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Close “\(tab.displayName)” and discard its buffer?"
            alert.informativeText = "Closing this tab removes its persistent buffer. Quitting Simplepad would keep it for next time."
            alert.addButton(withTitle: "Close Tab")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        tabs.removeAll { $0.id == tab.id }
        if selectedTabID == tab.id {
            selectedTabID = tabs.last?.id
        }
        if tabs.isEmpty {
            newTab()
        } else {
            persist()
        }
    }

    func saveSelected(force: Bool = false) {
        guard let tab = selectedTab else { return }
        guard let url = resolvedURL(for: tab) else {
            saveAs(tab)
            return
        }

        if !force && diskHasChanged(for: tab, at: url) {
            presentSaveConflict(for: tab, url: url)
            return
        }
        write(tab, to: url)
    }

    func saveAsSelected() {
        guard let tab = selectedTab else { return }
        saveAs(tab)
    }

    func reloadSelected() {
        guard let tab = selectedTab else { return }
        reload(tab)
    }

    func keepSelectedBuffer() {
        selectedTab?.externalConflict = false
    }

    func zoomIn() {
        changeFontSize(by: 1)
    }

    func zoomOut() {
        changeFontSize(by: -1)
    }

    func resetZoom() {
        guard let tab = selectedTab else { return }
        tab.fontSize = 13
        persist()
    }

    func toggleLineWrap() {
        guard let tab = selectedTab else { return }
        tab.wrapsLines.toggle()
        persist()
    }

    func checkExternalChanges() {
        for tab in tabs {
            guard let url = resolvedURL(for: tab) else { continue }
            do {
                let fingerprint = try FileAccess.fingerprint(for: url)
                guard fingerprint != tab.diskFingerprint else { continue }
                if tab.isDirty {
                    tab.externalConflict = true
                } else {
                    let opened = try FileAccess.open(url)
                    tab.applyOpenedFile(opened, url: url)
                }
            } catch {
                tab.externalConflict = true
            }
        }
        persist()
    }

    func persistSynchronously() {
        store.persistAndWait(tabs: snapshots(), selectedTabID: selectedTabID)
    }

    private func restoreSession() {
        let restored = store.load()
        tabs = restored.tabs.map { DocumentTab(record: $0.record, text: $0.text) }
        selectedTabID = tabs.contains(where: { $0.id == restored.selectedTabID })
            ? restored.selectedTabID
            : tabs.first?.id
        untitledCounter = tabs
            .filter { !$0.hasDiskFile }
            .compactMap { tab -> Int? in
                guard tab.displayName.hasPrefix("Untitled ") else { return nil }
                return Int(tab.displayName.dropFirst("Untitled ".count))
            }
            .max() ?? 0
    }

    private func saveAs(_ tab: DocumentTab) {
        let panel = NSSavePanel()
        panel.title = "Save Plain Text"
        panel.nameFieldStringValue = tab.hasDiskFile ? tab.displayName : "Untitled.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(tab, to: url)
    }

    private func write(_ tab: DocumentTab, to url: URL) {
        do {
            let (bookmark, fingerprint) = try FileAccess.write(tab.text, to: url)
            tab.markSaved(bookmark: bookmark, fingerprint: fingerprint, url: url)
            persist()
        } catch {
            showError(title: "Couldn’t Save File", error: error)
        }
    }

    private func reload(_ tab: DocumentTab) {
        guard let url = resolvedURL(for: tab) else { return }
        if tab.isDirty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Reload “\(tab.displayName)” from disk?"
            alert.informativeText = "The persistent buffer’s unsaved changes will be discarded."
            alert.addButton(withTitle: "Reload")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            tab.applyOpenedFile(try FileAccess.open(url), url: url)
            persist()
        } catch {
            showError(title: "Couldn’t Reload File", error: error)
        }
    }

    private func presentSaveConflict(for tab: DocumentTab, url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "The file changed outside Simplepad"
        alert.informativeText = "Your persistent buffer has been kept. Choose which copy should win."
        alert.addButton(withTitle: "Save Anyway")
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Save As…")
        switch alert.runModal() {
        case .alertFirstButtonReturn: write(tab, to: url)
        case .alertSecondButtonReturn: reload(tab)
        case .alertThirdButtonReturn: saveAs(tab)
        default: break
        }
    }

    private func diskHasChanged(for tab: DocumentTab, at url: URL) -> Bool {
        FileAccess.hasChanged(from: tab.diskFingerprint, at: url)
    }

    private func resolvedURL(for tab: DocumentTab) -> URL? {
        FileAccess.resolve(bookmark: tab.fileBookmark, fallbackPath: tab.filePathFallback)
    }

    private func changeFontSize(by amount: Double) {
        guard let tab = selectedTab else { return }
        tab.fontSize = min(40, max(9, tab.fontSize + amount))
        persist()
    }

    private func persist() {
        store.persist(tabs: snapshots(), selectedTabID: selectedTabID)
    }

    private func snapshots() -> [PersistedTabSnapshot] {
        tabs.map { PersistedTabSnapshot(record: $0.record, text: $0.text) }
    }

    private func showError(title: String, error: Error) {
        let alert = NSAlert(error: error)
        alert.alertStyle = .warning
        alert.messageText = title
        alert.runModal()
    }
}
