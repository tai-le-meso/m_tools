import Foundation

// Custom YAML parser/serializer — no third-party deps (CLAUDE.md bans SPM/Yams).
// Supports the practical subset needed for YAML <-> JSON conversion: block and flow
// mappings/sequences, quoted/unquoted scalars, comments, nesting by indentation.
// Not a full YAML 1.2 implementation (no anchors/aliases/multi-doc/tags).

indirect enum YAMLValue {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([YAMLValue])
    /// Order-preserving object — YAML (and JSON) keys are ordered in source even though
    /// JSONSerialization itself doesn't guarantee it; keeping order gives nicer round-trips.
    case object([(String, YAMLValue)])
}

enum YAMLError: LocalizedError {
    case syntax(String)
    var errorDescription: String? {
        switch self { case .syntax(let s): return s }
    }
}

enum YAMLParser {

    // MARK: - Parse

    static func parse(_ text: String) throws -> YAMLValue {
        let rawLines = text.components(separatedBy: "\n")
        var lines: [(indent: Int, content: String)] = []
        for raw in rawLines {
            let stripped = stripComment(raw)
            if stripped.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let indent = stripped.prefix { $0 == " " }.count
            lines.append((indent, String(stripped.dropFirst(indent))))
        }
        guard !lines.isEmpty else { return .null }
        var idx = 0
        let value = try parseBlock(lines, &idx, minIndent: lines[0].indent)
        return value
    }

    /// Removes a trailing `# comment`, respecting single/double-quoted strings.
    private static func stripComment(_ line: String) -> String {
        var inSingle = false, inDouble = false
        var result = ""
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "'" && !inDouble { inSingle.toggle() }
            if c == "\"" && !inSingle { inDouble.toggle() }
            if c == "#" && !inSingle && !inDouble {
                // Must be start-of-token comment (preceded by whitespace or start of line)
                if result.isEmpty || result.hasSuffix(" ") {
                    break
                }
            }
            result.append(c)
            i += 1
        }
        return result
    }

    private static func parseBlock(_ lines: [(indent: Int, content: String)], _ idx: inout Int, minIndent: Int) throws -> YAMLValue {
        guard idx < lines.count else { return .null }
        let first = lines[idx]
        guard first.indent >= minIndent else { return .null }

        if first.content.hasPrefix("- ") || first.content == "-" {
            return try parseSequence(lines, &idx, indent: first.indent)
        } else {
            return try parseMapping(lines, &idx, indent: first.indent)
        }
    }

    private static func parseSequence(_ lines: [(indent: Int, content: String)], _ idx: inout Int, indent: Int) throws -> YAMLValue {
        var items: [YAMLValue] = []
        while idx < lines.count, lines[idx].indent == indent,
              (lines[idx].content.hasPrefix("- ") || lines[idx].content == "-") {
            let content = lines[idx].content
            let rest = content == "-" ? "" : String(content.dropFirst(2))
            if rest.trimmingCharacters(in: .whitespaces).isEmpty {
                // Nested block on following lines, indented further than this dash.
                idx += 1
                if idx < lines.count, lines[idx].indent > indent {
                    items.append(try parseBlock(lines, &idx, minIndent: lines[idx].indent))
                } else {
                    items.append(.null)
                }
            } else if rest.contains(": ") || rest.hasSuffix(":") {
                // Inline mapping start: "- key: value" — treat the rest as a one-line
                // mapping whose first entry is on this line, continued at indent+2.
                let syntheticIndent = indent + 2
                var syntheticLines = lines
                syntheticLines[idx] = (syntheticIndent, rest)
                var localIdx = idx
                let obj = try parseMapping(syntheticLines, &localIdx, indent: syntheticIndent)
                items.append(obj)
                idx = localIdx
            } else {
                items.append(try parseScalar(rest))
                idx += 1
            }
        }
        return .array(items)
    }

    private static func parseMapping(_ lines: [(indent: Int, content: String)], _ idx: inout Int, indent: Int) throws -> YAMLValue {
        var entries: [(String, YAMLValue)] = []
        while idx < lines.count, lines[idx].indent == indent {
            let content = lines[idx].content
            guard let colonRange = findKeyColon(content) else {
                throw YAMLError.syntax("Expected 'key: value' at: \(content)")
            }
            let rawKey = String(content[content.startIndex..<colonRange])
            let key = unquote(rawKey.trimmingCharacters(in: .whitespaces))
            let afterColon = content[content.index(after: colonRange)...]
            let valueStr = afterColon.trimmingCharacters(in: .whitespaces)

            if valueStr.isEmpty {
                idx += 1
                if idx < lines.count, lines[idx].indent > indent {
                    let child = try parseBlock(lines, &idx, minIndent: lines[idx].indent)
                    entries.append((key, child))
                } else {
                    entries.append((key, .null))
                }
            } else if valueStr.hasPrefix("[") || valueStr.hasPrefix("{") {
                entries.append((key, try parseFlow(valueStr)))
                idx += 1
            } else {
                entries.append((key, try parseScalar(valueStr)))
                idx += 1
            }
        }
        return .object(entries)
    }

    /// Finds the ':' that separates key from value, ignoring one inside quotes.
    private static func findKeyColon(_ s: String) -> String.Index? {
        var inSingle = false, inDouble = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "'" && !inDouble { inSingle.toggle() }
            else if c == "\"" && !inSingle { inDouble.toggle() }
            else if c == ":" && !inSingle && !inDouble {
                let next = s.index(after: i)
                if next == s.endIndex || s[next] == " " { return i }
            }
            i = s.index(after: i)
        }
        return nil
    }

    private static func parseFlow(_ s: String) throws -> YAMLValue {
        var chars = Array(s)
        var i = 0
        let value = try parseFlowValue(&chars, &i)
        return value
    }

    private static func parseFlowValue(_ chars: inout [Character], _ i: inout Int) throws -> YAMLValue {
        skipSpaces(chars, &i)
        guard i < chars.count else { return .null }
        switch chars[i] {
        case "[":
            i += 1
            var items: [YAMLValue] = []
            skipSpaces(chars, &i)
            if i < chars.count, chars[i] == "]" { i += 1; return .array(items) }
            while true {
                items.append(try parseFlowValue(&chars, &i))
                skipSpaces(chars, &i)
                if i < chars.count, chars[i] == "," { i += 1; continue }
                break
            }
            skipSpaces(chars, &i)
            guard i < chars.count, chars[i] == "]" else { throw YAMLError.syntax("Expected ']'") }
            i += 1
            return .array(items)
        case "{":
            i += 1
            var entries: [(String, YAMLValue)] = []
            skipSpaces(chars, &i)
            if i < chars.count, chars[i] == "}" { i += 1; return .object(entries) }
            while true {
                skipSpaces(chars, &i)
                let key = readFlowToken(chars, &i, stopAt: [":"])
                skipSpaces(chars, &i)
                if i < chars.count, chars[i] == ":" { i += 1 }
                let value = try parseFlowValue(&chars, &i)
                entries.append((unquote(key.trimmingCharacters(in: .whitespaces)), value))
                skipSpaces(chars, &i)
                if i < chars.count, chars[i] == "," { i += 1; continue }
                break
            }
            skipSpaces(chars, &i)
            guard i < chars.count, chars[i] == "}" else { throw YAMLError.syntax("Expected '}'") }
            i += 1
            return .object(entries)
        default:
            let token = readFlowToken(chars, &i, stopAt: [",", "]", "}"])
            return try parseScalar(token.trimmingCharacters(in: .whitespaces))
        }
    }

    private static func skipSpaces(_ chars: [Character], _ i: inout Int) {
        while i < chars.count, chars[i] == " " { i += 1 }
    }

    private static func readFlowToken(_ chars: [Character], _ i: inout Int, stopAt: Set<Character>) -> String {
        var result = ""
        if i < chars.count, chars[i] == "\"" || chars[i] == "'" {
            let quote = chars[i]
            result.append(quote); i += 1
            while i < chars.count, chars[i] != quote {
                result.append(chars[i]); i += 1
            }
            if i < chars.count { result.append(chars[i]); i += 1 }
            return result
        }
        while i < chars.count, !stopAt.contains(chars[i]) {
            result.append(chars[i]); i += 1
        }
        return result
    }

    private static func parseScalar(_ raw: String) throws -> YAMLValue {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s == "~" || s == "null" || s == "Null" || s == "NULL" { return .null }
        if s == "true" || s == "True" || s == "TRUE" { return .bool(true) }
        if s == "false" || s == "False" || s == "FALSE" { return .bool(false) }
        if (s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2) {
            return .string(unescapeDouble(String(s.dropFirst().dropLast())))
        }
        if (s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2) {
            return .string(String(s.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'"))
        }
        if let intVal = Int(s) { return .int(intVal) }
        if let dblVal = Double(s) { return .double(dblVal) }
        return .string(s)
    }

    private static func unquote(_ s: String) -> String {
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            return unescapeDouble(String(s.dropFirst().dropLast()))
        }
        if s.hasPrefix("'") && s.hasSuffix("'") && s.count >= 2 {
            return String(s.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        return s
    }

    private static func unescapeDouble(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\"", with: "\"")
         .replacingOccurrences(of: "\\n", with: "\n")
         .replacingOccurrences(of: "\\t", with: "\t")
         .replacingOccurrences(of: "\\\\", with: "\\")
    }

    // MARK: - Serialize

    static func serialize(_ value: YAMLValue) -> String {
        let body = serializeBlock(value, indent: 0)
        return body.isEmpty ? "" : body
    }

    private static func serializeBlock(_ value: YAMLValue, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch value {
        case .object(let entries):
            if entries.isEmpty { return pad + "{}" }
            return entries.map { key, val -> String in
                let keyStr = yamlKey(key)
                switch val {
                case .object(let e) where !e.isEmpty:
                    return "\(pad)\(keyStr):\n\(serializeBlock(val, indent: indent + 1))"
                case .array(let a) where !a.isEmpty:
                    return "\(pad)\(keyStr):\n\(serializeBlock(val, indent: indent))"
                default:
                    return "\(pad)\(keyStr): \(scalarString(val))"
                }
            }.joined(separator: "\n")
        case .array(let items):
            if items.isEmpty { return pad + "[]" }
            return items.map { item -> String in
                switch item {
                case .object(let e) where !e.isEmpty:
                    let inner = serializeBlock(item, indent: indent + 1)
                    // First key goes on the same line as the dash.
                    let lines = inner.components(separatedBy: "\n")
                    guard let firstLine = lines.first else { return "\(pad)-" }
                    let firstTrimmed = firstLine.trimmingCharacters(in: .whitespaces)
                    let restLines = lines.dropFirst().joined(separator: "\n")
                    return restLines.isEmpty ? "\(pad)- \(firstTrimmed)" : "\(pad)- \(firstTrimmed)\n\(restLines)"
                case .array(let a) where !a.isEmpty:
                    let inner = serializeBlock(item, indent: indent + 1)
                    return "\(pad)-\n\(inner)"
                default:
                    return "\(pad)- \(scalarString(item))"
                }
            }.joined(separator: "\n")
        default:
            return pad + scalarString(value)
        }
    }

    private static func yamlKey(_ key: String) -> String {
        if key.isEmpty || key.contains(":") || key.contains("#") {
            return "\"\(key.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return key
    }

    private static func scalarString(_ value: YAMLValue) -> String {
        switch value {
        case .string(let s): return yamlScalarString(s)
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .object: return "{}"
        case .array: return "[]"
        }
    }

    private static func yamlScalarString(_ s: String) -> String {
        if s.isEmpty { return "\"\"" }
        let needsQuoting = s == "true" || s == "false" || s == "null" || s == "~"
            || Int(s) != nil || Double(s) != nil
            || s.contains(":") || s.contains("#") || s.hasPrefix("- ")
            || s.hasPrefix(" ") || s.hasSuffix(" ") || s.contains("\n")
        return needsQuoting ? "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\"" : s
    }

    // MARK: - Bridging to Foundation's JSON types (used by JSONSerialization)

    static func toJSONObject(_ value: YAMLValue) -> Any {
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let items): return items.map(toJSONObject)
        case .object(let entries):
            let dict = NSMutableOrderedDict()
            for (k, v) in entries { dict.set(k, toJSONObject(v)) }
            return dict.toDictionary()
        }
    }

    static func fromJSONObject(_ obj: Any) -> YAMLValue {
        switch obj {
        case let n as NSNumber:
            // Distinguish bool from number: CFBoolean is backed by NSNumber.
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool(n.boolValue) }
            if let intVal = n as? Int, Double(intVal) == n.doubleValue { return .int(intVal) }
            return .double(n.doubleValue)
        case let s as String:
            return .string(s)
        case is NSNull:
            return .null
        case let arr as [Any]:
            return .array(arr.map(fromJSONObject))
        case let dict as [String: Any]:
            // JSONSerialization doesn't preserve key order; sort for deterministic output.
            let entries = dict.keys.sorted().map { ($0, fromJSONObject(dict[$0]!)) }
            return .object(entries)
        default:
            return .null
        }
    }
}

/// Minimal order-preserving dictionary helper, since Swift's Dictionary has no
/// guaranteed order and we want YAML->JSON->YAML round-trips to look stable.
private final class NSMutableOrderedDict {
    private var keys: [String] = []
    private var values: [String: Any] = [:]

    func set(_ key: String, _ value: Any) {
        if values[key] == nil { keys.append(key) }
        values[key] = value
    }

    func toDictionary() -> [String: Any] { values }
}
