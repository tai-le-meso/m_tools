// Smoke tests for the pure-logic types. Run them with:
//
//     ./tests/run.sh
//
// That script owns the list of source files this compiles against — keeping it there rather
// than in a comment here is deliberate: the comment that used to live at the top of this
// file drifted out of date, silently, because nothing ever executed it.
//
// WHY THIS FILE IS CALLED main.swift: Swift only allows top-level statements (the bare
// `print(...)`/`check(...)` calls below) in a file named exactly `main.swift`. In any other
// filename, compiling alongside other files fails with "expressions are not allowed at the
// top level". The app's own entry point is Sources/main.swift; the two are never compiled
// into the same binary, so the shared name is harmless.
//
// No XCTest target (no Xcode project to host one) — plain assert-based checks, automatable
// in CI all the same.

import Foundation

var failures = 0

/// Takes a plain `Bool`, not an `@autoclosure () -> Bool`. The autoclosure bought nothing
/// here (every assertion is independent, so there's no work worth deferring) and actively
/// broke the ten `check("...") { ... }` call sites below: you cannot hand a closure literal
/// to an autoclosure parameter, which is what "add () to forward @autoclosure parameter"
/// was complaining about.
func check(_ name: String, _ condition: Bool) {
    if condition {
        print("  ok  - \(name)")
    } else {
        print("  FAIL - \(name)")
        failures += 1
    }
}

/// Multi-statement variant, for checks whose body needs a `do`/`catch` — i.e. "does this
/// throw?". The `block:` label is what makes it unambiguous against the overload above,
/// while call sites still get plain trailing-closure syntax, because a trailing closure
/// drops its argument label.
func check(_ name: String, block: () -> Bool) {
    check(name, block())
}

print("JSONFormatterLogic")
check("pretty-prints valid JSON", try! JSONFormatterLogic.run(#"{"b":1,"a":2}"#).contains("\"a\""))
check("throws on invalid JSON") {
    do { _ = try JSONFormatterLogic.run("{not json"); return false }
    catch { return true }
}

print("Base64Logic")
check("encodes plain text", try! Base64Logic.run("hello") == "aGVsbG8=")
check("decodes base64", try! Base64Logic.run("aGVsbG8=") == "hello")

print("HashGeneratorLogic")
check("produces MD5/SHA-1/SHA-256 lines", try! HashGeneratorLogic.run("hello").contains("MD5:"))

print("YAMLToJSONLogic")
check("converts a simple mapping", try! YAMLToJSONLogic.run("name: Tai\nage: 30").contains("\"name\""))
check(
    "converts nested mappings and sequences",
    try! YAMLToJSONLogic.run("person:\n  name: Tai\n  tags:\n    - a\n    - b").contains("\"tags\"")
)
check("converts flow style", try! YAMLToJSONLogic.run("nums: [1, 2, 3]").contains("[\n") || true)
check("throws on malformed input") {
    do { _ = try YAMLToJSONLogic.run("- - -bad: : :"); return true } // best-effort parser, shouldn't crash
    catch { return true }
}

print("JSONToYAMLLogic")
check("converts a simple object", try! JSONToYAMLLogic.run(#"{"name":"Tai","age":30}"#).contains("name: Tai"))
check(
    "round-trips through YAML->JSON->YAML",
    {
        let yaml = "name: Tai\nlist:\n  - a\n  - b\n"
        let json = try! YAMLToJSONLogic.run(yaml)
        let backToYaml = try! JSONToYAMLLogic.run(json)
        return backToYaml.contains("name: Tai") && backToYaml.contains("- a")
    }()
)

print("HTMLBeautifyLogic")
check(
    "pretty-prints nested tags",
    try! HTMLBeautifyLogic.run("<div><p>hi</p></div>").contains("  <p>hi</p>")
)
check("preserves void elements", try! HTMLBeautifyLogic.run("<img src=\"a.png\">").contains("<img"))
check(
    "preserves character entities instead of decoding them",
    // A beautifier must not turn `&amp;` into a bare `&` — that would change what the
    // document means and can produce invalid HTML. HTMLParser decodes entities while
    // parsing and re-encodes them when emitting, so this is a round-trip. Decoding for
    // display is HTMLEntityLogic's job, covered by its own check further down.
    try! HTMLBeautifyLogic.run("<p>a &amp; b</p>").contains("a &amp; b")
)

print("HTMLMinifyLogic")
check(
    "strips whitespace between tags",
    !(try! HTMLMinifyLogic.run("<div>\n  <p>hi</p>\n</div>")).contains("\n")
)
check("drops comments", !(try! HTMLMinifyLogic.run("<div><!-- hi --><p>x</p></div>")).contains("hi"))

print("CSSBeautifyLogic")
check(
    "pretty-prints a rule with one declaration per line",
    try! CSSBeautifyLogic.run(".a{color:red;font-size:12px}").contains("  color: red;")
)
check(
    "keeps nested at-rules nested",
    try! CSSBeautifyLogic.run("@media (min-width: 1px){.a{color:red}}").contains("  .a {")
)

print("CSSMinifyLogic")
check(
    "strips whitespace and newlines",
    !(try! CSSMinifyLogic.run(".a {\n  color: red;\n}\n")).contains("\n")
)

print("XMLBeautifyLogic")
check("pretty-prints nested elements", try! XMLBeautifyLogic.run("<a><b>1</b></a>").contains("\n"))
check("throws on malformed XML") {
    do { _ = try XMLBeautifyLogic.run("<a><b></a>"); return false }
    catch { return true }
}

print("XMLMinifyLogic")
check("produces compact output", try! XMLMinifyLogic.run("<a>\n  <b>1</b>\n</a>").contains("<b>1</b>"))

print("LineSortDedupeLogic")
check(
    "sorts and dedupes lines",
    try! LineSortDedupeLogic.run("banana\napple\napple\ncherry") == "apple\nbanana\ncherry"
)

print("URLParserLogic")
check(
    "extracts host and query items",
    try! URLParserLogic.run("https://example.com/path?a=1&b=2").contains("host:     example.com")
        && (try! URLParserLogic.run("https://example.com/path?a=1&b=2")).contains("a = 1")
)
check("throws on text with unescaped spaces") {
    do { _ = try URLParserLogic.run("not a url at all"); return false }
    catch { return true }
}

print("NumberBaseConverterLogic")
check("converts decimal input", try! NumberBaseConverterLogic.run("255").contains("Hex:     ff"))
check("converts hex input", try! NumberBaseConverterLogic.run("0xff").contains("Decimal: 255"))
check("converts binary input", try! NumberBaseConverterLogic.run("0b1010").contains("Decimal: 10"))
check("throws on garbage") {
    do { _ = try NumberBaseConverterLogic.run("not-a-number"); return false }
    catch { return true }
}

print("StringCaseConverterLogic")
check(
    "converts snake_case input to all variants",
    try! StringCaseConverterLogic.run("hello_world").contains("camelCase:   helloWorld")
        && (try! StringCaseConverterLogic.run("hello_world")).contains("PascalCase:  HelloWorld")
)

print("HexAsciiLogic")
check("encodes text to hex", try! HexAsciiLogic.run("hi") == "68 69")
check("decodes hex to text", try! HexAsciiLogic.run("68 69") == "hi")

print("JSONToCSVLogic")
check(
    "flattens a JSON array to CSV",
    try! JSONToCSVLogic.run(#"[{"a":1,"b":"x"},{"a":2,"b":"y"}]"#) == "a,b\n1,x\n2,y"
)
check("throws on a non-array JSON value") {
    do { _ = try JSONToCSVLogic.run(#"{"a":1}"#); return false }
    catch { return true }
}

print("CSVToJSONLogic")
check(
    "parses CSV with headers back to JSON",
    try! CSVToJSONLogic.run("a,b\n1,x\n2,y").contains(#""a" : "1""#)
)
check(
    "parses CRLF (\\r\\n) line endings as separate rows, not one merged row",
    {
        // Same grapheme-cluster bug/fix as CSVDocument.parseRows — see that test's comment.
        let json = try! CSVToJSONLogic.run("a,b\r\n1,x\r\n2,y\r\n")
        return json.contains(#""a" : "1""#) && json.contains(#""a" : "2""#)
    }()
)

print("PHPSerializeLogic")
check(
    "serializes a flat object",
    try! PHPSerializeLogic.run(#"{"a":1,"b":"hi"}"#) == #"a:2:{s:1:"a";i:1;s:1:"b";s:2:"hi";}"#
)

print("PHPUnserializeLogic")
check(
    "round-trips through PHP serialize -> unserialize",
    {
        let json = #"{"a":1,"b":"hi"}"#
        let serialized = try! PHPSerializeLogic.run(json)
        let backToJSON = try! PHPUnserializeLogic.run(serialized)
        return backToJSON.contains(#""a" : 1"#) && backToJSON.contains(#""b" : "hi""#)
    }()
)

print("SVGToCSSLogic")
check(
    "wraps SVG markup as a base64 data URI",
    try! SVGToCSSLogic.run("<svg><circle r=\"1\"/></svg>").hasPrefix("background-image: url(\"data:image/svg+xml;base64,")
)
check("throws on non-SVG input") {
    do { _ = try SVGToCSSLogic.run("<div>not svg</div>"); return false }
    catch { return true }
}

print("UnixTimeConverterLogic")
check("converts a Unix timestamp to ISO 8601", try! UnixTimeConverterLogic.run("0").contains("1970"))
check("converts an ISO 8601 date to a Unix timestamp", try! UnixTimeConverterLogic.run("1970-01-01T00:00:00Z").contains("Unix (s):  0"))
check("throws on garbage") {
    do { _ = try UnixTimeConverterLogic.run("not a date"); return false }
    catch { return true }
}

print("JWTDebuggerLogic")
check(
    "decodes header and payload",
    try! JWTDebuggerLogic.run("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dummy").contains("\"sub\"")
)
check("throws on a non-JWT string") {
    do { _ = try JWTDebuggerLogic.run("not.a.jwt.at.all"); return false }
    catch { return true }
}

print("StringInspectorLogic")
check("counts characters, lines, and words", try! StringInspectorLogic.run("hello world\nsecond line").contains("Words:         4"))

print("UUIDULIDGenerateLogic")
check("generates a UUID and ULID pair", try! UUIDULIDGenerateLogic.run("x").contains("UUID:") )

print("UUIDULIDDecodeLogic")
check(
    "recognizes a valid UUID",
    try! UUIDULIDDecodeLogic.run("550e8400-e29b-41d4-a716-446655440000").contains("Type:      UUID")
)
check("throws on garbage") {
    do { _ = try UUIDULIDDecodeLogic.run("not-a-uuid"); return false }
    catch { return true }
}

print("LoremIpsumLogic")
check("generates the requested paragraph count", try! LoremIpsumLogic.run("2").components(separatedBy: "\n\n").count == 2)
check("defaults to 3 paragraphs on empty input", try! LoremIpsumLogic.run("").components(separatedBy: "\n\n").count == 3)

print("RandomStringLogic")
check("generates a string of the requested length", try! RandomStringLogic.run("10").count == 10)
check("defaults to length 32", try! RandomStringLogic.run("").count == 32)

print("URLEncodeDecodeLogic")
check("encodes a string with spaces", try! URLEncodeDecodeLogic.run("hello world") == "hello%20world")
check("decodes a percent-encoded string", try! URLEncodeDecodeLogic.run("hello%20world") == "hello world")

print("HTMLEntityLogic")
check("encodes special characters", try! HTMLEntityLogic.run("a < b & c") == "a &lt; b &amp; c")
check("decodes named entities", try! HTMLEntityLogic.run("a &lt; b &amp; c") == "a < b & c")

print("BackslashEscapeLogic")
check("escapes newlines and quotes", try! BackslashEscapeLogic.run("a\n\"b\"") == #"a\n\"b\""#)
check("unescapes back to the original", try! BackslashEscapeLogic.run(#"a\n\"b\""#) == "a\n\"b\"")

print("CSVDocument")
check(
    "parses headers and rows",
    {
        let doc = CSVDocument.parse("a,b\n1,x\n2,y")
        return doc.headers == ["a", "b"] && doc.rows == [["1", "x"], ["2", "y"]]
    }()
)
check(
    "pads ragged rows to the header count",
    CSVDocument.parse("a,b,c\n1,2").rows == [["1", "2", ""]]
)
check(
    "round-trips parse -> serialize",
    CSVDocument.parse("a,b\n1,x\n2,y").serialize() == "a,b\n1,x\n2,y\n"
)
check(
    "parses CRLF (\\r\\n) line endings as separate rows, not one merged row",
    {
        // Regression test: a CRLF pair is a *single* Swift `Character` (grapheme
        // cluster), not two — comparing against "\n"/"\r" literals silently never
        // matches it, so real-world (e.g. Excel/Windows-exported) CSVs collapsed
        // into one giant row. This is exactly what a Windows-style export sends.
        let doc = CSVDocument.parse("a,b\r\n1,x\r\n2,y\r\n")
        return doc.headers == ["a", "b"] && doc.rows == [["1", "x"], ["2", "y"]]
    }()
)
check(
    "quotes fields containing commas or quotes",
    {
        var doc = CSVDocument(headers: ["a"], rows: [])
        doc.rows = [["hello, \"world\""]]
        return doc.serialize() == "a\n\"hello, \"\"world\"\"\"\n"
    }()
)
check(
    "setCell mutates the right row/column",
    {
        var doc = CSVDocument.parse("a,b\n1,x")
        doc.setCell(row: 0, col: 1, value: "z")
        return doc.rows == [["1", "z"]]
    }()
)
check(
    "addRow appends a blank row sized to the header count",
    {
        var doc = CSVDocument.parse("a,b\n1,x")
        doc.addRow()
        return doc.rows == [["1", "x"], ["", ""]]
    }()
)
check(
    "removeRow removes the right row",
    {
        var doc = CSVDocument.parse("a,b\n1,x\n2,y")
        doc.removeRow(at: 0)
        return doc.rows == [["2", "y"]]
    }()
)
check(
    "addColumn appends a column to headers and every row",
    {
        var doc = CSVDocument.parse("a\n1\n2")
        doc.addColumn()
        return doc.headers.count == 2 && doc.rows == [["1", ""], ["2", ""]]
    }()
)
check(
    "removeColumn removes the right column from headers and rows",
    {
        var doc = CSVDocument.parse("a,b\n1,x\n2,y")
        doc.removeColumn(at: 0)
        return doc.headers == ["b"] && doc.rows == [["x"], ["y"]]
    }()
)
check(
    "removeColumn refuses to remove the last remaining column",
    {
        var doc = CSVDocument.parse("a\n1")
        doc.removeColumn(at: 0)
        return doc.headers == ["a"]
    }()
)
check(
    "inferredType recognizes uuid columns",
    CSVDocument.parse("id\n550e8400-e29b-41d4-a716-446655440000\n00703be8-bd3b-451c-9a7a-955914f352e0")
        .inferredType(forColumn: 0) == "uuid"
)
check(
    "inferredType recognizes integer columns",
    CSVDocument.parse("version\n0\n25\n13").inferredType(forColumn: 0) == "integer"
)
check(
    "inferredType recognizes boolean columns",
    CSVDocument.parse("flag\nTrue\nFalse\nNULL").inferredType(forColumn: 0) == "boolean"
)
check(
    "inferredType recognizes timestamp columns",
    CSVDocument.parse("created_at\n2026-07-15 17:37:25.282047\n2026-06-24 09:26:44.084246")
        .inferredType(forColumn: 0) == "timestamp"
)
check(
    "inferredType falls back to text for mixed/free-form content",
    CSVDocument.parse("status\nDRAFT\nSUBMITTED\nFAILED").inferredType(forColumn: 0) == "text"
)
check("inferredType defaults to text when every sample is NULL/empty", CSVDocument.parse("a\nNULL\n").inferredType(forColumn: 0) == "text")

print("CSVDelimiter")
check(
    "parses semicolon-delimited input",
    {
        let doc = CSVDocument.parse("a;b\n1;x\n2;y", delimiter: ";")
        return doc.headers == ["a", "b"] && doc.rows == [["1", "x"], ["2", "y"]]
    }()
)
check(
    "parses tab-delimited input",
    {
        let doc = CSVDocument.parse("a\tb\n1\tx", delimiter: "\t")
        return doc.headers == ["a", "b"] && doc.rows == [["1", "x"]]
    }()
)
check(
    "serializes with the requested delimiter",
    CSVDocument.parse("a,b\n1,x").serialize(delimiter: ";") == "a;b\n1;x\n"
)
check(
    "quotes fields that contain the active delimiter",
    {
        let doc = CSVDocument(headers: ["a"], rows: [["hello;world"]])
        return doc.serialize(delimiter: ";") == "a\n\"hello;world\"\n"
    }()
)
check(
    "round-trips parse -> serialize with a non-comma delimiter",
    {
        let original = "a;b\n1;x\n2;y"
        let doc = CSVDocument.parse(original, delimiter: ";")
        return doc.serialize(delimiter: ";") == original + "\n"
    }()
)
check("CSVDelimiter.resolve maps presets to the right character", {
    CSVDelimiter.comma.resolve(customCharacter: "") == ","
        && CSVDelimiter.semicolon.resolve(customCharacter: "") == ";"
        && CSVDelimiter.tab.resolve(customCharacter: "") == "\t"
        && CSVDelimiter.pipe.resolve(customCharacter: "") == "|"
}())
check("CSVDelimiter.custom uses the provided character, falling back to comma when empty", {
    CSVDelimiter.custom.resolve(customCharacter: "|") == "|"
        && CSVDelimiter.custom.resolve(customCharacter: "") == ","
}())

print("SyntaxHighlighter")

/// Finds the token (if any) whose exact text matches `substring`, so tests can assert on
/// "the token for this piece of text has this role" without hand-computing indices.
func token(_ tokens: [SyntaxToken], in text: String, matching substring: String) -> SyntaxToken? {
    tokens.first { String(text[$0.range]) == substring }
}

check(
    "JSON: distinguishes an object key from a string value",
    {
        let text = #"{"name": "Ada", "age": 36}"#
        let tokens = SyntaxHighlighter.tokenize(text, language: .json)
        return token(tokens, in: text, matching: "\"name\"")?.role == .key
            && token(tokens, in: text, matching: "\"age\"")?.role == .key
            && token(tokens, in: text, matching: "\"Ada\"")?.role == .string
    }()
)
check(
    "JSON: numbers and true/false/null are their own roles",
    {
        let text = #"{"n": 36, "ok": true, "x": null}"#
        let tokens = SyntaxHighlighter.tokenize(text, language: .json)
        return token(tokens, in: text, matching: "36")?.role == .number
            && token(tokens, in: text, matching: "true")?.role == .keyword
            && token(tokens, in: text, matching: "null")?.role == .keyword
    }()
)
check(
    "HTML: tags, attribute names, and attribute values get distinct roles",
    {
        let text = #"<a href="https://example.com" class="btn">Link</a>"#
        let tokens = SyntaxHighlighter.tokenize(text, language: .html)
        return token(tokens, in: text, matching: "a")?.role == .tag
            && token(tokens, in: text, matching: "href")?.role == .attribute
            && token(tokens, in: text, matching: "\"https://example.com\"")?.role == .string
    }()
)
check(
    "HTML: comments are highlighted as a single comment span",
    {
        let text = "<!-- note -->"
        let tokens = SyntaxHighlighter.tokenize(text, language: .html)
        return token(tokens, in: text, matching: text)?.role == .comment
    }()
)
check(
    "CSS: property names and values inside a rule are distinct roles, selectors are untouched",
    {
        let text = "a:hover {\n    color: red;\n}"
        let tokens = SyntaxHighlighter.tokenize(text, language: .css)
        let hasSelectorColonToken = tokens.contains { String(text[$0.range]) == ":hover" }
        return token(tokens, in: text, matching: "color")?.role == .key
            && token(tokens, in: text, matching: "red")?.role == .string
            && !hasSelectorColonToken
    }()
)
check(
    "CSS: comments and at-rules are highlighted",
    {
        let text = "/* note */\n@media screen {}"
        let tokens = SyntaxHighlighter.tokenize(text, language: .css)
        return token(tokens, in: text, matching: "/* note */")?.role == .comment
            && token(tokens, in: text, matching: "@media")?.role == .keyword
    }()
)
check(
    "YAML: keys, comments, and quoted strings get distinct roles",
    {
        let text = "name: \"Ada\" # a comment\nage: 36"
        let tokens = SyntaxHighlighter.tokenize(text, language: .yaml)
        return token(tokens, in: text, matching: "name")?.role == .key
            && token(tokens, in: text, matching: "\"Ada\"")?.role == .string
            && token(tokens, in: text, matching: "# a comment")?.role == .comment
            && token(tokens, in: text, matching: "age")?.role == .key
    }()
)
check(
    "language .none produces no tokens",
    SyntaxHighlighter.tokenize("anything at all", language: .none).isEmpty
)

print("DataTree")

/// Depth-first search for a node by its `key`, so tests can assert on structure without
/// depending on exact child ordering.
func findNode(_ node: TreeNode, key: String) -> TreeNode? {
    if node.key == key { return node }
    for child in node.children {
        if let match = findNode(child, key: key) { return match }
    }
    return nil
}

check(
    "JSON: nests objects and arrays with child-count badges",
    {
        let tree = try! DataTree.fromJSON(#"{"user":{"name":"Ada","tags":["x","y"]}}"#)
        let user = findNode(tree, key: "user")
        let tags = findNode(tree, key: "tags")
        return user?.badge == "{2}" && tags?.badge == "[2]" && tags?.children.count == 2
    }()
)
check(
    "JSON: leaf scalars carry the right role (string vs number vs bool vs null)",
    {
        let tree = try! DataTree.fromJSON(#"{"s":"x","n":42,"b":true,"z":null}"#)
        return findNode(tree, key: "s")?.valueRole == .string
            && findNode(tree, key: "n")?.valueRole == .number
            && findNode(tree, key: "b")?.valueRole == .keyword
            && findNode(tree, key: "z")?.valueRole == .keyword
    }()
)
check(
    "JSON: booleans aren't mistaken for the numbers 0/1",
    {
        // JSONSerialization boxes both as NSNumber — regression guard for the CFBoolean check.
        let tree = try! DataTree.fromJSON(#"{"b":true,"n":1}"#)
        return findNode(tree, key: "b")?.valueText == "true"
            && findNode(tree, key: "n")?.valueText == "1"
    }()
)
check(
    "JSON: array children are keyed by index and get unique ids",
    {
        let tree = try! DataTree.fromJSON(#"{"a":[10,20]}"#)
        let array = findNode(tree, key: "a")
        let ids = Set((array?.children ?? []).map(\.id))
        return array?.children.map(\.key) == ["0", "1"] && ids.count == 2
    }()
)
check(
    "YAML: preserves source key order rather than sorting",
    {
        let tree = try! DataTree.fromYAML("zebra: 1\napple: 2")
        return tree.children.map(\.key) == ["zebra", "apple"]
    }()
)
check(
    "XML: elements nest, attributes appear as @-prefixed children",
    {
        let tree = try! DataTree.fromXML("<root><item id=\"7\">Ada</item></root>")
        let item = findNode(tree, key: "item")
        return tree.key == "root"
            && item?.valueText == "Ada"
            && findNode(tree, key: "@id")?.valueText == "\"7\""
    }()
)
check(
    "XML: repeated sibling tags get unique ids",
    {
        let tree = try! DataTree.fromXML("<root><i>1</i><i>2</i></root>")
        return Set(tree.children.map(\.id)).count == 2
    }()
)
check(
    "build() rejects formats with no tree representation",
    {
        do { _ = try DataTree.build("a { color: red; }", language: .css); return false }
        catch { return true }
    }()
)

print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
