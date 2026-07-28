import SwiftUI
import Foundation

/// Auto-detects direction: an all-digit input is treated as a Unix timestamp (seconds,
/// or milliseconds if it has 13+ digits) and converted to human-readable dates; anything
/// else is parsed as an ISO 8601 date string and converted back to a Unix timestamp.
enum UnixTimeConverterLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let seconds = Double(trimmed) {
            let digitCount = trimmed.filter(\.isNumber).count
            let isMillis = digitCount >= 13
            let date = Date(timeIntervalSince1970: isMillis ? seconds / 1000 : seconds)

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let utcFormatter = DateFormatter()
            utcFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'UTC'"
            utcFormatter.timeZone = TimeZone(identifier: "UTC")

            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

            return """
            ISO 8601: \(iso.string(from: date))
            UTC:      \(utcFormatter.string(from: date))
            Local:    \(localFormatter.string(from: date))
            Unix (s): \(Int(date.timeIntervalSince1970))
            """
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]

        guard let date = iso.date(from: trimmed) ?? isoNoFraction.date(from: trimmed) else {
            throw DevToolError.invalidInput("Not a recognizable Unix timestamp or ISO 8601 date.")
        }
        return """
        Unix (s):  \(Int(date.timeIntervalSince1970))
        Unix (ms): \(Int64(date.timeIntervalSince1970 * 1000))
        """
    }
}

struct UnixTimeConverterView: View {
    var body: some View {
        ToolView(title: "Unix Time Converter", transform: UnixTimeConverterLogic.run)
    }
}
