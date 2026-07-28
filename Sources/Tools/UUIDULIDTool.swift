import SwiftUI
import Foundation

/// Ignores the input text and mints fresh identifiers every time it runs — a "reroll"
/// generator, same spirit as the upstream DevUtils tool. Typing anything into the input
/// (even a single character) triggers a fresh UUID v4 + ULID pair.
enum UUIDULIDGenerateLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        // Ignores `input` entirely (beyond being the thing that triggers a re-roll) —
        // always returns a fresh pair, including on the tool's very first appearance.
        "UUID: \(UUID().uuidString.lowercased())\nULID: \(ULID.generate())"
    }
}

/// Parses a pasted UUID or ULID and reports what it is.
enum UUIDULIDDecodeLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let uuid = UUID(uuidString: trimmed) {
            let hex = trimmed.replacingOccurrences(of: "-", with: "")
            let versionChar = hex.count == 32 ? Array(hex)[12] : "?"
            return """
            Type:      UUID
            Version:   \(versionChar)
            Canonical: \(uuid.uuidString.lowercased())
            """
        }

        if ULID.isValid(trimmed), let date = ULID.timestamp(from: trimmed) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return """
            Type:      ULID
            Timestamp: \(formatter.string(from: date))
            """
        }

        throw DevToolError.invalidInput("Not a recognizable UUID or ULID.")
    }
}

struct UUIDULIDToolView: View {
    var body: some View {
        ToolView(title: "UUID/ULID", modes: [
            .init("Generate", UUIDULIDGenerateLogic.run),
            .init("Decode", UUIDULIDDecodeLogic.run),
        ])
    }
}
