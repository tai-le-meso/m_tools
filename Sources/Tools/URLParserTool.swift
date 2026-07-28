import SwiftUI
import Foundation

/// Breaks a URL (or bare query string) into its parts via `URLComponents` — native
/// framework, no parsing needed by hand.
enum URLParserLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Reject interior whitespace before handing anything to URLComponents. Recent
        // Foundation versions happily accept a string like "not a url at all" and report the
        // whole thing as a relative `path`, which is useless output from a URL parser — and
        // a space is never legal unescaped in a URL (RFC 3986) regardless. Checking here
        // rather than relying on URLComponents returning nil also means the error message
        // can say what to do about it. Leading/trailing whitespace was already trimmed
        // above, so anything found now is genuinely inside the input.
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw DevToolError.invalidInput(
                "A URL can't contain unescaped spaces — percent-encode them as %20."
            )
        }

        guard let components = URLComponents(string: trimmed) else {
            throw DevToolError.invalidInput("Couldn't parse as a URL.")
        }

        var lines: [String] = []
        if let scheme = components.scheme { lines.append("scheme:   \(scheme)") }
        if let user = components.user { lines.append("user:     \(user)") }
        if let host = components.host { lines.append("host:     \(host)") }
        if let port = components.port { lines.append("port:     \(port)") }
        if !components.path.isEmpty { lines.append("path:     \(components.path)") }
        if let fragment = components.fragment { lines.append("fragment: \(fragment)") }
        if let items = components.queryItems, !items.isEmpty {
            lines.append("query:")
            for item in items {
                lines.append("  \(item.name) = \(item.value ?? "")")
            }
        }

        guard !lines.isEmpty else {
            throw DevToolError.invalidInput("No recognizable URL components found.")
        }
        return lines.joined(separator: "\n")
    }
}

struct URLParserView: View {
    var body: some View {
        ToolView(title: "URL Parser", transform: URLParserLogic.run)
    }
}
