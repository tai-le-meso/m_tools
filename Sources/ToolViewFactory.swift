import SwiftUI

/// Maps a `DevToolSummary.id` to its concrete tool view. Kept separate from
/// ToolRegistry.swift (which only knows about lightweight summaries) so that file can stay
/// free of SwiftUI imports — this is the one place that wires ids to actual `View`s.
enum ToolViewFactory {
    @ViewBuilder
    static func view(for id: String) -> some View {
        switch id {
        case "json-formatter": JSONFormatterView()
        case "base64": Base64ToolView()
        case "hash-generator": HashGeneratorView()
        case "yaml-to-json": YAMLToJSONView()
        case "json-to-yaml": JSONToYAMLView()
        case "html-formatter": HTMLToolView()
        case "css-formatter": CSSToolView()
        case "xml-formatter": XMLToolView()
        case "line-sort-dedupe": LineSortDedupeView()
        case "url-parser": URLParserView()
        case "number-base-converter": NumberBaseConverterView()
        case "string-case-converter": StringCaseConverterView()
        case "hex-ascii": HexAsciiView()
        case "json-csv": JSONCSVToolView()
        case "csv-editor": CSVEditorView()
        case "php-serialize": PHPSerializeToolView()
        case "svg-to-css": SVGToCSSView()
        case "unix-time": UnixTimeConverterView()
        case "jwt-debugger": JWTDebuggerView()
        case "string-inspector": StringInspectorView()
        case "uuid-ulid": UUIDULIDToolView()
        case "lorem-ipsum": LoremIpsumView()
        case "random-string": RandomStringView()
        case "url-encode-decode": URLEncodeDecodeView()
        case "html-entity": HTMLEntityView()
        case "backslash-escape": BackslashEscapeView()
        default:
            VStack {
                Text("Tool not wired up yet").foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
