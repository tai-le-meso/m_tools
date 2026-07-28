import SwiftUI
import Foundation

/// Splits a JWT into its 3 dot-separated parts, base64url-decodes the header/payload as
/// pretty JSON, and flags whether an `exp` claim has passed. No signature verification —
/// this is a debugger, not a validator (matches the upstream DevUtils tool's scope).
enum JWTDebuggerLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let parts = trimmed.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw DevToolError.invalidInput("A JWT has 3 dot-separated parts (header.payload.signature).")
        }

        let header = try decodeSegment(parts[0], name: "header")
        let payload = try decodeSegment(parts[1], name: "payload")

        var result = "HEADER:\n\(header)\n\nPAYLOAD:\n\(payload)"
        if let expiry = expiryLine(fromPayloadJSON: payload) {
            result += "\n\n\(expiry)"
        }
        return result
    }

    private static func decodeSegment(_ segment: String, name: String) throws -> String {
        guard let data = base64URLDecode(segment) else {
            throw DevToolError.invalidInput("Couldn't base64url-decode the \(name).")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return String(data: data, encoding: .utf8) ?? "(binary \(name))"
        }
        let pretty = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        return String(data: pretty, encoding: .utf8) ?? ""
    }

    private static func base64URLDecode(_ s: String) -> Data? {
        var base64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        return Data(base64Encoded: base64)
    }

    private static func expiryLine(fromPayloadJSON payloadJSON: String) -> String? {
        guard let data = payloadJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expNumber = obj["exp"] as? NSNumber else { return nil }
        let date = Date(timeIntervalSince1970: expNumber.doubleValue)
        let expired = date < Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "Expires: \(formatter.string(from: date)) (\(expired ? "EXPIRED" : "valid"))"
    }
}

struct JWTDebuggerView: View {
    var body: some View {
        // The output is mostly two pretty-printed JSON blocks (header/payload) wrapped in
        // plain "HEADER:"/"PAYLOAD:"/"Expires:" labels — the JSON tokenizer only lights up
        // strings/numbers/keywords/punctuation it actually recognizes, so the label lines
        // just render as plain text alongside the highlighted JSON.
        ToolView(title: "JWT Debugger", language: .json, transform: JWTDebuggerLogic.run)
    }
}
