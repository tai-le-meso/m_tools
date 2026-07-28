import SwiftUI
import Foundation

// Uses Foundation's native XMLDocument — no third-party XML package needed (CLAUDE.md
// bans SPM). XMLDocument is part of Foundation on macOS, same tier as JSONSerialization.

enum XMLBeautifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        do {
            let doc = try XMLDocument(xmlString: input, options: [.nodePreserveWhitespace])
            return doc.xmlString(options: [.nodePrettyPrint])
        } catch {
            throw DevToolError.invalidInput("Invalid XML: \(error.localizedDescription)")
        }
    }
}

enum XMLMinifyLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        do {
            let doc = try XMLDocument(xmlString: input, options: [])
            return doc.xmlString(options: [.nodeCompactEmptyElement])
        } catch {
            throw DevToolError.invalidInput("Invalid XML: \(error.localizedDescription)")
        }
    }
}

struct XMLToolView: View {
    var body: some View {
        ToolView(title: "XML Beautify/Minify", language: .xml, modes: [
            .init("Beautify", XMLBeautifyLogic.run),
            .init("Minify", XMLMinifyLogic.run),
        ])
    }
}
