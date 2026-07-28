import SwiftUI
import Foundation

/// Wraps raw SVG markup as a base64 data URI, ready to drop into a CSS `background-image`.
enum SVGToCSSLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.contains("<svg") else {
            throw DevToolError.invalidInput("Input doesn't look like SVG markup (missing an <svg> tag).")
        }
        guard let data = trimmed.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        let base64 = data.base64EncodedString()
        return "background-image: url(\"data:image/svg+xml;base64,\(base64)\");"
    }
}

struct SVGToCSSView: View {
    var body: some View {
        // Not tagged `.css`: the highlighter's key/value coloring only fires *inside* a
        // `{ }` rule block (needed so it doesn't also light up selector pseudo-classes like
        // `a:hover` as if they were declarations) — this tool's single bare
        // `property: value;` line, with no surrounding braces, wouldn't get colored anyway.
        ToolView(title: "SVG to CSS", transform: SVGToCSSLogic.run)
    }
}
