import SwiftUI
import Foundation

/// Auto-detects direction like `Base64Logic`: if the (whitespace-stripped) input looks
/// like a valid hex byte string, decode it to text; otherwise encode the input to hex.
enum HexAsciiLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }

        let cleaned = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")

        if looksLikeHex(cleaned) {
            var bytes: [UInt8] = []
            var idx = cleaned.startIndex
            while idx < cleaned.endIndex {
                let next = cleaned.index(idx, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
                guard let byte = UInt8(cleaned[idx..<next], radix: 16) else {
                    throw DevToolError.invalidInput("Invalid hex byte: \(cleaned[idx..<next])")
                }
                bytes.append(byte)
                idx = next
            }
            return String(bytes: bytes, encoding: .utf8)
                ?? bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        }

        return input.utf8.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func looksLikeHex(_ s: String) -> Bool {
        guard !s.isEmpty, s.count % 2 == 0 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

struct HexAsciiView: View {
    var body: some View {
        ToolView(title: "Hex ⇄ ASCII", transform: HexAsciiLogic.run)
    }
}
