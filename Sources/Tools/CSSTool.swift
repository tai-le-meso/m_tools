import SwiftUI
import Foundation

enum CSSBeautifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let rules = try CSSParser.parse(input)
        return CSSParser.beautify(rules)
    }
}

enum CSSMinifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let rules = try CSSParser.parse(input)
        return CSSParser.minify(rules)
    }
}

struct CSSToolView: View {
    var body: some View {
        ToolView(title: "CSS Beautify/Minify", language: .css, modes: [
            .init("Beautify", CSSBeautifyLogic.run),
            .init("Minify", CSSMinifyLogic.run),
        ])
    }
}
