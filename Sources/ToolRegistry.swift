import Foundation

/// Categories shown as sidebar nav items and content tabs. Extend as new tool groups
/// are added — see docs/task-plan.md Phase 2 for the full tool list this maps to.
enum ToolCategory: String, CaseIterable, Identifiable {
    case all, format, convert, inspect, generate, encode

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .format: return "Format"
        case .convert: return "Convert"
        case .inspect: return "Inspect"
        case .generate: return "Generate"
        case .encode: return "Encode"
        }
    }

    /// SF Symbol per the Phosphor → SF Symbols mapping in docs/mesoneer-design-system.md
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .format: return "text.alignleft"
        case .convert: return "arrow.left.arrow.right"
        case .inspect: return "magnifyingglass"
        case .generate: return "wand.and.stars"
        case .encode: return "lock.shield"
        }
    }

    func count(in registry: ToolRegistry) -> Int { registry.tools(in: self, matching: "").count }
    func badge(from registry: ToolRegistry) -> String? { nil }
}

/// Lightweight summary used for grid/list display. The actual tool View + Logic live in
/// Sources/Tools/<ToolName>.swift — this is just what's needed to render the picker.
struct DevToolSummary: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let category: ToolCategory
    let keywords: [String]
}

/// Single source of truth for every tool. Add one entry here per new tool — this is the
/// "registry pattern" referenced throughout the architecture/task plans.
final class ToolRegistry {
    static let shared = ToolRegistry()

    let all: [DevToolSummary] = [
        DevToolSummary(
            id: "json-formatter", name: "JSON Formatter",
            subtitle: "Validate, pretty-print, and minify JSON",
            icon: "curlybraces", category: .format,
            keywords: ["json", "format", "validate", "pretty", "minify"]
        ),
        DevToolSummary(
            id: "base64", name: "Base64",
            subtitle: "Encode and decode Base64 strings",
            icon: "arrow.left.arrow.right.square", category: .encode,
            keywords: ["base64", "encode", "decode"]
        ),
        DevToolSummary(
            id: "hash-generator", name: "Hash Generator",
            subtitle: "MD5, SHA-1, SHA-256, Keccak-256",
            icon: "number", category: .generate,
            keywords: ["hash", "md5", "sha1", "sha256", "keccak"]
        ),
        DevToolSummary(
            id: "yaml-to-json", name: "YAML to JSON",
            subtitle: "Convert YAML documents to JSON",
            icon: "arrow.right.doc.on.clipboard", category: .convert,
            keywords: ["yaml", "json", "convert", "yml"]
        ),
        DevToolSummary(
            id: "json-to-yaml", name: "JSON to YAML",
            subtitle: "Convert JSON to YAML documents",
            icon: "arrow.left.doc.on.clipboard", category: .convert,
            keywords: ["json", "yaml", "convert", "yml"]
        ),
        DevToolSummary(
            id: "html-formatter", name: "HTML Beautify/Minify",
            subtitle: "Pretty-print or minify HTML markup",
            icon: "chevron.left.slash.chevron.right", category: .format,
            keywords: ["html", "beautify", "minify", "format", "pretty", "compress"]
        ),
        DevToolSummary(
            id: "css-formatter", name: "CSS Beautify/Minify",
            subtitle: "Pretty-print or minify CSS, incl. nested at-rules",
            icon: "paintbrush", category: .format,
            keywords: ["css", "beautify", "minify", "format", "pretty", "compress"]
        ),
        DevToolSummary(
            id: "xml-formatter", name: "XML Beautify/Minify",
            subtitle: "Pretty-print or minify XML documents",
            icon: "chevron.left.forwardslash.chevron.right", category: .format,
            keywords: ["xml", "beautify", "minify", "format", "pretty", "compress"]
        ),
        DevToolSummary(
            id: "line-sort-dedupe", name: "Line Sort/Dedupe",
            subtitle: "Sort lines alphabetically and remove duplicates",
            icon: "arrow.up.arrow.down", category: .format,
            keywords: ["line", "sort", "dedupe", "duplicate", "unique"]
        ),
        DevToolSummary(
            id: "url-parser", name: "URL Parser",
            subtitle: "Break a URL into scheme, host, path, and query",
            icon: "link", category: .convert,
            keywords: ["url", "query", "parse", "components"]
        ),
        DevToolSummary(
            id: "number-base-converter", name: "Number Base Converter",
            subtitle: "Convert between binary, octal, decimal, hex",
            icon: "number.circle", category: .convert,
            keywords: ["number", "base", "binary", "octal", "hex", "decimal"]
        ),
        DevToolSummary(
            id: "string-case-converter", name: "String Case Converter",
            subtitle: "camelCase, PascalCase, snake_case, kebab-case…",
            icon: "textformat", category: .convert,
            keywords: ["case", "camel", "snake", "kebab", "pascal", "const"]
        ),
        DevToolSummary(
            id: "hex-ascii", name: "Hex ⇄ ASCII",
            subtitle: "Convert between hex bytes and ASCII text",
            icon: "number", category: .convert,
            keywords: ["hex", "ascii", "convert", "bytes"]
        ),
        DevToolSummary(
            id: "json-csv", name: "JSON ⇄ CSV",
            subtitle: "Flatten JSON arrays to CSV and back",
            icon: "tablecells", category: .convert,
            keywords: ["json", "csv", "convert", "spreadsheet"]
        ),
        DevToolSummary(
            id: "csv-editor", name: "CSV Editor",
            subtitle: "Open, edit, and save CSV files as an editable grid",
            icon: "tablecells.fill", category: .convert,
            keywords: ["csv", "editor", "spreadsheet", "grid", "table", "open", "save"]
        ),
        DevToolSummary(
            id: "php-serialize", name: "PHP Serialize/Unserialize",
            subtitle: "Convert between JSON and PHP's serialize() format",
            icon: "curlybraces.square", category: .convert,
            keywords: ["php", "serialize", "unserialize", "json"]
        ),
        DevToolSummary(
            id: "svg-to-css", name: "SVG to CSS",
            subtitle: "Wrap SVG markup as a CSS background-image data URI",
            icon: "photo", category: .convert,
            keywords: ["svg", "css", "data uri", "background-image"]
        ),
        DevToolSummary(
            id: "unix-time", name: "Unix Time Converter",
            subtitle: "Convert between Unix timestamps and ISO 8601 dates",
            icon: "clock", category: .inspect,
            keywords: ["unix", "time", "timestamp", "date", "iso8601"]
        ),
        DevToolSummary(
            id: "jwt-debugger", name: "JWT Debugger",
            subtitle: "Decode a JWT's header, payload, and expiry",
            icon: "key", category: .inspect,
            keywords: ["jwt", "token", "decode", "debug", "auth"]
        ),
        DevToolSummary(
            id: "string-inspector", name: "String Inspector",
            subtitle: "Character, byte, line, and word counts",
            icon: "text.magnifyingglass", category: .inspect,
            keywords: ["string", "inspect", "length", "count", "bytes"]
        ),
        DevToolSummary(
            id: "uuid-ulid", name: "UUID/ULID",
            subtitle: "Generate or decode UUIDs and ULIDs",
            icon: "die.face.5", category: .generate,
            keywords: ["uuid", "ulid", "generate", "decode", "guid"]
        ),
        DevToolSummary(
            id: "lorem-ipsum", name: "Lorem Ipsum Generator",
            subtitle: "Placeholder paragraphs for mockups",
            icon: "text.alignleft", category: .generate,
            keywords: ["lorem", "ipsum", "placeholder", "text"]
        ),
        DevToolSummary(
            id: "random-string", name: "Random String Generator",
            subtitle: "Alphanumeric strings of a given length",
            icon: "shuffle", category: .generate,
            keywords: ["random", "string", "generate", "password"]
        ),
        DevToolSummary(
            id: "url-encode-decode", name: "URL Encode/Decode",
            subtitle: "Percent-encode or decode a URL/query fragment",
            icon: "percent", category: .encode,
            keywords: ["url", "encode", "decode", "percent", "escape"]
        ),
        DevToolSummary(
            id: "html-entity", name: "HTML Entity Encode/Decode",
            subtitle: "Convert &amp; friends to and from plain text",
            icon: "chevron.left.slash.chevron.right", category: .encode,
            keywords: ["html", "entity", "encode", "decode"]
        ),
        DevToolSummary(
            id: "backslash-escape", name: "Backslash Escape/Unescape",
            subtitle: "Escape or unescape \\n, \\t, quotes, and backslashes",
            icon: "textformat.abc", category: .encode,
            keywords: ["backslash", "escape", "unescape", "string"]
        ),
    ]

    func tools(in category: ToolCategory, matching query: String) -> [DevToolSummary] {
        all
            .filter { category == .all || $0.category == category }
            .filter { query.isEmpty
                || $0.name.localizedCaseInsensitiveContains(query)
                || $0.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
            }
    }

    /// Real tool groups only (excludes the synthetic `.all` bucket) — used by the sidebar's
    /// grouped tool list, mirroring devutils.com's "Format / Convert / Inspect / ..." sections.
    var groupedCategories: [ToolCategory] {
        ToolCategory.allCases.filter { $0 != .all }
    }
}

/// Protocol every tool's pure logic conforms to (per the architecture plan's MVVM split).
/// Views call into `run`, catch thrown errors for the error banner — no SwiftUI here.
protocol DevToolLogic {
    static func run(_ input: String) throws -> String
}

enum DevToolError: LocalizedError {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let detail): return detail
        }
    }
}
