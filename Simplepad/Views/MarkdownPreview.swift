import AppKit
import Combine
import SwiftUI

struct MarkdownPreviewWindow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if let tab = model.selectedTab {
                MarkdownPreviewContent(tab: tab)
                    .id(tab.id)
            } else {
                ContentUnavailableView("Nothing to Preview", systemImage: "doc.richtext")
            }
        }
        .frame(minWidth: 380, minHeight: 300)
    }
}

private struct MarkdownPreviewContent: View {
    @ObservedObject var tab: DocumentTab
    @State private var rendered = NSAttributedString()

    var body: some View {
        Group {
            if tab.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Nothing to Preview",
                    systemImage: "doc.richtext",
                    description: Text("Start typing markdown in this tab.")
                )
            } else {
                ReadOnlyAttributedTextView(content: rendered)
            }
        }
        .onAppear { rendered = MarkdownRenderer.render(tab.text) }
        .onReceive(
            tab.$text
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .removeDuplicates()
        ) { text in
            rendered = MarkdownRenderer.render(text)
        }
    }
}

private struct ReadOnlyAttributedTextView: NSViewRepresentable {
    let content: NSAttributedString

    final class Coordinator {
        var lastContent: NSAttributedString?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        // Explicit TextKit 1 stack: NSTextTable (tables, heading rules) needs
        // it, and non-contiguous layout keeps scrolling smooth on long docs.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(
            containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        layoutManager.addTextContainer(container)

        let textView = NSTextView(frame: .zero, textContainer: container)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 14)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityIdentifier("markdown-preview")
        textView.textStorage?.setAttributedString(content)
        context.coordinator.lastContent = content

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if context.coordinator.lastContent !== content {
            let offset = scrollView.contentView.bounds.origin
            textView.textStorage?.setAttributedString(content)
            context.coordinator.lastContent = content
            if offset.y > 0 {
                textView.scroll(offset)
            }
        }
    }
}
