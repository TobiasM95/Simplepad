import Foundation
import XCTest
@testable import Simplepad

final class PlainTextCodecTests: XCTestCase {
    func testDecodesUTF8() throws {
        let text = "Hello, 世界 👋"
        XCTAssertEqual(try PlainTextCodec.decode(Data(text.utf8)), text)
    }

    func testStripsUTF8BOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("plain text".utf8))
        XCTAssertEqual(try PlainTextCodec.decode(data), "plain text")
    }

    func testRejectsInvalidUTF8() {
        XCTAssertThrowsError(try PlainTextCodec.decode(Data([0xC3, 0x28]))) { error in
            XCTAssertEqual(error as? PlainTextCodecError, .invalidUTF8)
        }
    }

    func testEncodingNeverAddsBOM() {
        let data = PlainTextCodec.encode("text")
        XCTAssertEqual(Array(data.prefix(3)), [0x74, 0x65, 0x78])
    }
}

