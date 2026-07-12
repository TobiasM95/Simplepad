import SwiftUI

struct TabBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(model.tabs) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: model.selectedTabID == tab.id,
                        select: { model.select(tab) },
                        close: { model.requestClose(tab) }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityIdentifier("tab-bar")
    }
}

private struct TabButton: View {
    @ObservedObject var tab: DocumentTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: select) {
                HStack(spacing: 5) {
                    Text(tab.displayName)
                        .lineLimit(1)
                    if tab.isDirty {
                        Circle()
                            .frame(width: 6, height: 6)
                            .accessibilityLabel("Unsaved changes")
                    }
                }
                .frame(maxWidth: 180)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tab-select-\(tab.id.uuidString)")

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(tab.displayName)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.secondary.opacity(0.25) : .clear)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tab-\(tab.id.uuidString)")
    }
}
