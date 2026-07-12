import AppKit
import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { model.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Open…") { model.showOpenPanel() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.saveSelected() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Save As…") { model.saveAsSelected() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Close Tab") { model.requestClose() }
                .keyboardShortcut("w", modifiers: .command)
        }

        CommandGroup(replacing: .textEditing) {
            Button("Find…") { showFindBar() }
                .keyboardShortcut("f", modifiers: .command)
        }

        CommandGroup(replacing: .toolbar) {
            Button("Zoom In") { model.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
            Button("Zoom Out") { model.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { model.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
            Toggle("Line Wrap", isOn: Binding(
                get: { model.selectedTab?.wrapsLines ?? true },
                set: { _ in model.toggleLineWrap() }
            ))
        }

        CommandGroup(replacing: .help) {
            Button("Simplepad Help") { showHelp() }
        }
    }

    private func showFindBar() {
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
    }

    private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Simplepad"
        alert.informativeText = "Use ⌘T for a new tab and ⌘O to open UTF-8 text. Open tabs are stored continuously and return after quitting or a crash. Closing a tab deliberately removes its persistent buffer."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
