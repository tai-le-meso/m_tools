import Foundation

/// A selectable CSV delimiter — comma covers most files, but semicolon/tab/pipe are common
/// real-world exports, plus an arbitrary single custom character for anything else.
enum CSVDelimiter: Hashable {
    case comma, semicolon, tab, pipe, custom

    static let presets: [CSVDelimiter] = [.comma, .semicolon, .tab, .pipe, .custom]

    var label: String {
        switch self {
        case .comma: return "Comma (,)"
        case .semicolon: return "Semicolon (;)"
        case .tab: return "Tab"
        case .pipe: return "Pipe (|)"
        case .custom: return "Custom…"
        }
    }

    /// Resolves to an actual delimiter character. `customCharacter` is only consulted for
    /// `.custom`, falling back to comma if it's empty (e.g. not filled in yet).
    func resolve(customCharacter: String) -> Character {
        switch self {
        case .comma: return ","
        case .semicolon: return ";"
        case .tab: return "\t"
        case .pipe: return "|"
        case .custom: return customCharacter.first ?? ","
        }
    }
}

/// Pure CSV model backing the CSV Editor tool — parsing, serializing, and row/column
/// mutation, with zero SwiftUI so it's testable on its own (same split as every other
/// tool's `Logic` type). Rows are padded/truncated to `headers.count` on read so the grid
/// never has to special-case ragged input.
struct CSVDocument: Equatable {
    var headers: [String]
    var rows: [[String]]

    static let empty = CSVDocument(headers: ["Column 1"], rows: [[""]])

    // MARK: - Parse

    /// `delimiter` defaults to comma, but any single character works — semicolon, tab, and
    /// pipe are common real-world exports (e.g. semicolon-delimited CSV from European-locale
    /// spreadsheet apps).
    static func parse(_ text: String, delimiter: Character = ",") -> CSVDocument {
        let rawRows = parseRows(text, delimiter: delimiter)
        guard let header = rawRows.first else { return .empty }
        let columnCount = header.count
        let dataRows = rawRows.dropFirst().map { row -> [String] in
            var padded = row
            if padded.count < columnCount {
                padded += Array(repeating: "", count: columnCount - padded.count)
            } else if padded.count > columnCount {
                padded = Array(padded.prefix(columnCount))
            }
            return padded
        }
        return CSVDocument(headers: header, rows: Array(dataRows))
    }

    /// Quoted-field-aware CSV row tokenizer (handles embedded delimiters/newlines and
    /// doubled-quote escaping), same approach as `JSONCSVTool`'s parser.
    private static func parseRows(_ input: String, delimiter: Character) -> [[String]] {
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
            } else if c == delimiter {
                row.append(field); field = ""; i += 1
            } else if c.isNewline {
                // `c.isNewline` (not `c == "\n" || c == "\r"`) is required here: Swift's
                // `Character` is a grapheme cluster, and a CRLF pair from a real-world
                // (e.g. Windows/Excel-exported) CSV collapses into a *single* Character
                // equal to neither "\n" nor "\r" alone — a literal comparison silently
                // never matches, so the whole file reads as one row. `.isNewline` matches
                // LF, CR, and CRLF (and other Unicode newlines) as one row terminator.
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

    // MARK: - Serialize

    func serialize(delimiter: Character = ",") -> String {
        let sep = String(delimiter)
        var lines = [headers.map { Self.csvField($0, delimiter: delimiter) }.joined(separator: sep)]
        for row in rows {
            lines.append(row.map { Self.csvField($0, delimiter: delimiter) }.joined(separator: sep))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvField(_ s: String, delimiter: Character) -> String {
        guard s.contains(delimiter) || s.contains("\"") || s.contains("\n") else { return s }
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - Mutation

    mutating func setCell(row: Int, col: Int, value: String) {
        guard rows.indices.contains(row), rows[row].indices.contains(col) else { return }
        rows[row][col] = value
    }

    mutating func renameColumn(_ col: Int, to name: String) {
        guard headers.indices.contains(col) else { return }
        headers[col] = name
    }

    mutating func addRow() {
        rows.append(Array(repeating: "", count: headers.count))
    }

    mutating func removeRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
    }

    mutating func addColumn() {
        var n = headers.count + 1
        var name = "Column \(n)"
        while headers.contains(name) { n += 1; name = "Column \(n)" }
        headers.append(name)
        for i in rows.indices { rows[i].append("") }
    }

    mutating func removeColumn(at index: Int) {
        guard headers.indices.contains(index), headers.count > 1 else { return }
        headers.remove(at: index)
        for i in rows.indices where rows[i].indices.contains(index) {
            rows[i].remove(at: index)
        }
    }

    // MARK: - Type inference

    /// Best-guess column type from its data, shown as a subtitle under the header name —
    /// there's no real schema behind a CSV, so this is a heuristic over a sample of values,
    /// not authoritative metadata (unlike a database tool's actual column types).
    func inferredType(forColumn col: Int, sampleLimit: Int = 200) -> String {
        let samples = rows.prefix(sampleLimit).compactMap { row -> String? in
            guard col < row.count else { return nil }
            let v = row[col]
            return (v.isEmpty || v == "NULL") ? nil : v
        }
        return Self.inferType(from: samples)
    }

    static func inferType(from samples: [String]) -> String {
        guard !samples.isEmpty else { return "text" }
        if samples.allSatisfy(isUUID) { return "uuid" }
        if samples.allSatisfy(isBoolean) { return "boolean" }
        if samples.allSatisfy(isInteger) { return "integer" }
        if samples.allSatisfy(isDecimal) { return "decimal" }
        if samples.allSatisfy(isTimestamp) { return "timestamp" }
        return "text"
    }

    private static func isUUID(_ s: String) -> Bool {
        s.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil
    }

    private static func isBoolean(_ s: String) -> Bool {
        ["true", "false", "True", "False", "TRUE", "FALSE"].contains(s)
    }

    private static func isInteger(_ s: String) -> Bool {
        s.range(of: #"^-?\d+$"#, options: .regularExpression) != nil
    }

    private static func isDecimal(_ s: String) -> Bool {
        s.range(of: #"^-?\d+\.\d+$"#, options: .regularExpression) != nil
    }

    private static func isTimestamp(_ s: String) -> Bool {
        s.range(of: #"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}"#, options: .regularExpression) != nil
    }
}
