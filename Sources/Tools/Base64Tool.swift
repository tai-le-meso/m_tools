import SwiftUI
import Foundation

/// Auto-detects direction: if the input decodes cleanly as Base64, decode it; otherwise
/// encode it. Matches the "smart" feel of the original DevUtils tool.
enum Base64Logic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeBase64(trimmed), let data = Data(base64Encoded: trimmed) {
            return String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        }
        guard let data = input.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        return data.base64EncodedString()
    }

    private static func looksLikeBase64(_ s: String) -> Bool {
        guard s.count % 4 == 0, s.count > 0 else { return false }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

struct Base64ToolView: View {
    var body: some View {
        ToolView(title: "Base64", transform: Base64Logic.run)
    }
}
