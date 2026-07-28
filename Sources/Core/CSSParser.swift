import Foundation

// Custom CSS tokenizer/formatter — no third-party deps (CLAUDE.md bans SPM). Handles
// plain CSS plus nested at-rules (@media/@supports containing rules), which also makes
// this a reasonable base to extend for SCSS/LESS beautify later (docs/task-plan.md).
// Not a full CSS3 grammar (no string-aware value validation beyond skipping quoted content).

struct CSSRule {
    let selector: String
    let declarations: [(String, String)]
    let children: [CSSRule]
    /// A standalone statement with no block, e.g. `@import url(a.css);`
    let isStatement: Bool
}

enum CSSParser {

    // MARK: - Parse

    static func parse(_ input: String) throws -> [CSSRule] {
        var chars = Array(input)
        var i = 0
        let (_, children) = try parseBlockContent(&chars, &i, topLevel: true)
        return children
    }

    private static func parseBlockContent(
        _ chars: inout [Character], _ i: inout Int, topLevel: Bool
    ) throws -> (declarations: [(String, String)], children: [CSSRule]) {
        var declarations: [(String, String)] = []
        var children: [CSSRule] = []

        while true {
            skipWhitespaceAndComments(&chars, &i)
            guard i < chars.count else { break }
            if chars[i] == "}" {
                if topLevel {
                    // Stray closing brace at top level — skip it rather than throwing;
                    // best-effort formatting shouldn't hard-fail on minor input slips.
                    i += 1
                    continue
                }
                i += 1
                break
            }

            let start = i
            while i < chars.count, chars[i] != "{", chars[i] != ";", chars[i] != "}" {
                if chars[i] == "\"" || chars[i] == "'" {
                    skipString(&chars, &i)
                } else {
                    i += 1
                }
            }

            guard i < chars.count else {
                let text = String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { children.append(CSSRule(selector: text + ";", declarations: [], children: [], isStatement: true)) }
                break
            }

            switch chars[i] {
            case "{":
                let selector = String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                i += 1
                let (innerDecls, innerChildren) = try parseBlockContent(&chars, &i, topLevel: false)
                children.append(CSSRule(selector: selector, declarations: innerDecls, children: innerChildren, isStatement: false))
            case ";":
                let text = String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                i += 1
                if !text.isEmpty {
                    if let colon = text.firstIndex(of: ":") {
                        let prop = String(text[text.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                        let value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                        declarations.append((prop, value))
                    } else {
                        children.append(CSSRule(selector: text + ";", declarations: [], children: [], isStatement: true))
                    }
                }
            case "}":
                let text = String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, let colon = text.firstIndex(of: ":") {
                    let prop = String(text[text.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                    let value = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    declarations.append((prop, value))
                }
                i += 1
                return (declarations, children)
            default:
                break
            }
        }
        return (declarations, children)
    }

    private static func skipString(_ chars: inout [Character], _ i: inout Int) {
        let quote = chars[i]
        i += 1
        while i < chars.count, chars[i] != quote {
            if chars[i] == "\\" { i += 1 }
            i += 1
        }
        if i < chars.count { i += 1 }
    }

    private static func skipWhitespaceAndComments(_ chars: inout [Character], _ i: inout Int) {
        while i < chars.count {
            if chars[i].isWhitespace {
                i += 1
            } else if chars[i] == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i + 1 < chars.count, !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                i = min(i + 2, chars.count)
            } else {
                break
            }
        }
    }

    // MARK: - Render

    static func beautify(_ rules: [CSSRule], indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        var lines: [String] = []
        for (idx, rule) in rules.enumerated() {
            if rule.isStatement {
                lines.append("\(pad)\(rule.selector)")
                continue
            }
            lines.append("\(pad)\(rule.selector) {")
            for (prop, value) in rule.declarations {
                lines.append("\(pad)  \(prop): \(value);")
            }
            if !rule.children.isEmpty {
                lines.append(beautify(rule.children, indent: indent + 1))
            }
            lines.append("\(pad)}")
            if indent == 0, idx < rules.count - 1 { lines.append("") }
        }
        return lines.joined(separator: "\n")
    }

    static func minify(_ rules: [CSSRule]) -> String {
        var out = ""
        for rule in rules {
            if rule.isStatement {
                out += rule.selector
                continue
            }
            out += "\(rule.selector){"
            out += rule.declarations.map { "\($0.0):\($0.1);" }.joined()
            out += minify(rule.children)
            out += "}"
        }
        return out
    }
}
