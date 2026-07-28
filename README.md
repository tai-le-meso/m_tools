# m_tools

An internal, offline-first developer toolbox for macOS — JSON/YAML/Base64/hash/JWT/etc.
tools in one native app, styled with mesoneer's design system. Nothing you paste ever
leaves the machine: no network calls anywhere in the app.

## Status

26 tools shipped across Format / Convert / Inspect / Generate / Encode, plus a CSV
editor. See `docs/task-plan.md` for the remaining build-out and
`docs/architecture-plan.md` for the technical design.

## Build & run

```sh
./build.sh                       # → build/m_tools.app + m_tools.dmg
open build/m_tools.app
```

Run the smoke tests with `./tests/run.sh`.

See `CONTRIBUTING.md` for the dev loop (`./build.sh --run`), code signing, and how to
cut a release, and `docs/repo-setup.md` for the one-time GitHub setup (CI, release
signing secrets, and publishing the install page).

## Tools

**Format**

| Tool | What it does |
|---|---|
| JSON Formatter | Validate, pretty-print, and minify JSON |
| HTML Beautify/Minify | Pretty-print or minify HTML markup |
| CSS Beautify/Minify | Pretty-print or minify CSS, incl. nested at-rules |
| XML Beautify/Minify | Pretty-print or minify XML documents |
| Line Sort/Dedupe | Sort lines alphabetically and remove duplicates |

**Convert**

| Tool | What it does |
|---|---|
| YAML to JSON | Convert YAML documents to JSON |
| JSON to YAML | Convert JSON to YAML documents |
| JSON ⇄ CSV | Flatten JSON arrays to CSV and back |
| CSV Editor | Open, edit, and save CSV files as an editable grid |
| URL Parser | Break a URL into scheme, host, path, and query |
| Number Base Converter | Convert between binary, octal, decimal, hex |
| String Case Converter | camelCase, PascalCase, snake_case, kebab-case… |
| Hex ⇄ ASCII | Convert between hex bytes and ASCII text |
| PHP Serialize/Unserialize | Convert between JSON and PHP's `serialize()` format |
| SVG to CSS | Wrap SVG markup as a CSS `background-image` data URI |

**Inspect**

| Tool | What it does |
|---|---|
| Unix Time Converter | Convert between Unix timestamps and ISO 8601 dates |
| JWT Debugger | Decode a JWT's header, payload, and expiry |
| String Inspector | Character, byte, line, and word counts |

**Generate**

| Tool | What it does |
|---|---|
| Hash Generator | MD5, SHA-1, SHA-256 (via CryptoKit) |
| UUID/ULID | Generate or decode UUIDs and ULIDs |
| Lorem Ipsum Generator | Placeholder paragraphs for mockups |
| Random String Generator | Alphanumeric strings of a given length |

**Encode**

| Tool | What it does |
|---|---|
| Base64 | Encode and decode Base64 strings |
| URL Encode/Decode | Percent-encode or decode a URL/query fragment |
| HTML Entity Encode/Decode | Convert `&amp;` and friends to and from plain text |
| Backslash Escape/Unescape | Escape or unescape `\n`, `\t`, quotes, backslashes |

## Shared features

These come from the shared `ToolView` layout, so every tool above gets them for free.

- **Live two-pane layout** — output updates as you type; no "run" button.
- **Mode switching** — tools with two directions (Beautify/Minify, JSON→CSV/CSV→JSON)
  share one input and switch with a pill toggle instead of occupying two sidebar entries.
- **Syntax highlighting** — JSON, HTML, XML, CSS, and YAML output is colored by token
  role (keys, strings, numbers, keywords, comments, tags, attributes), with separate
  light and dark palettes that follow the app theme.
- **Tree view** — JSON, YAML, and XML output can be switched from text to a collapsible
  node tree with expand/collapse per node, expand/collapse all, and child-count badges.
  Built on `NSOutlineView`, so it stays responsive on large documents.
- **Expand to fullscreen** — either pane can be blown up to near-screen size for reading
  or editing long payloads.
- **Copy/paste shortcuts** — ⌘C / ⌘V with a brief highlight pulse on the pane that
  changed; ⌘A selects all in the focused pane.
- **Scrollable, selectable output** — long minified output scrolls and can be selected
  and copied without being editable.
- **Light/dark toggle** — in the header; the sidebar stays fixed-dark per the design
  system.
- **Menu bar item** — the app runs without a Dock icon; show the window or quit from the
  status item.

The CSV Editor is the one tool with its own layout: a spreadsheet-style grid with a
pinned header row, inferred column types, row numbers, add/remove rows and columns,
a configurable delimiter (comma/semicolon/tab/pipe/custom), and a double-click cell
dialog that shows full content, pretty-prints JSON values, and saves straight back to
the open file.

## What's in here

```
Sources/            all Swift source — no Xcode project, no SPM (see CONTRIBUTING.md)
  Theme.swift        design tokens (colors, type, spacing, syntax palette)
  Components.swift    reusable styled views (nav item, chip, tab, search field, buttons)
  AppShellView.swift  sidebar + header + selected tool pane
  ToolView.swift       shared two-pane input/output layout every tool uses
  TreeOutlineView.swift  NSOutlineView-backed collapsible tree for JSON/YAML/XML output
  ToolRegistry.swift   single source of truth for available tools
  ToolViewFactory.swift  maps a tool id to its SwiftUI view
  Core/                shared parsers: YAML, HTML, CSS, CSV, ULID, syntax, tree building
  Tools/               one file per tool: pure logic + SwiftUI view
docs/index.html      the install/release page the team uses (self-contained, no build step)
docs/repo-setup.md   one-time GitHub setup: CI, signing secrets, Pages
docs/deployment.md   IT-facing: MDM .pkg deployment, and installing without admin rights
docs/                architecture plan, task plan, design system reference
.github/workflows/   ci.yml (build + tests on every push) and release.yml (tag → signed DMG)
tools/makeicon.swift  draws the app icon in code and writes the multi-res .icns
tests/main.swift        standalone smoke tests (run via tests/run.sh)
build.sh             the entire build system
```

## Design system

Colors, type, and component patterns are ported from the Mesoneer Console design
system (`docs/mesoneer-design-system.md`) — same brand language as mesoneer's other
internal tools (e.g. m_capture), applied to this app's own content.

**Note:** Manrope (the brand typeface) isn't a macOS system font and isn't bundled in
this skeleton yet — drop the `.ttf` files (SIL Open Font License, from Google Fonts)
into `Sources/Resources/Fonts/` before building, or `ThemeFont` will silently fall back
to the system font.
