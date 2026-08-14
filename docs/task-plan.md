# m_tools — Native macOS (Swift) — Detailed Task Plan

Checkbox format for pasting into Jira/Linear/GitHub Issues. Estimates assume one mid-level Swift/SwiftUI developer working solo; Phase 2 parallelizes well across multiple devs since tools are independent.

---

## Phase 0 — Project Setup (0.5 day)

- [ ] Create new Xcode project: macOS App, SwiftUI lifecycle, deployment target macOS 13+
- [ ] Set up folder structure (`Core/`, `Tools/`, `Shared/`, `App/`, `Tests/`)
- [ ] Add SPM dependencies: SwiftSoup, Yams, swift-crypto (add others later as needed)
- [ ] Configure code signing (Developer ID, or internal team cert)
- [ ] Set up SwiftLint (optional but recommended for a multi-contributor tool codebase)
- [ ] Set up a basic CI (GitHub Actions/Xcode Cloud) — build + run XCTest on PR
- [ ] Create `.gitignore` for Xcode/SPM artifacts, push to internal git remote

---

## Phase 1 — Core Architecture & App Shell (1–2 days)

- [ ] Define `DevTool` protocol + `ToolCategory` enum
- [ ] Build `ToolRegistry` (static array, one source of truth)
- [ ] Build `SidebarView` — grouped by category, `.searchable` filter
- [ ] Build main `NavigationSplitView` shell (sidebar + detail)
- [ ] Build reusable `ToolView` — input `TextEditor`, output pane, `CopyButton`, `ClearButton`, error banner
- [ ] Build `CopyButton` (writes to `NSPasteboard.general`, shows checkmark feedback via brief state toggle)
- [ ] Implement 3 pilot tools end-to-end to validate the whole pattern:
  - [ ] JSON Format/Validate (`JSONFormatterLogic.swift` + view + XCTest)
  - [ ] Base64 String Encode/Decode
  - [ ] Hash Generator (MD5/SHA1/SHA256 via swift-crypto)
- [ ] Internal review of the skeleton before mass tool build-out

---

## Phase 2 — Tool Build-Out

Per-tool sub-tasks: **(a)** write pure `Logic` type, **(b)** XCTest coverage, **(c)** SwiftUI view via `ToolView`, **(d)** register in `ToolRegistry` with keywords, **(e)** manual smoke test.

Effort key: S ≈ 30–60min, M ≈ 1–2hrs, L ≈ 2–4hrs (native-framework tools tend to be faster than the SPA equivalents; custom-parser tools take longer since there's no off-the-shelf Swift package).

### Format / Validate / Minify
- [ ] JSON Format/Validate — *(done Phase 1)*
- [x] HTML Beautify/Minify — M (custom tokenizer/DOM in `Sources/Core/HTMLParser.swift`, no SwiftSoup per CLAUDE.md)
- [x] CSS Beautify/Minify — custom tokenizer/formatter in `Sources/Core/CSSParser.swift` (handles nested at-rules too)
- [ ] JS Beautify/Minify — L (custom, best-effort; consider deprioritizing if rarely used)
- [ ] SCSS Beautify/Minify — L (extend `CSSParser` for nesting/variables)
- [ ] LESS Beautify/Minify — L (extend `CSSParser` for LESS syntax)
- [x] XML Beautify/Minify — native `XMLDocument` pretty-print/compact in `Sources/Tools/XMLTool.swift`
- [ ] SQL Formatter — L (custom keyword-based formatter)
- [x] Line Sort/Dedupe — `Sources/Tools/LineSortDedupeTool.swift` (sort + dedupe; no case-insensitive/reverse toggle yet — ToolView has no per-tool options UI)

### Data Converter / Parser
- [x] URL/Query String Parser — `Sources/Tools/URLParserTool.swift` (`URLComponents`)
- [x] YAML → JSON — custom parser in `Sources/Core/YAMLParser.swift`, no Yams per CLAUDE.md
- [x] JSON → YAML — same custom parser, serializer direction
- [x] Number Base Converter — `Sources/Tools/NumberBaseConverterTool.swift` (auto-detects 0x/0b/0o/decimal)
- [x] JSON → CSV — `Sources/Tools/JSONCSVTool.swift` (flat object arrays, sorted headers for deterministic columns)
- [x] CSV → JSON — same tool, other mode (custom quoted-field CSV parser)
- [ ] HTML to JSX — M (custom transform on the `HTMLParser` tree)
- [x] String Case Converter — `Sources/Tools/StringCaseConverterTool.swift` (camel/Pascal/snake/kebab/const/Title)
- [x] PHP → JSON — `Sources/Tools/PHPSerializeTool.swift`, "PHP → JSON" mode
- [x] JSON → PHP — same tool, "JSON → PHP" mode
- [x] PHP Serializer — merged into the tool above (JSON → PHP mode)
- [x] PHP Unserializer — merged into the tool above (PHP → JSON mode)
- [x] SVG to CSS — `Sources/Tools/SVGToCSSTool.swift` (base64 data URI)
- [ ] cURL to Code — L (custom curl-flag parser → 2–3 target languages, e.g. Swift + Python + JS)
- [ ] JSON to Code (typed models) — L (custom type-inference + codegen, scope to 1–2 languages initially)
- [x] Hex → ASCII — merged into one smart-direction tool, `Sources/Tools/HexAsciiTool.swift`
- [x] ASCII → Hex — same tool as above (auto-detects direction, like the Base64 tool)
- [x] **Quick Actions** *(not in the original tool list — added by request)* — `Sources/QuickAction.swift`, `QuickActionSettings.swift`, `QuickActionRunner.swift`, `QuickActionSettingsView.swift`, `AppState.swift`. Menu bar entries that run a tool's transform over the clipboard, then open the app on that tool with the input prefilled (and the mode preselected, for multi-mode tools). Copying the result back is a setting; the enabled list and its order are user-configurable, with 7 developer-oriented defaults out of a 24-action catalog.
- [x] **Output tree viewer** *(not in the original tool list — added by request)* — `Sources/Core/DataTree.swift` + `Sources/TreeOutlineView.swift`. A Text/Tree toggle in every `ToolView` output pane whose result parses as JSON, YAML, or XML: collapsible node-by-node outline with expand/collapse-all, child-count badges, and role-colored values from the same `Theme.syntax` palette as the text highlighter.
- [x] **CSV Editor** *(not in the original tool list — added by request)* — `Sources/Tools/CSVEditorTool.swift` + `Sources/Core/CSVDocument.swift`. The one tool that doesn't use the shared `ToolView` two-pane layout: a real Open/Save-panel-backed grid with a double-click cell-detail dialog (scrollable editor, JSON auto-detect/pretty-print, saves straight back to the open file), hover tooltips for long content, and add/remove row/column affordances.

### Inspect / Preview / Debug
- [x] Unix Time Converter — `Sources/Tools/UnixTimeConverterTool.swift` (`ISO8601DateFormatter`/`DateFormatter`, multiple formats)
- [x] JWT Debugger — `Sources/Tools/JWTDebuggerTool.swift` (base64url decode, header/payload, expiry check; no signature verification)
- [ ] RegExp Tester — L (Swift `Regex`, live match highlighting via `AttributedString` ranges, capture group display)
- [ ] HTML Preview — S (`WKWebView` + `loadHTMLString`) — needs a non-text-pane UI, deferred until ToolView supports non-text output
- [ ] Text Diff Checker — M (custom Myers diff or Differ package; side-by-side view)
- [x] String Inspector — `Sources/Tools/StringInspectorTool.swift` (length/byte size/line count/word count)
- [ ] Markdown Preview — S (`AttributedString(markdown:)`, native) — same non-text-pane blocker as HTML Preview
- [ ] Cron Job Parser — M (custom parser + human-readable description generator)
- [ ] Color Converter — M (`NSColor` conversions, live swatch preview, HEX/RGB/HSB fields)

### Generators
- [x] UUID/ULID Generate/Decode — `Sources/Tools/UUIDULIDTool.swift` + `Sources/Core/ULID.swift` (native `UUID()`; custom Crockford-Base32 ULID)
- [x] Lorem Ipsum Generator — `Sources/Tools/LoremIpsumTool.swift` (static word bank, optional paragraph-count input)
- [ ] QR Code Generator — S (`CIFilter.qrCodeGenerator`, render to `NSImage`)
- [ ] QR Code Reader — M (`CIDetector`, file drag-drop or paste-image support)
- [ ] Hash Generator — *(pilot, extend)* + Keccak-256 — M (swift-crypto for standard hashes; small custom/third-party Keccak implementation)
- [x] Random String Generator — `Sources/Tools/RandomStringTool.swift` (charset + optional length input)

### Encoders / Decoders
- [ ] Base64 String Encode/Decode — *(done Phase 1)*
- [ ] Base64 Image Encode/Decode — M (drag-drop `NSItemProvider`, `NSImage` ⇄ `Data`)
- [x] URL Encode/Decode — `Sources/Tools/URLEncodeDecodeTool.swift` (`addingPercentEncoding`, smart-direction)
- [x] HTML Entity Encode/Decode — `Sources/Tools/HTMLEntityTool.swift` (reuses `HTMLParser`'s entity table, smart-direction)
- [x] Backslash Escape/Unescape — `Sources/Tools/BackslashEscapeTool.swift` (smart-direction)
- [ ] X.509 Certificate Decoder — L (Security framework: `SecCertificateCreateWithData`, `SecCertificateCopyValues`, format subject/issuer/validity/SANs)

**Phase 2 total estimate:** ~12–16 dev-days solo (slightly more than the SPA version due to a few custom parsers with no ready-made package), or ~4–6 days split across 3 people by category.

---

## Phase 3 — Menu Bar, Clipboard Detection & Command Palette (2–3 days)

- [ ] Build `MenuBarController` — `NSStatusItem` with icon, popover or menu
- [ ] Implement clipboard watcher: poll `NSPasteboard.general.changeCount` on a timer (e.g. every 0.5s) or use a more efficient notification-based approach if available
- [ ] Write `Detection.swift` — ordered heuristics returning best-guess tool:
  - [ ] JSON (`JSONSerialization` parse succeeds)
  - [ ] JWT (three dot-separated base64url segments)
  - [ ] Base64 (regex + valid decode)
  - [ ] Unix timestamp (all-digit, plausible range)
  - [ ] UUID (regex match)
  - [ ] Hex color (`#RRGGBB` pattern)
  - [ ] Cron expression (5–6 space-separated fields matching cron grammar)
- [ ] Wire menu bar click → run detection → show "Open in [Tool]" action(s), opening main window to that tool
- [ ] Build ⌘K command palette (`NSPanel` or SwiftUI `.searchable` sheet), fuzzy-match against `ToolRegistry` name + keywords
- [ ] Register global keyboard shortcut for palette via `NSEvent.addGlobalMonitorForEvents` (native — no third-party hotkey library, staying dependency-free)
- [ ] Manual test pass: paste 10+ varied sample inputs, confirm correct detection

---

## Phase 4 — Polish (2–3 days)

- [ ] Add basic syntax highlighting to `TextEditor`/output panes (custom `NSTextView` subclass with `NSAttributedString` coloring for JSON/HTML/CSS/etc., since SwiftUI's `TextEditor` doesn't support this natively — this is the one area needing an AppKit bridge)
- [ ] Add "Load sample" button per tool (for onboarding/demoing)
- [ ] Consistent error banner styling across all tools
- [ ] Full keyboard shortcut pass (⌘Enter run, ⌘K palette, Esc clear, ⌘C smart-copy)
- [ ] Empty-state text/icon for each tool's input pane
- [ ] Dark/light appearance QA pass (should follow system automatically via SwiftUI, but verify contrast in both)
- [ ] Add "Runs 100% locally, no network access" note somewhere visible (About panel or footer)
- [ ] Accessibility pass: VoiceOver labels on icon-only buttons, Dynamic Type support check

---

## Phase 5 — Signing, Release Automation & Distribution (1–2 days)

- [ ] Write `build.sh` (see adapted script) — compiles `Sources/**/*.swift` via `swiftc`, no Xcode/SPM
- [ ] Create `m_tools-dev` self-signed Code Signing cert (Keychain Access → Self Signed Root) for local `--run` loop
- [ ] One-time admin setup: create `m_tools-release` cert, export `.p12`, add `RELEASE_CERT_P12_BASE64` + `RELEASE_CERT_PASSWORD` GitHub secrets, pin `RELEASE_CERT_SHA` in `build.sh`
- [ ] Write `.github/workflows/release.yml` — on version tag push: import release cert from secrets, run `build.sh`, verify tag matches `VERSION`, publish DMG to GitHub Release
- [x] `tools/makeicon.swift` — draws the app icon in code (CoreGraphics) and writes a multi-resolution `.icns` directly, no image assets. Artwork is branding direction "1b — Brand solid"; the same mark is an SVG symbol in `docs/index.html` and a wordmark in the sidebar.
- [ ] (Optional) small custom update-checker: hit GitHub Releases API, compare `CFBundleShortVersionString`, prompt to download+swap — avoids pulling in Sparkle as a dependency
- [ ] Write `CONTRIBUTING.md` (see adapted version) — build/run, releasing, conventions, "how to add a new tool"
- [ ] Announce internally, distribute DMG link, collect first-week feedback (Slack channel or internal issue tracker)

---

## Ongoing / Backlog

- [ ] Add tools on request (registry pattern keeps this low-friction)
- [ ] Custom update-checker maturity (changelog display in the "Check for Updates" flow), if built
- [ ] Optional: Spotlight-style global hotkey to summon the app from anywhere (not just the in-app palette) — would be the first feature to actually need a permission grant, making the `m_tools-dev`/`m_tools-release` identity split earn its keep
- [ ] Optional: per-tool "recent inputs" history stored locally (e.g. via `UserDefaults` or a local SQLite/Core Data store — still fully offline)

---

## Summary Timeline

| Phase | Effort (solo dev) |
|---|---|
| 0. Setup | 0.5 day |
| 1. Core Architecture & Shell | 1–2 days |
| 2. Tool Build-Out | 12–16 days |
| 3. Menu Bar / Detection / Palette | 2–3 days |
| 4. Polish | 2–3 days |
| 5. Signing & Distribution | 1–2 days |
| **Total** | **~19–26 days solo** (parallelizes well in Phase 2 with 2–3 devs) |

---

## Note vs. the SPA version

The Swift build is slightly heavier in Phase 2 because a few tools (CSS/SCSS/LESS formatting, SQL formatting, cURL-to-code, JSON-to-code) lack mature ready-made Swift packages the way they had solid npm equivalents — those need small custom parsers here. Everything else (hashing, JSON, XML, Markdown, QR, certificates, clipboard access) is actually *less* work than the web version since it's built straight into Apple's frameworks with no dependency wrangling at all.
