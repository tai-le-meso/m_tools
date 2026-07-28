import SwiftUI
import Foundation

/// Auto-detects direction, same pattern as `Base64Logic`: if percent-decoding would
/// actually change the input, decode it; otherwise percent-encode it.
enum URLEncodeDecodeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }

        if let decoded = input.removingPercentEncoding, decoded != input {
            return decoded
        }
        guard let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw DevToolError.invalidInput("Couldn't URL-encode this input.")
        }
        return encoded
    }
}

struct URLEncodeDecodeView: View {
    var body: some View {
        ToolView(title: "URL Encode/Decode", transform: URLEncodeDecodeLogic.run)
    }
}
