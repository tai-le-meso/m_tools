import SwiftUI
import Foundation

/// Flattens a JSON array of objects into CSV — headers are the union of every object's
/// keys, sorted alphabetically for deterministic column order (Swift's `Dictionary`
/// iteration order isn't stable across runs, so "first-seen order" would silently
/// reshuffle columns between runs of the exact same input).
enum JSONToCSVLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        guard let data = input.data(using: .utf8) else {
            throw DevToolError.invalidInput("Input isn't valid UTF-8 text.")
        }
        guard let raw = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let array = raw as? [[String: Any]], !array.isEmpty else {
            throw DevToolError.invalidInput(#"Expected a JSON array of flat objects, e.g. [{"a":1}]."#)
        }

        var headerSet: Set<String> = []
        for obj in array { headerSet.formUnion(obj.keys) }
        let headers = headerSet.sorted()

        var lines = [headers.map(csvField).joined(separator: ",")]
        for obj in array {
            let row = headers.map { csvField(stringify(obj[$0])) }
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func stringify(_ value: Any?) -> String {
        guard let value else { return "" }
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case is NSNull: return ""
        default: return "\(value)"
        }
    }

    private static func csvField(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

/// Parses CSV (quoted fields, embedded commas/newlines, doubled-quote escaping) using the
/// first row as headers, and emits an array of JSON objects.
enum CSVToJSONLogic: DevToolLogic {
    static func run(_ input: String) throws -> String {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let rows = parseCSV(input)
        guard let header = rows.first else { return "[]" }

        var objects: [[String: Any]] = []
        for row in rows.dropFirst() {
            var obj: [String: Any] = [:]
            for (index, key) in header.enumerated() where index < row.count {
                obj[key] = row[index]
            }
            objects.append(obj)
        }
        let data = try JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseCSV(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\""); i += 2; continue
                    }
                    inQuotes = false; i += 1
                } else {
                    field.append(c); i += 1
                }
            } else if c == "\"" {
                inQuotes = true; i += 1
            } else if c == "," {
                row.append(field); field = ""; i += 1
            } else if c.isNewline {
                // `c.isNewline` (not `c == "\n" || c == "\r"`) is required here: Swift's
                // `Character` is a grapheme cluster, and a CRLF pair from a real-world
                // CSV collapses into a *single* Character equal to neither "\n" nor "\r"
                // alone — a literal comparison silently never matches, so the whole file
                // reads as one row. `.isNewline` matches LF, CR, and CRLF as one row
                // terminator. (Same bug, same fix, as CSVDocument.parseRows.)
                row.append(field); field = ""
                rows.append(row); row = []
                i += 1
            } else {
                field.append(c); i += 1
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}

struct JSONCSVToolView: View {
    var body: some View {
        ToolView(title: "JSON ⇄ CSV", modes: [
            .init("JSON → CSV", JSONToCSVLogic.run), // CSV output — no highlighter for it yet
            .init("CSV → JSON", language: .json, CSVToJSONLogic.run),
        ])
    }
}
