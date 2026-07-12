import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TabBar(model: model)
            if let tab = model.selectedTab {
                EditorPane(model: model, tab: tab)
                    .id(tab.id)
            }
        }
        .frame(minWidth: 520, minHeight: 320)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.checkExternalChanges()
        }
        .onOpenURL { url in
            model.openFile(url)
        }
    }
}

private struct EditorPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(spacing: 0) {
            if tab.externalConflict {
                ConflictBanner(model: model, tab: tab)
            }
            PlainTextEditor(
                text: Binding(
                    get: { tab.text },
                    set: { model.updateText(in: tab, to: $0) }
                ),
                wrapsLines: tab.wrapsLines,
                fontSize: tab.fontSize,
                focusRequest: model.editorFocusRequest
            )
        }
    }
}

private struct ConflictBanner: View {
    @ObservedObject var model: AppModel
    @ObservedObject var tab: DocumentTab

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("This file changed or disappeared outside Simplepad. Your buffer is safe.")
                .lineLimit(1)
            Spacer()
            Button("Keep Buffer") { model.keepSelectedBuffer() }
            Button("Reload") { model.reloadSelected() }
            Button("Save As…") { model.saveAsSelected() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityIdentifier("file-conflict-banner")
    }
}

