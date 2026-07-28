#!/bin/bash
# Compiles and runs the logic smoke tests.
#
# The test binary is "the whole app, with its entry point swapped for the tests". That's the
# only split that actually works here, because every file under Sources/Tools/ contains both
# a tool's pure `Logic` enum *and* its SwiftUI `View` — so the logic cannot be compiled
# without the view layer sitting next to it, which in turn pulls in ToolView, Theme,
# Components, and so on.
#
# Hence exactly one exclusion: Sources/main.swift. It holds the app's top-level startup
# statements, tests/main.swift holds the tests' own, and Swift permits only one file with
# top-level code per module. Everything else under Sources/ comes along.
#
# The list is derived with `find` rather than enumerated by hand on purpose. The previous
# version of this script spelled out 33 paths, and that list was both wrong (it omitted the
# view files the tool files depend on) and exactly the kind of thing that rots silently
# every time a file is added.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DIR/build/logic_tests"
mkdir -p "$DIR/build"

SOURCES=("$DIR/tests/main.swift")
while IFS= read -r -d '' f; do
    SOURCES+=("$f")
done < <(find "$DIR/Sources" -name '*.swift' ! -path "$DIR/Sources/main.swift" -print0)

# Guard against a silent no-op if this is ever run from an unexpected location.
if [ "${#SOURCES[@]}" -lt 2 ]; then
    echo "tests/run.sh: found no Swift sources under $DIR/Sources" >&2
    exit 1
fi

echo "==> Compiling logic tests (${#SOURCES[@]} files)"
# Same framework set as build.sh, since this compiles the same code.
swiftc -swift-version 5 -O -target "$(uname -m)-apple-macos13.0" \
    -o "$OUT" \
    "${SOURCES[@]}" \
    -framework AppKit -framework SwiftUI -framework CoreImage -framework Security \
    -framework WebKit -framework UniformTypeIdentifiers -framework CryptoKit

echo "==> Running"
"$OUT"
