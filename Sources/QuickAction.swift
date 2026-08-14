import Foundation

/// One entry in the menu bar's Quick Actions list: take whatever is on the clipboard, run a
/// single transform over it, and open the app at the matching tool.
///
/// A quick action is deliberately *an operation*, not a tool. Several tools expose two
/// directions behind a mode switch — CSS Beautify vs Minify, JSON → CSV vs CSV → JSON — and
/// "run the CSS tool" isn't a thing a user can mean from a menu. `modeIndex` records which
/// of the tool's modes the action corresponds to so the app can open on the right one.
struct QuickAction: Identifiable {
    /// Stable key used for persistence. Must never change once shipped, or a user's saved
    /// selection silently loses that action.
    let id: String
    /// Menu item text. Written as the operation ("JSON → YAML"), not the tool name.
    let title: String
    /// `DevToolSummary.id` of the tool to open — the same ids `ToolViewFactory` switches on.
    let toolId: String
    /// Which of the tool's modes this is, for multi-mode tools; `nil` for single-transform
    /// tools, which have exactly one mode.
    let modeIndex: Int?
    /// The transform itself. Same `DevToolLogic.run` the tool's own view calls, so a quick
    /// action can never drift from what the tool does.
    let run: (String) throws -> String
}

/// Every action that *can* be enabled, plus which are on by default.
///
/// Deliberately not "all 26 tools": generators (UUID, Lorem Ipsum, Random String) ignore
/// their input, so running them against the clipboard is meaningless, and a menu listing
/// everything would defeat the purpose. What's here is the set where "I have this on my
/// clipboard, give me the other form" is a sentence that makes sense.
enum QuickActionCatalog {
    static let all: [QuickAction] = [
        QuickAction(id: "json-format", title: "Format JSON", toolId: "json-formatter", modeIndex: nil, run: JSONFormatterLogic.run),
        QuickAction(id: "json-to-yaml", title: "JSON → YAML", toolId: "json-to-yaml", modeIndex: nil, run: JSONToYAMLLogic.run),
        QuickAction(id: "yaml-to-json", title: "YAML → JSON", toolId: "yaml-to-json", modeIndex: nil, run: YAMLToJSONLogic.run),
        QuickAction(id: "jwt-decode", title: "Decode JWT", toolId: "jwt-debugger", modeIndex: nil, run: JWTDebuggerLogic.run),
        QuickAction(id: "base64", title: "Base64 Encode/Decode", toolId: "base64", modeIndex: nil, run: Base64Logic.run),
        QuickAction(id: "url-encode", title: "URL Encode/Decode", toolId: "url-encode-decode", modeIndex: nil, run: URLEncodeDecodeLogic.run),
        QuickAction(id: "url-parse", title: "Parse URL", toolId: "url-parser", modeIndex: nil, run: URLParserLogic.run),
        QuickAction(id: "unix-time", title: "Convert Unix Time", toolId: "unix-time", modeIndex: nil, run: UnixTimeConverterLogic.run),
        QuickAction(id: "hash", title: "Hash (MD5 / SHA)", toolId: "hash-generator", modeIndex: nil, run: HashGeneratorLogic.run),
        QuickAction(id: "xml-beautify", title: "Beautify XML", toolId: "xml-formatter", modeIndex: 0, run: XMLBeautifyLogic.run),
        QuickAction(id: "xml-minify", title: "Minify XML", toolId: "xml-formatter", modeIndex: 1, run: XMLMinifyLogic.run),
        QuickAction(id: "html-beautify", title: "Beautify HTML", toolId: "html-formatter", modeIndex: 0, run: HTMLBeautifyLogic.run),
        QuickAction(id: "html-minify", title: "Minify HTML", toolId: "html-formatter", modeIndex: 1, run: HTMLMinifyLogic.run),
        QuickAction(id: "css-beautify", title: "Beautify CSS", toolId: "css-formatter", modeIndex: 0, run: CSSBeautifyLogic.run),
        QuickAction(id: "css-minify", title: "Minify CSS", toolId: "css-formatter", modeIndex: 1, run: CSSMinifyLogic.run),
        QuickAction(id: "json-to-csv", title: "JSON → CSV", toolId: "json-csv", modeIndex: 0, run: JSONToCSVLogic.run),
        QuickAction(id: "csv-to-json", title: "CSV → JSON", toolId: "json-csv", modeIndex: 1, run: CSVToJSONLogic.run),
        QuickAction(id: "html-entity", title: "HTML Entity Encode/Decode", toolId: "html-entity", modeIndex: nil, run: HTMLEntityLogic.run),
        QuickAction(id: "backslash-escape", title: "Backslash Escape/Unescape", toolId: "backslash-escape", modeIndex: nil, run: BackslashEscapeLogic.run),
        QuickAction(id: "hex-ascii", title: "Hex ⇄ ASCII", toolId: "hex-ascii", modeIndex: nil, run: HexAsciiLogic.run),
        QuickAction(id: "case-convert", title: "Convert String Case", toolId: "string-case-converter", modeIndex: nil, run: StringCaseConverterLogic.run),
        QuickAction(id: "number-base", title: "Convert Number Base", toolId: "number-base-converter", modeIndex: nil, run: NumberBaseConverterLogic.run),
        QuickAction(id: "sort-dedupe", title: "Sort & Dedupe Lines", toolId: "line-sort-dedupe", modeIndex: nil, run: LineSortDedupeLogic.run),
        QuickAction(id: "inspect-string", title: "Inspect String", toolId: "string-inspector", modeIndex: nil, run: StringInspectorLogic.run),
    ]

    /// Shown to someone who has never opened the settings — the handful a backend or web
    /// developer reaches for most, kept short enough that the menu stays scannable.
    static let defaultIDs: [String] = [
        "json-format",
        "json-to-yaml",
        "yaml-to-json",
        "jwt-decode",
        "base64",
        "url-encode",
        "unix-time",
    ]

    static func action(withID id: String) -> QuickAction? {
        all.first { $0.id == id }
    }

    /// Resolves saved ids to actions, dropping any that no longer exist. Order follows the
    /// saved list, which is what makes the settings screen's reordering meaningful.
    static func actions(for ids: [String]) -> [QuickAction] {
        ids.compactMap(action(withID:))
    }
}
