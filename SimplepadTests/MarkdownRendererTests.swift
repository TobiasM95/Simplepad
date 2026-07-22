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
        XCTAssertEqual(rendered.string, "Title")
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

    func testLinkAttributeIsCopied() throws {
        let rendered = MarkdownRenderer.render("[site](https://example.com)")
        let link = try XCTUnwrap(rendered.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        XCTAssertEqual(link.absoluteString, "https://example.com")
    }
}
