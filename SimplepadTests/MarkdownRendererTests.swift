import AppKit
import XCTest
@testable import Simplepad

final class MarkdownRendererTests: XCTestCase {
    func testEmptyInputRendersEmptyString() {
        XCTAssertEqual(MarkdownRenderer.render("").length, 0)
    }

    func testPlainTextSurvivesUnchanged() throws {
        let rendered = MarkdownRenderer.render("hello world", baseFontSize: 13)
        XCTAssertEqual(rendered.string, "hello world")
        let font = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font.pointSize, 13)
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testHeadingIsBoldAndLarger() throws {
        let rendered = MarkdownRenderer.render("# Title", baseFontSize: 13)
        XCTAssertEqual(rendered.string, "Title\n")
        let font = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertGreaterThan(font.pointSize, 13)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testInlineBoldAndItalicTraits() throws {
        let rendered = MarkdownRenderer.render("**bold** and *italic*")
        let text = rendered.string as NSString

        let boldRange = text.range(of: "bold")
        let boldFont = try XCTUnwrap(
            rendered.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(boldFont.fontDescriptor.symbolicTraits.contains(.bold))

        let italicRange = text.range(of: "italic")
        let italicFont = try XCTUnwrap(
            rendered.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(italicFont.fontDescriptor.symbolicTraits.contains(.italic))
    }

    func testCodeBlockIsMonospacedWithBackground() throws {
        let rendered = MarkdownRenderer.render("```\nlet x = 1\n```")
        let range = (rendered.string as NSString).range(of: "let x = 1")
        XCTAssertNotEqual(range.location, NSNotFound)
        let font = try XCTUnwrap(
            rendered.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(font.isFixedPitch)
        XCTAssertNotNil(rendered.attribute(.backgroundColor, at: range.location, effectiveRange: nil))
    }

    func testUnorderedListGetsBulletsAndIndent() throws {
        let rendered = MarkdownRenderer.render("- one\n- two")
        XCTAssertEqual(rendered.string, "•  one\n•  two")
        let style = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        XCTAssertGreaterThan(style.headIndent, 0)
    }

    func testOrderedListUsesOrdinals() {
        let rendered = MarkdownRenderer.render("1. first\n2. second")
        XCTAssertEqual(rendered.string, "1.  first\n2.  second")
    }

    func testBlockquoteUsesSecondaryColor() throws {
        let rendered = MarkdownRenderer.render("> quote")
        let range = (rendered.string as NSString).range(of: "quote")
        let color = try XCTUnwrap(
            rendered.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
        )
        XCTAssertEqual(color, NSColor.secondaryLabelColor)
    }

    func testLevelTwoHeadingGetsUnderlineRule() throws {
        let rendered = MarkdownRenderer.render("## 1. Project identity")
        let style = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        XCTAssertEqual(style.textBlocks.count, 1)
        XCTAssertTrue(rendered.string.hasSuffix("\n"))
    }

    func testLevelThreeHeadingHasNoUnderlineRule() throws {
        let rendered = MarkdownRenderer.render("### Sub")
        let style = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        XCTAssertTrue(style.textBlocks.isEmpty)
    }

    func testTableRendersCellsAsTextTableBlocks() throws {
        let rendered = MarkdownRenderer.render("| a | b |\n| - | - |\n| 1 | 2 |")
        let text = rendered.string as NSString
        for cell in ["a", "b", "1", "2"] {
            XCTAssertNotEqual(text.range(of: cell).location, NSNotFound)
        }

        let headerStyle = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: text.range(of: "a").location, effectiveRange: nil)
                as? NSParagraphStyle
        )
        let headerBlock = try XCTUnwrap(headerStyle.textBlocks.first as? NSTextTableBlock)
        XCTAssertNotNil(headerBlock.backgroundColor)

        let bodyStyle = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: text.range(of: "1").location, effectiveRange: nil)
                as? NSParagraphStyle
        )
        let bodyBlock = try XCTUnwrap(bodyStyle.textBlocks.first as? NSTextTableBlock)
        XCTAssertNil(bodyBlock.backgroundColor)
        XCTAssertTrue(headerBlock.table === bodyBlock.table)
        XCTAssertEqual(headerBlock.table.numberOfColumns, 2)
    }

    func testLinkAttributeIsCopied() throws {
        let rendered = MarkdownRenderer.render("[site](https://example.com)")
        let link = try XCTUnwrap(rendered.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        XCTAssertEqual(link.absoluteString, "https://example.com")
    }
}
