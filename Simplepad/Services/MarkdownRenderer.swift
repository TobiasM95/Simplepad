import AppKit

/// Renders markdown into a styled NSAttributedString for the read-only preview
/// window using only Foundation's built-in parser. Styling is intentionally
/// minimal and uses system semantic colors so light and dark mode adapt
/// automatically. Tables and the rules under level 1-2 headings use
/// NSTextTable blocks, which require the preview text view to lay out with
/// TextKit 1.
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
        var blockAttributes: [NSAttributedString.Key: Any] = [:]
        var tables: [Int: NSTextTable] = [:]

        for run in parsed.runs {
            let block = Block(run.presentationIntent?.components ?? [])
            var text = String(parsed[run.range].characters)
            if block.isThematicBreak {
                text = String(repeating: "─", count: 24)
            } else if block.isCodeBlock, text.hasSuffix("\n") {
                text.removeLast()
            }

            if previous == nil || previous?.identity != block.identity {
                if previous != nil {
                    // Terminate the previous paragraph with its own attributes
                    // so paragraph styles (including text blocks) apply to it.
                    result.append(NSAttributedString(string: "\n", attributes: blockAttributes))
                }
                blockAttributes = attributes(for: block, baseFontSize: baseFontSize, tables: &tables)
                if let item = block.listItemIdentity, item != previous?.listItemIdentity {
                    let prefix = block.listIsOrdered ? "\(block.listItemOrdinal).  " : "•  "
                    result.append(NSAttributedString(string: prefix, attributes: blockAttributes))
                }
            }

            var runAttributes = blockAttributes
            applyInlineStyles(
                intent: run.inlinePresentationIntent,
                link: run.link,
                to: &runAttributes
            )
            result.append(NSAttributedString(string: text, attributes: runAttributes))
            previous = block
        }

        // Paragraphs carrying text blocks (table cells, underlined headings)
        // must be newline-terminated for the block layout to apply.
        if let last = previous, last.isTableCell || last.hasHeadingRule {
            result.append(NSAttributedString(string: "\n", attributes: blockAttributes))
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
        var tableIdentity: Int?
        var tableColumnCount = 1
        var tableColumnIndex = 0
        var tableRowIndex = 0

        var hasHeadingRule: Bool { headerLevel.map { $0 <= 2 } ?? false }

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
                case .tableCell(let columnIndex):
                    isTableCell = true
                    tableColumnIndex = columnIndex
                case .tableHeaderRow:
                    isTableHeaderCell = true
                    tableRowIndex = 0
                case .tableRow(let rowIndex):
                    tableRowIndex = rowIndex
                case .table(let columns):
                    tableIdentity = component.identity
                    tableColumnCount = columns.count
                default:
                    break
                }
            }
        }
    }

    // MARK: - Styling

    private static func attributes(
        for block: Block,
        baseFontSize: CGFloat,
        tables: inout [Int: NSTextTable]
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
            if block.hasHeadingRule {
                paragraph.textBlocks = [headingRuleBlock(baseFontSize: baseFontSize)]
            }
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
        if block.isTableCell, let tableID = block.tableIdentity {
            let table = tables[tableID] ?? {
                let table = NSTextTable()
                table.numberOfColumns = max(block.tableColumnCount, 1)
                table.collapsesBorders = true
                tables[tableID] = table
                return table
            }()
            paragraph.textBlocks = [tableCellBlock(in: table, for: block)]
            paragraph.paragraphSpacing = 0
            if block.isTableHeaderCell {
                font = .systemFont(ofSize: baseFontSize, weight: .semibold)
            }
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

    /// A full-width single-cell table whose bottom border draws the rule under
    /// level 1-2 headings.
    private static func headingRuleBlock(baseFontSize: CGFloat) -> NSTextTableBlock {
        let table = NSTextTable()
        table.numberOfColumns = 1
        let block = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        block.setBorderColor(.separatorColor)
        block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
        block.setWidth(baseFontSize * 0.25, type: .absoluteValueType, for: .padding, edge: .maxY)
        return block
    }

    private static func tableCellBlock(in table: NSTextTable, for block: Block) -> NSTextTableBlock {
        let cell = NSTextTableBlock(
            table: table,
            startingRow: block.tableRowIndex,
            rowSpan: 1,
            startingColumn: block.tableColumnIndex,
            columnSpan: 1
        )
        cell.setBorderColor(.separatorColor)
        cell.setWidth(1, type: .absoluteValueType, for: .border)
        cell.setWidth(5, type: .absoluteValueType, for: .padding)
        if block.isTableHeaderCell {
            cell.backgroundColor = .quaternarySystemFill
        }
        return cell
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
