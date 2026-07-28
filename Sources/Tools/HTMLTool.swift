import SwiftUI
import Foundation

enum HTMLBeautifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let nodes = try HTMLParser.parse(input)
        return HTMLParser.beautify(nodes)
    }
}

enum HTMLMinifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let nodes = try HTMLParser.parse(input)
        return HTMLParser.minify(nodes)
    }
}

struct HTMLToolView: View {
    var body: some View {
        ToolView(title: "HTML Beautify/Minify", language: .html, modes: [
            .init("Beautify", HTMLBeautifyLogic.run),
            .init("Minify", HTMLMinifyLogic.run),
        ])
    }
}
