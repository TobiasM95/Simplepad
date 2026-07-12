import CryptoKit
import Foundation

enum PlainTextCodecError: LocalizedError, Equatable {
    case invalidUTF8

    var errorDescription: String? {
        "The file is not valid UTF-8 plain text."
    }
}

enum PlainTextCodec {
    static func decode(_ data: Data) throws -> String {
        guard var text = String(data: data, encoding: .utf8) else {
            throw PlainTextCodecError.invalidUTF8
        }
        if text.first == "\u{FEFF}" {
            text.removeFirst()
        }
        return text
    }

    static func encode(_ text: String) -> Data {
        Data(text.utf8)
    }

    static func hash(_ text: String) -> String {
        hash(encode(text))
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

