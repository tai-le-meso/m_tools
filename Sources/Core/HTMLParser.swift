import Foundation

// Custom HTML tokenizer + DOM builder — no third-party deps (CLAUDE.md bans SwiftSoup/SPM).
// Enough to support beautify/minify and (later) HTML-to-JSX: tags, attributes, text,
// comments, and void elements. Not a spec-complete HTML5 parser (no error-recovery
// algorithm, no scripting/foreign-content modes).

indirect enum HTMLNode {
    case element(tag: String, attrs: [(String, String)], children: [HTMLNode], selfClosing: Bool)
    case text(String)
    case comment(String)
}

/// Tags with no closing tag / children per the HTML spec.
let htmlVoidElements: Set<String> = [
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr"
]

/// Tags whose text content shouldn't be re-indented/word-wrapped.
let htmlRawTextElements: Set<String> = ["script", "style", "pre", "textarea"]

enum HTMLParseError: LocalizedError {
    case unclosedTag(String)
    var errorDescription: String? {
        switch self {
        case .unclosedTag(let tag): return "Unclosed tag: <\(tag)>"
        }
    }
}

enum HTMLParser {

    // MARK: - Tokenize + build tree

    static func parse(_ input: String) throws -> [HTMLNode] {
        var chars = Array(input)
        var i = 0
        return try parseNodes(&chars, &i, stopTags: [])
    }

    private static func parseNodes(_ chars: inout [Character], _ i: inout Int, stopTags: Set<String>) throws -> [HTMLNode] {
        var nodes: [HTMLNode] = []
        while i < chars.count {
            if chars[i] == "<" {
                if peekMatches(chars, i, "<!--") {
                    nodes.append(.comment(readComment(&chars, &i)))
                    continue
                }
                if peekMatches(chars, i, "<!") {
                    // Doctype or other declaration — pass through as raw text.
                    let start = i
                    while i < chars.count, chars[i] != ">" { i += 1 }
                    if i < chars.count { i += 1 }
                    nodes.append(.text(String(chars[start..<i])))
                    continue
                }
                if peekMatches(chars, i, "</") {
                    // Closing tag — let the caller (element parser) consume it.
                    return nodes
                }
                let (tag, attrs, selfClosing) = try readOpenTag(&chars, &i)
                if selfClosing || htmlVoidElements.contains(tag.lowercased()) {
                    nodes.append(.element(tag: tag, attrs: attrs, children: [], selfClosing: true))
                    continue
                }
                if htmlRawTextElements.contains(tag.lowercased()) {
                    let raw = readRawTextUntilClose(&chars, &i, tag: tag)
                    nodes.append(.element(tag: tag, attrs: attrs, children: [.text(raw)], selfClosing: false))
                    continue
                }
                let children = try parseNodes(&chars, &i, stopTags: stopTags.union([tag.lowercased()]))
                consumeClosingTag(&chars, &i, expected: tag)
                nodes.append(.element(tag: tag, attrs: attrs, children: children, selfClosing: false))
            } else {
                nodes.append(.text(readText(&chars, &i)))
            }
        }
        return nodes
    }

    private static func peekMatches(_ chars: [Character], _ i: Int, _ s: String) -> Bool {
        let sChars = Array(s)
        guard i + sChars.count <= chars.count else { return false }
        for (offset, c) in sChars.enumerated() where chars[i + offset].lowercased() != String(c).lowercased() {
            return false
        }
        return true
    }

    private static func readComment(_ chars: inout [Character], _ i: inout Int) -> String {
        i += 4 // skip <!--
        let start = i
        while i < chars.count, !peekMatches(chars, i, "-->") { i += 1 }
        let content = String(chars[start..<i])
        if i < chars.count { i += 3 }
        return content
    }

    private static func readText(_ chars: inout [Character], _ i: inout Int) -> String {
        let start = i
        while i < chars.count, chars[i] != "<" { i += 1 }
        return decodeEntities(String(chars[start..<i]))
    }

    private static func readRawTextUntilClose(_ chars: inout [Character], _ i: inout Int, tag: String) -> String {
        let start = i
        let closeTag = "</\(tag.lowercased())"
        while i < chars.count {
            if chars[i] == "<", peekMatches(chars, i, closeTag) {
                break
            }
            i += 1
        }
        let content = String(chars[start..<i])
        // Consume the closing tag itself.
        while i < chars.count, chars[i] != ">" { i += 1 }
        if i < chars.count { i += 1 }
        return content
    }

    private static func readOpenTag(_ chars: inout [Character], _ i: inout Int) throws -> (String, [(String, String)], Bool) {
        i += 1 // skip '<'
        var tag = ""
        while i < chars.count, !chars[i].isWhitespace, chars[i] != ">", chars[i] != "/" {
            tag.append(chars[i]); i += 1
        }
        var attrs: [(String, String)] = []
        var selfClosing = false
        while i < chars.count, chars[i] != ">" {
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            if i < chars.count, chars[i] == "/" {
                selfClosing = true
                i += 1
                continue
            }
            if i >= chars.count || chars[i] == ">" { break }
            var name = ""
            while i < chars.count, !chars[i].isWhitespace, chars[i] != "=", chars[i] != ">", chars[i] != "/" {
                name.append(chars[i]); i += 1
            }
            if name.isEmpty { break }
            while i < chars.count, chars[i].isWhitespace { i += 1 }
            var value = ""
            if i < chars.count, chars[i] == "=" {
                i += 1
                while i < chars.count, chars[i].isWhitespace { i += 1 }
                if i < chars.count, chars[i] == "\"" || chars[i] == "'" {
                    let quote = chars[i]; i += 1
                    let start = i
                    while i < chars.count, chars[i] != quote { i += 1 }
                    value = String(chars[start..<i])
                    if i < chars.count { i += 1 }
                } else {
                    let start = i
                    while i < chars.count, !chars[i].isWhitespace, chars[i] != ">" { i += 1 }
                    value = String(chars[start..<i])
                }
                attrs.append((name, decodeEntities(value)))
            } else {
                attrs.append((name, name)) // boolean attribute
            }
        }
        if i < chars.count, chars[i] == ">" { i += 1 }
        return (tag, attrs, selfClosing)
    }

    private static func consumeClosingTag(_ chars: inout [Character], _ i: inout Int, expected: String) {
        guard i < chars.count, peekMatches(chars, i, "</") else { return }
        while i < chars.count, chars[i] != ">" { i += 1 }
        if i < chars.count { i += 1 }
    }

    // MARK: - Entities (minimal named-entity table, plus numeric refs)

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "copy": "©", "reg": "®", "trade": "™",
        "mdash": "—", "ndash": "–", "hellip": "…"
    ]

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "&", let semi = chars[i...].firstIndex(of: ";"), semi - i <= 10 {
                let entity = String(chars[(i + 1)..<semi])
                if entity.hasPrefix("#x") || entity.hasPrefix("#X"), let code = UInt32(entity.dropFirst(2), radix: 16), let scalar = Unicode.Scalar(code) {
                    result.append(Character(scalar)); i = semi + 1; continue
                }
                if entity.hasPrefix("#"), let code = UInt32(entity.dropFirst()), let scalar = Unicode.Scalar(code) {
                    result.append(Character(scalar)); i = semi + 1; continue
                }
                if let named = namedEntities[entity] {
                    result.append(named); i = semi + 1; continue
                }
            }
            result.append(chars[i]); i += 1
        }
        return result
    }

    static func encodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Render

    static func beautify(_ nodes: [HTMLNode], indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        var lines: [String] = []
        for node in nodes {
            switch node {
            case .text(let t):
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { lines.append(pad + encodeEntities(trimmed)) }
            case .comment(let c):
                lines.append("\(pad)<!--\(c)-->")
            case .element(let tag, let attrs, let children, let selfClosing):
                let attrStr = renderAttrs(attrs)
                if selfClosing || htmlVoidElements.contains(tag.lowercased()) {
                    lines.append("\(pad)<\(tag)\(attrStr)>")
                } else if htmlRawTextElements.contains(tag.lowercased()) {
                    let raw = children.compactMap { if case .text(let t) = $0 { return t } else { return nil } }.joined()
                    lines.append("\(pad)<\(tag)\(attrStr)>\(raw)</\(tag)>")
                } else if children.isEmpty {
                    lines.append("\(pad)<\(tag)\(attrStr)></\(tag)>")
                } else if children.count == 1, case .text(let t) = children[0],
                          !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("\(pad)<\(tag)\(attrStr)>\(encodeEntities(t.trimmingCharacters(in: .whitespacesAndNewlines)))</\(tag)>")
                } else {
                    lines.append("\(pad)<\(tag)\(attrStr)>")
                    lines.append(beautify(children, indent: indent + 1))
                    lines.append("\(pad)</\(tag)>")
                }
            }
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func minify(_ nodes: [HTMLNode]) -> String {
        var out = ""
        for node in nodes {
            switch node {
            case .text(let t):
                let collapsed = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !collapsed.isEmpty {
                    out += collapsed.hasPrefix(" ") || out.hasSuffix(" ") || out.isEmpty ? collapsed : " " + collapsed
                }
            case .comment:
                continue // comments dropped in minified output
            case .element(let tag, let attrs, let children, let selfClosing):
                let attrStr = renderAttrs(attrs)
                if selfClosing || htmlVoidElements.contains(tag.lowercased()) {
                    out += "<\(tag)\(attrStr)>"
                } else if htmlRawTextElements.contains(tag.lowercased()) {
                    let raw = children.compactMap { if case .text(let t) = $0 { return t } else { return nil } }.joined()
                    out += "<\(tag)\(attrStr)>\(raw)</\(tag)>"
                } else {
                    out += "<\(tag)\(attrStr)>\(minify(children))</\(tag)>"
                }
            }
        }
        return out
    }

    private static func renderAttrs(_ attrs: [(String, String)]) -> String {
        guard !attrs.isEmpty else { return "" }
        return " " + attrs.map { name, value in
            name == value ? name : "\(name)=\"\(value.replacingOccurrences(of: "\"", with: "&quot;"))\""
        }.joined(separator: " ")
    }
}
