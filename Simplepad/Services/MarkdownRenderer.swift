import AppKit

/// Renders markdown into a styled NSAttributedString for the read-only preview
/// window using only Foundation's built-in parser. Styling is intentionally
/// minimal and uses system semantic colors so light and dark mode adapt
/// automatically.
enum MarkdownRenderer {
    static func render(_ markdown: String, baseFontSize: CGFloat = 13) -> NSAttributedString {
        guard !markdown.isEmpty else { return NSAttributedString() }

        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return NSAttributedString(string: markdown, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor
            ])
        }

        let result = NSMutableAttributedString()
        var previous: Block?
        var previousAttributes: [NSAttributedString.Key: Any] = [:]

        for run in parsed.runs {
            let block = Block(run.presentationIntent?.components ?? [])
            var text = String(parsed[run.range].characters)
            if block.isThematicBreak {
                text = String(repeating: "─", count: 24)
            } else if block.isCodeBlock, text.hasSuffix("\n") {
                text.removeLast()
            }

            let blockAttributes = attributes(for: block, baseFontSize: baseFontSize)

            if let previous, previous.identity != block.identity {
                if block.tableRowIdentity != nil, block.tableRowIdentity == previous.tableRowIdentity {
                    result.append(NSAttributedString(string: "  |  ", attributes: blockAttributes))
                } else {
                    result.append(NSAttributedString(string: "\n", attributes: previousAttributes))
                }
            }

            if let item = block.listItemIdentity, item != previous?.listItemIdentity {
                let prefix = block.listIsOrdered ? "\(block.listItemOrdinal).  " : "•  "
                result.append(NSAttributedString(string: prefix, attributes: blockAttributes))
            }

            var runAttributes = blockAttributes
            applyInlineStyles(
                intent: run.inlinePresentationIntent,
                link: run.link,
                to: &runAttributes
            )
            result.append(NSAttributedString(string: text, attributes: runAttributes))

            previous = block
            previousAttributes = blockAttributes
        }
        return result
    }

    // MARK: - Block context

    /// The block-level context of a run, derived from its presentation-intent
    /// components (ordered innermost to outermost).
    private struct Block {
        var identity = -1
        var headerLevel: Int?
        var isCodeBlock = false
        var isBlockQuote = false
        var isThematicBreak = false
        var listDepth = 0
        var listItemIdentity: Int?
        var listItemOrdinal = 0
        var listIsOrdered = false
        var isTableCell = false
        var isTableHeaderCell = false
        var tableRowIdentity: Int?

        init(_ components: [PresentationIntent.IntentType]) {
            identity = components.first?.identity ?? -1
            for (index, component) in components.enumerated() {
                switch component.kind {
                case .header(let level):
                    headerLevel = level
                case .codeBlock:
                    isCodeBlock = true
                case .blockQuote:
                    isBlockQuote = true
                case .thematicBreak:
                    isThematicBreak = true
                case .listItem(let ordinal):
                    if listItemIdentity == nil {
                        listItemIdentity = component.identity
                        listItemOrdinal = ordinal
                        if index + 1 < components.count,
                           case .orderedList = components[index + 1].kind {
                            listIsOrdered = true
                        }
                    }
                case .orderedList, .unorderedList:
                    listDepth += 1
                case .tableCell:
                    isTableCell = true
                case .tableHeaderRow:
                    isTableHeaderCell = true
                    tableRowIdentity = component.identity
                case .tableRow:
                    tableRowIdentity = component.identity
                default:
                    break
                }
            }
        }
    }

    // MARK: - Styling

    private static func attributes(
        for block: Block,
        baseFontSize: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        var font = NSFont.systemFont(ofSize: baseFontSize)
        var color = NSColor.textColor
        var background: NSColor?
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = baseFontSize * 0.5

        if let level = block.headerLevel {
            let scales: [CGFloat] = [2.0, 1.6, 1.3, 1.15, 1.0, 1.0]
            let scale = scales[min(max(level, 1), 6) - 1]
            font = .systemFont(ofSize: baseFontSize * scale, weight: level >= 5 ? .semibold : .bold)
            paragraph.paragraphSpacingBefore = baseFontSize * 0.8
            paragraph.paragraphSpacing = baseFontSize * 0.3
        }
        if block.isCodeBlock {
            font = .monospacedSystemFont(ofSize: baseFontSize * 0.92, weight: .regular)
            background = .quaternarySystemFill
            paragraph.firstLineHeadIndent = 12
            paragraph.headIndent = 12
        }
        if block.isBlockQuote {
            color = .secondaryLabelColor
            font = applying(traits: .italic, to: font)
            paragraph.firstLineHeadIndent += 14
            paragraph.headIndent += 14
        }
        if block.listDepth > 0 {
            let indent = CGFloat(block.listDepth) * 20
            paragraph.firstLineHeadIndent += indent
            // Hanging indent so wrapped lines align past the bullet.
            paragraph.headIndent += indent + 16
            paragraph.paragraphSpacing = baseFontSize * 0.2
        }
        if block.isTableCell {
            font = .monospacedSystemFont(
                ofSize: baseFontSize * 0.92,
                weight: block.isTableHeaderCell ? .semibold : .regular
            )
            paragraph.paragraphSpacing = baseFontSize * 0.15
        }
        if block.isThematicBreak {
            color = .tertiaryLabelColor
            paragraph.alignment = .center
            paragraph.paragraphSpacingBefore = baseFontSize * 0.6
            paragraph.paragraphSpacing = baseFontSize * 0.6
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if let background {
            attributes[.backgroundColor] = background
        }
        return attributes
    }

    private static func applyInlineStyles(
        intent: InlinePresentationIntent?,
        link: URL?,
        to attributes: inout [NSAttributedString.Key: Any]
    ) {
        if let intent {
            var font = attributes[.font] as? NSFont ?? .systemFont(ofSize: NSFont.systemFontSize)
            if intent.contains(.stronglyEmphasized) {
                font = applying(traits: .bold, to: font)
            }
            if intent.contains(.emphasized) {
                font = applying(traits: .italic, to: font)
            }
            if intent.contains(.code) {
                font = .monospacedSystemFont(ofSize: font.pointSize * 0.92, weight: .regular)
                attributes[.backgroundColor] = NSColor.quaternarySystemFill
            }
            if intent.contains(.strikethrough) {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            attributes[.font] = font
        }
        if let link {
            attributes[.link] = link
        }
    }

    private static func applying(traits: NSFontDescriptor.SymbolicTraits, to font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(
            font.fontDescriptor.symbolicTraits.union(traits)
        )
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }
}
