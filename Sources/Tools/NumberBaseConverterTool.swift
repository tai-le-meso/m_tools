import SwiftUI
import Foundation

/// Auto-detects the input base from its prefix (0x/0b/0o, else decimal) and shows the
/// value in all four bases — no UI toggle needed since detection covers the common cases.
enum NumberBaseConverterLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var body = trimmed
        var negative = false
        if body.hasPrefix("-") { negative = true; body.removeFirst() }

        let parsed: Int64?
        if body.hasPrefix("0x") || body.hasPrefix("0X") {
            parsed = Int64(body.dropFirst(2), radix: 16)
        } else if body.hasPrefix("0b") || body.hasPrefix("0B") {
            parsed = Int64(body.dropFirst(2), radix: 2)
        } else if body.hasPrefix("0o") || body.hasPrefix("0O") {
            parsed = Int64(body.dropFirst(2), radix: 8)
        } else {
            parsed = Int64(body)
        }

        guard let magnitude = parsed else {
            throw DevToolError.invalidInput(
                "Not a recognizable integer — use decimal, 0x hex, 0b binary, or 0o octal."
            )
        }
        let value = negative ? -magnitude : magnitude
        let sign = value < 0 ? "-" : ""
        let abs = magnitude

        return """
        Binary:  \(sign)\(String(abs, radix: 2))
        Octal:   \(sign)\(String(abs, radix: 8))
        Decimal: \(value)
        Hex:     \(sign)\(String(abs, radix: 16))
        """
    }
}

struct NumberBaseConverterView: View {
    var body: some View {
        ToolView(title: "Number Base Converter", transform: NumberBaseConverterLogic.run)
    }
}
