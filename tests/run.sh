#!/bin/bash
# Compiles and runs the logic smoke tests.
#
# Why this script exists: the test file can't simply be compiled against all of Sources/ —
# Sources/main.swift has top-level statements that start the app, and so does
# logic_tests.swift, and Swift permits only one file with top-level code per module. So the
# test target has to name its files explicitly. Keeping that list here (rather than in a
# comment at the top of logic_tests.swift, where it silently went stale) means CI and a
# developer running tests by hand always use the same list.
#
# Rule of thumb when adding a file: pure-logic files (Sources/Core/*, Sources/Tools/*'s
# Logic enums) belong here; view files don't, because the tests never touch SwiftUI.
# Sources/Tools/CSVEditorTool.swift is deliberately absent for that reason — it's pure view,
# with all of its testable behavior living in Sources/Core/CSVDocument.swift.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DIR/build/logic_tests"
mkdir -p "$DIR/build"

SOURCES=(
    "$DIR/tests/logic_tests.swift"
    "$DIR/Sources/ToolRegistry.swift"
    "$DIR/Sources/Core/YAMLParser.swift"
    "$DIR/Sources/Core/HTMLParser.swift"
    "$DIR/Sources/Core/CSSParser.swift"
    "$DIR/Sources/Core/ULID.swift"
    "$DIR/Sources/Core/CSVDocument.swift"
    "$DIR/Sources/Core/SyntaxHighlighter.swift"
    "$DIR/Sources/Core/DataTree.swift"
    "$DIR/Sources/Tools/JSONFormatter.swift"
    "$DIR/Sources/Tools/Base64Tool.swift"
    "$DIR/Sources/Tools/HashGenerator.swift"
    "$DIR/Sources/Tools/YAMLTool.swift"
    "$DIR/Sources/Tools/HTMLTool.swift"
    "$DIR/Sources/Tools/CSSTool.swift"
    "$DIR/Sources/Tools/XMLTool.swift"
    "$DIR/Sources/Tools/LineSortDedupeTool.swift"
    "$DIR/Sources/Tools/URLParserTool.swift"
    "$DIR/Sources/Tools/NumberBaseConverterTool.swift"
    "$DIR/Sources/Tools/StringCaseConverterTool.swift"
    "$DIR/Sources/Tools/HexAsciiTool.swift"
    "$DIR/Sources/Tools/JSONCSVTool.swift"
    "$DIR/Sources/Tools/PHPSerializeTool.swift"
    "$DIR/Sources/Tools/SVGToCSSTool.swift"
    "$DIR/Sources/Tools/UnixTimeConverterTool.swift"
    "$DIR/Sources/Tools/JWTDebuggerTool.swift"
    "$DIR/Sources/Tools/StringInspectorTool.swift"
    "$DIR/Sources/Tools/UUIDULIDTool.swift"
    "$DIR/Sources/Tools/LoremIpsumTool.swift"
    "$DIR/Sources/Tools/RandomStringTool.swift"
    "$DIR/Sources/Tools/URLEncodeDecodeTool.swift"
    "$DIR/Sources/Tools/HTMLEntityTool.swift"
    "$DIR/Sources/Tools/BackslashEscapeTool.swift"
)

# Fail loudly on a path typo rather than letting swiftc report a confusing missing-symbol
# error much later.
for file in "${SOURCES[@]}"; do
    [ -f "$file" ] || { echo "tests/run.sh: missing source: $file" >&2; exit 1; }
done

echo "==> Compiling logic tests (${#SOURCES[@]} files)"
# The tool files pull in SwiftUI for their View types even though the tests only exercise
# the Logic enums, so the same frameworks the app links against are needed here too.
swiftc -swift-version 5 -O -target "$(uname -m)-apple-macos13.0" \
    -o "$OUT" \
    "${SOURCES[@]}" \
    -framework AppKit -framework SwiftUI -framework CoreImage -framework Security \
    -framework WebKit -framework UniformTypeIdentifiers -framework CryptoKit

echo "==> Running"
"$OUT"
