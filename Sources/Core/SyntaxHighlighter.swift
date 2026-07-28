import Foundation

/// Which language's rules to apply when coloring a tool's output pane. `.none` means no
/// highlighting — the output pane just renders as plain themed text, same as before this
/// existed (every non-formatter tool: Base64, hash generator, encoders, etc.).
enum SyntaxLanguage {
    case none, json, html, xml, css, yaml
}

/// What a highlighted span represents — maps to a `Theme.SyntaxColors` field by the caller
/// (kept color-free here on purpose: this file is pure Foundation, no AppKit/SwiftUI, so it
/// stays testable the same way every other `Sources/Core/*.swift` parser is).
enum SyntaxTokenRole {
    case key, string, number, keyword, comment, tag, attribute, punctuation
}

struct SyntaxToken {
    let range: Range<String.Index>
    let role: SyntaxTokenRole
}

/// Pure, dependency-free tokenizers that classify ranges of *already-formatted* output text
/// for display coloring. These don't validate or fully parse anything — a malformed or
/// partial string still gets *some* reasonable highlighting rather than throwing — which is
/// deliberately different from `CSSParser`/`HTMLParser`/`YAMLParser` (which build a real
/// document model for beautify/minify). Highlighting only ever needs "what color is this
/// span", never a structured tree.
enum SyntaxHighlighter {
    static func tokenize(_ text: String, language: SyntaxLanguage) -> [SyntaxToken] {
        switch language {
        case .none: return []
        case .json: return tokenizeJSON(text)
        case .html, .xml: return tokenizeMarkup(text)
        case .css: return tokenizeCSS(text)
        case .yaml: return tokenizeYAML(text)
        }
    }

    // MARK: - JSON

    private static func tokenizeJSON(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]

            if c == "\"" {
                let start = i
                let end = scanQuotedString(text, from: i, quote: "\"")
                // A string is a "key" if, skipping whitespace, the next non-space character
                // after the closing quote is a colon — otherwise it's a value.
                var lookahead = end
                while lookahead < text.endIndex, text[lookahead] == " " || text[lookahead] == "\t" {
                    lookahead = text.index(after: lookahead)
                }
                let isKey = lookahead < text.endIndex && text[lookahead] == ":"
                tokens.append(SyntaxToken(range: start..<end, role: isKey ? .key : .string))
                i = end
            } else if c.isNumber || (c == "-" && isDigit(text, at: text.index(after: i))) {
                let start = i
                var j = text.index(after: i)
                while j < text.endIndex, isNumberBodyCharacter(text[j]) {
                    j = text.index(after: j)
                }
                tokens.append(SyntaxToken(range: start..<j, role: .number))
                i = j
            } else if c.isLetter {
                let start = i
                var j = text.index(after: i)
                while j < text.endIndex, text[j].isLetter { j = text.index(after: j) }
                let word = text[start..<j]
                if word == "true" || word == "false" || word == "null" {
                    tokens.append(SyntaxToken(range: start..<j, role: .keyword))
                }
                i = j
            } else if "{}[]:,".contains(c) {
                let j = text.index(after: i)
                tokens.append(SyntaxToken(range: i..<j, role: .punctuation))
                i = j
            } else {
                i = text.index(after: i)
            }
        }
        return tokens
    }

    // MARK: - HTML / XML

    private static func tokenizeMarkup(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            if c == "<" {
                if text[i...].hasPrefix("<!--") {
                    let start = i
                    let end = scanUntil(text, from: i, marker: "-->")
                    tokens.append(SyntaxToken(range: start..<end, role: .comment))
                    i = end
                } else if text[i...].hasPrefix("<!") {
                    // Doctype and similar declarations — highlight the whole thing as one
                    // keyword-colored span rather than trying to parse it.
                    let start = i
                    let end = scanUntil(text, from: i, marker: ">")
                    tokens.append(SyntaxToken(range: start..<end, role: .keyword))
                    i = end
                } else {
                    i = scanTag(text, from: i, into: &tokens)
                }
            } else {
                i = text.index(after: i)
            }
        }
        return tokens
    }

    /// Scans a single `<tag ...>` / `</tag>` from its opening `<` through the matching `>`
    /// (not inside a quoted attribute value), tagging the tag name, each attribute name, and
    /// each quoted attribute value along the way. Returns the index just past the `>`, or
    /// `text.endIndex` if the tag is never closed (unterminated/truncated input).
    private static func scanTag(_ text: String, from start: String.Index, into tokens: inout [SyntaxToken]) -> String.Index {
        var i = text.index(after: start) // past "<"
        if i < text.endIndex, text[i] == "/" { i = text.index(after: i) } // closing tag slash

        let nameStart = i
        while i < text.endIndex, isTagNameCharacter(text[i]) { i = text.index(after: i) }
        if i > nameStart {
            tokens.append(SyntaxToken(range: nameStart..<i, role: .tag))
        }

        // Attributes: `name`, or `name="value"` / `name='value'`.
        while i < text.endIndex, text[i] != ">" {
            if text[i] == "\"" || text[i] == "'" {
                let quote = text[i]
                let strStart = i
                let strEnd = scanQuotedString(text, from: i, quote: quote)
                tokens.append(SyntaxToken(range: strStart..<strEnd, role: .string))
                i = strEnd
                continue
            }
            if isAttributeNameCharacter(text[i]) {
                let attrStart = i
                while i < text.endIndex, isAttributeNameCharacter(text[i]) { i = text.index(after: i) }
                tokens.append(SyntaxToken(range: attrStart..<i, role: .attribute))
                continue
            }
            i = text.index(after: i)
        }
        if i < text.endIndex { i = text.index(after: i) } // past ">"
        return i
    }

    // MARK: - CSS

    private static func tokenizeCSS(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var i = text.startIndex
        var depth = 0 // 0 = selector/at-rule context, >0 = inside a declaration block

        while i < text.endIndex {
            let c = text[i]

            if text[i...].hasPrefix("/*") {
                let start = i
                let end = scanUntil(text, from: i, marker: "*/")
                tokens.append(SyntaxToken(range: start..<end, role: .comment))
                i = end
                continue
            }
            if c == "@" {
                let start = i
                var j = text.index(after: i)
                while j < text.endIndex, text[j].isLetter || text[j] == "-" { j = text.index(after: j) }
                tokens.append(SyntaxToken(range: start..<j, role: .keyword))
                i = j
                continue
            }
            if c == "{" {
                depth += 1
                let j = text.index(after: i)
                tokens.append(SyntaxToken(range: i..<j, role: .punctuation))
                i = j
                continue
            }
            if c == "}" {
                depth = max(0, depth - 1)
                let j = text.index(after: i)
                tokens.append(SyntaxToken(range: i..<j, role: .punctuation))
                i = j
                continue
            }
            if depth > 0, c == ":" {
                // Everything back to the start of this declaration is the property name;
                // everything forward to `;`/`}` is the value. Walking backward from `:` to
                // the last `;`/`{`/`}`/newline keeps this a single forward pass overall.
                let colonIndex = i
                var propStart = i
                while propStart > text.startIndex {
                    let prev = text.index(before: propStart)
                    if ";{}\n".contains(text[prev]) { break }
                    propStart = prev
                }
                let trimmedPropStart = trimLeadingWhitespace(text, from: propStart, upTo: colonIndex)
                if trimmedPropStart < colonIndex {
                    tokens.append(SyntaxToken(range: trimmedPropStart..<colonIndex, role: .key))
                }

                var valueEnd = text.index(after: colonIndex)
                while valueEnd < text.endIndex, !";}".contains(text[valueEnd]) {
                    valueEnd = text.index(after: valueEnd)
                }
                let valueStart = text.index(after: colonIndex)
                let trimmedValueStart = trimLeadingWhitespace(text, from: valueStart, upTo: valueEnd)
                if trimmedValueStart < valueEnd {
                    tokens.append(SyntaxToken(range: trimmedValueStart..<valueEnd, role: .string))
                }
                tokens.append(SyntaxToken(range: colonIndex..<text.index(after: colonIndex), role: .punctuation))
                i = valueEnd
                continue
            }
            if c == ";" {
                let j = text.index(after: i)
                tokens.append(SyntaxToken(range: i..<j, role: .punctuation))
                i = j
                continue
            }
            i = text.index(after: i)
        }
        return tokens
    }

    // MARK: - YAML

    /// Line-based on purpose — real YAML is context-sensitive (flow style, multi-line
    /// scalars, anchors), and a full parser already exists in `YAMLParser` for actually
    /// reading the document. This only needs "does this line look like `key: value`, a
    /// comment, or a quoted string" for coloring, so treating it line-by-line keeps it
    /// simple and safe against the same document `YAMLParser` already validated.
    private static func tokenizeYAML(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var lineStart = text.startIndex

        while true {
            var lineEnd = lineStart
            while lineEnd < text.endIndex, text[lineEnd] != "\n" { lineEnd = text.index(after: lineEnd) }

            tokenizeYAMLLine(text, lineStart: lineStart, lineEnd: lineEnd, into: &tokens)

            if lineEnd >= text.endIndex { break }
            lineStart = text.index(after: lineEnd) // skip the "\n" itself
        }
        return tokens
    }

    private static func tokenizeYAMLLine(
        _ text: String, lineStart: String.Index, lineEnd: String.Index, into tokens: inout [SyntaxToken]
    ) {
        var i = lineStart
        while i < lineEnd, text[i] == " " { i = text.index(after: i) }
        // "- " list-item marker doesn't affect key detection — just skip past it.
        if i < lineEnd, text[i] == "-", text.index(after: i) < lineEnd, text[text.index(after: i)] == " " {
            i = text.index(after: text.index(after: i))
        }
        guard i < lineEnd else { return }

        if text[i] == "#" {
            tokens.append(SyntaxToken(range: i..<lineEnd, role: .comment))
            return
        }

        // A line starting directly with a quote is a bare scalar, not a `key:` — skip
        // straight to value classification so `scanQuotedString` (not a raw colon scan)
        // is what finds the string's real end, in case the string itself contains a colon.
        if text[i] != "\"", text[i] != "'" {
            var j = i
            while j < lineEnd, text[j] != ":" { j = text.index(after: j) }
            if j < lineEnd {
                tokens.append(SyntaxToken(range: i..<j, role: .key))
                var valueStart = text.index(after: j)
                while valueStart < lineEnd, text[valueStart] == " " { valueStart = text.index(after: valueStart) }
                if valueStart < lineEnd {
                    classifyYAMLValue(text, from: valueStart, lineEnd: lineEnd, into: &tokens)
                }
                return
            }
        }
        classifyYAMLValue(text, from: i, lineEnd: lineEnd, into: &tokens)
    }

    /// Colors a scalar value (quoted string — with a possible trailing `# comment` — an
    /// end-of-line comment, `true`/`false`/`null`/`~`, or a bare number). Anything else
    /// (plain unquoted text, flow collections like `[a, b]`, etc.) is left uncolored rather
    /// than guessed at.
    private static func classifyYAMLValue(
        _ text: String, from start: String.Index, lineEnd: String.Index, into tokens: inout [SyntaxToken]
    ) {
        if text[start] == "\"" || text[start] == "'" {
            let quote = text[start]
            let end = scanQuotedString(text, from: start, quote: quote, hardStop: lineEnd)
            tokens.append(SyntaxToken(range: start..<end, role: .string))
            var rest = end
            while rest < lineEnd, text[rest] == " " { rest = text.index(after: rest) }
            if rest < lineEnd, text[rest] == "#" {
                tokens.append(SyntaxToken(range: rest..<lineEnd, role: .comment))
            }
            return
        }
        if text[start] == "#" {
            tokens.append(SyntaxToken(range: start..<lineEnd, role: .comment))
            return
        }
        let word = text[start..<lineEnd]
        if word == "true" || word == "false" || word == "null" || word == "~" {
            tokens.append(SyntaxToken(range: start..<lineEnd, role: .keyword))
        } else if isNumericLiteral(word) {
            tokens.append(SyntaxToken(range: start..<lineEnd, role: .number))
        }
    }

    // MARK: - Shared scanning helpers

    /// Scans a quoted string starting at an opening `quote`, honoring `\`-escapes, and
    /// returns the index just past the matching closing quote (or `hardStop`/`endIndex` if
    /// the string is never closed — e.g. truncated input mid-edit).
    private static func scanQuotedString(
        _ text: String, from start: String.Index, quote: Character, hardStop: String.Index? = nil
    ) -> String.Index {
        let limit = hardStop ?? text.endIndex
        var j = text.index(after: start)
        var escaped = false
        while j < limit {
            let cj = text[j]
            if escaped {
                escaped = false
            } else if cj == "\\" {
                escaped = true
            } else if cj == quote {
                return text.index(after: j)
            }
            j = text.index(after: j)
        }
        return limit
    }

    /// Scans forward until `marker` is found, returning the index just past it (or
    /// `endIndex` if `marker` never appears).
    private static func scanUntil(_ text: String, from start: String.Index, marker: String) -> String.Index {
        var j = start
        while j < text.endIndex {
            if text[j...].hasPrefix(marker) {
                return text.index(j, offsetBy: marker.count)
            }
            j = text.index(after: j)
        }
        return text.endIndex
    }

    private static func trimLeadingWhitespace(_ text: String, from start: String.Index, upTo end: String.Index) -> String.Index {
        var i = start
        while i < end, text[i] == " " || text[i] == "\t" || text[i] == "\n" { i = text.index(after: i) }
        return i
    }

    private static func isDigit(_ text: String, at index: String.Index) -> Bool {
        index < text.endIndex && text[index].isNumber
    }

    private static func isNumberBodyCharacter(_ c: Character) -> Bool {
        c.isNumber || c == "." || c == "e" || c == "E" || c == "+" || c == "-"
    }

    private static func isTagNameCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "-" || c == ":" || c == "_"
    }

    private static func isAttributeNameCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || c == "-" || c == "_" || c == ":"
    }

    private static func isNumericLiteral<S: StringProtocol>(_ s: S) -> Bool {
        guard !s.isEmpty else { return false }
        var body = s[...]
        if body.first == "-" || body.first == "+" { body = body.dropFirst() }
        guard !body.isEmpty else { return false }
        var seenDot = false
        for c in body {
            if c == "." {
                if seenDot { return false }
                seenDot = true
            } else if !c.isNumber {
                return false
            }
        }
        return true
    }
}
