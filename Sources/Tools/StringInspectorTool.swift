import SwiftUI
import Foundation

enum StringInspectorLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.isEmpty else { return "" }
        let characters = input.count
        let bytes = input.utf8.count
        let lines = input.components(separatedBy: "\n").count
        let words = input.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count

        return """
        Characters:    \(characters)
        Bytes (UTF-8): \(bytes)
        Lines:         \(lines)
        Words:         \(words)
        """
    }
}

struct StringInspectorView: View {
    var body: some View {
        ToolView(title: "String Inspector", transform: StringInspectorLogic.run)
    }
}
