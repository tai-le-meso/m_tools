import SwiftUI
import Foundation

/// Auto-detects direction, reusing `HTMLParser`'s entity table: if decoding would actually
/// change the input, decode it; otherwise encode the handful of characters that matter
/// (&, <, >) for safe HTML embedding.
enum HTMLEntityLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }
        let decoded = HTMLParser.decodeEntities(input)
        if decoded != input {
            return decoded
        }
        return HTMLParser.encodeEntities(input)
    }
}

struct HTMLEntityView: View {
    var body: some View {
        ToolView(title: "HTML Entity Encode/Decode", transform: HTMLEntityLogic.run)
    }
}
