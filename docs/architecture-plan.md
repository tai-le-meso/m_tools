# Internal m_tools — Native macOS (Swift) — Architecture Plan

**Goal:** Same tool set as the SPA plan, but as a真 native macOS app — SwiftUI UI, works fully offline (no browser, no JS runtime, no network calls ever), menu-bar clipboard detection, distributed as a signed/notarized `.app` for internal team use.

---

## 1. Tech Stack

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI (macOS 13+ target) | Modern, less boilerplate than AppKit; `NavigationSplitView` gives sidebar+detail for free |
| Language | Swift 5.9+ | — |
| Architecture | MVVM | Each tool = View + ViewModel + pure `Logic` struct/enum (unit-testable) |
| Build system | **Plain `swiftc`, no Xcode project, no SPM** | Matches internal convention (see m_capture): `build.sh` compiles `Sources/*.swift` directly. No `Package.swift`, no dependency resolution, no `.xcodeproj` to keep in sync |
| Dependencies | **None — system frameworks only** | No SwiftSoup, no Yams, no swift-crypto. Anything those would've covered is either a native framework call or a small custom implementation living in `Sources/` |
| Menu bar agent | `NSStatusItem` (AppKit — no interop shim needed since there's no SwiftUI App lifecycle wrapper to fight) | For clipboard-watching "smart detect" like the original |
| Distribution | Signed + notarized `.app`, DMG | Same dual-identity signing pattern as m_capture (see Section 6) |
| Testing | XCTest, or a lightweight hand-rolled assert harness run via `swift test`-free script (since there's no SPM/Xcode test target without a project) — simplest is a small `swiftc`-compiled test binary that runs `Logic` functions and asserts, matching the "no automated suite, smoke-test by hand" convention if you'd rather skip formal tests entirely | Optional — decide based on how strict you want tool-logic correctness to be |

**Convention alignment:** this mirrors m_capture's stated conventions exactly — "no external dependencies, system frameworks only," icons drawn in code (SF Symbols/CoreGraphics, no image assets), and comments that explain *why* not *what*. Treat those as binding for this project too, not just inspiration.

---

## 2. App Shell / UX

- **Main window**: `NavigationSplitView` — sidebar with categories/search, detail pane per tool.
- **Command palette**: `⌘K` opens a floating `NSPanel`/`SwiftUI.Sheet` with a `.searchable` fuzzy list over the tool registry (same pattern as Spotlight/Raycast).
- **Menu bar extra**: `NSStatusItem` with a small icon; clicking it polls `NSPasteboard.general.changeCount`, runs the same detection heuristics as below, and offers "Open in [Tool]" — this is the exact equivalent of DevUtils' clipboard-detect feature, and it's *easier* in native macOS since you get real system clipboard access without browser permission prompts.
- **Two-pane tool view**: reusable `ToolView` component — input `TextEditor`, output `TextEditor`/styled text, copy button (`NSPasteboard`), clear button, inline error `Text`.
- **Appearance**: follow system light/dark automatically (`@Environment(\.colorScheme)`), no manual toggle needed unless you want an override.
- **Global keyboard shortcuts** via `.keyboardShortcut()` modifiers (⌘K palette, ⌘Enter run, Esc clear).

---

## 3. Architecture Pattern

```swift
protocol DevTool: Identifiable {
    var id: String { get }
    var name: String { get }
    var category: ToolCategory { get }
    var keywords: [String] { get }
    associatedtype ViewType: View
    func makeView() -> ViewType
}
```

- `ToolRegistry`: a single static array of all tools (mirrors the `registry.ts` idea from the SPA plan) — one place to add a new tool.
- Each tool's transformation logic lives in a pure, side-effect-free `enum Logic { static func run(_ input: String) throws -> String }` — fully unit-testable, fully decoupled from SwiftUI.
- Views only handle binding/display; they call into `Logic` and catch thrown errors for the error banner.

---

## 4. Project Structure

```
m_tools/
├── build.sh                              # compiles Sources/*.swift, signs, packages DMG
├── CONTRIBUTING.md
├── Sources/
│   ├── main.swift                        # entry point (NSApplication / @main-equivalent)
│   ├── AppDelegate.swift
│   ├── MenuBarController.swift           # NSStatusItem + clipboard watcher
│   ├── AppState.swift
│   ├── ToolRegistry.swift
│   ├── DevTool.swift                     # protocol + category enum
│   ├── Detection.swift                   # smart-detect heuristics
│   ├── Theme.swift                       # all styling — no hardcoded colors/fonts elsewhere
│   ├── ToolView.swift                    # reusable two-pane layout
│   ├── CopyButton.swift
│   ├── SidebarView.swift
│   ├── Tools/
│   │   ├── JSONFormatter.swift           # view + logic in one file, or split if it grows
│   │   ├── Base64Tool.swift
│   │   ├── HashGenerator.swift
│   │   └── ... (one file per tool, or one folder per tool if a tool's view+logic gets large)
│   └── Vendor/
│       └── (none — kept empty deliberately; no external deps)
├── tools/
│   └── makeicon.swift                    # generates .icns in code, no image assets
├── tests/
│   └── logic_tests.swift                 # simple assert-based smoke tests, compiled standalone
├── docs/                                  # optional landing site (GitHub Pages), mirrors m_capture
└── .github/workflows/release.yml
```

No `.xcodeproj`, no `Package.swift`. `build.sh` is the entire build system — one `swiftc` invocation compiling every file under `Sources/`.

---

## 5. Tool-by-Tool: Framework/Library Mapping

### Format / Validate / Minify
| Tool | Approach |
|---|---|
| JSON Format/Validate | `JSONSerialization` (`.prettyPrinted`, `.sortedKeys` options) — fully native |
| HTML Beautify/Minify | Custom lightweight HTML tokenizer (tag/attribute/text scanner — not a full DOM) for pretty-print indentation; minify = strip inter-tag whitespace |
| CSS/SCSS/LESS Beautify/Minify | Custom lightweight tokenizer/formatter (no solid native or Swift-package equivalent to `js-beautify`/`csso` — write a small rule-based formatter; fine for typical CSS, won't handle every edge case of a full parser) |
| JS Beautify/Minify | Custom minifier (strip comments/collapse whitespace) — full JS AST beautify (Prettier-equivalent) doesn't have a good pure-Swift port; flag as "best-effort" in UI, or deprioritize if team doesn't need it much |
| XML Beautify/Minify | `Foundation.XMLDocument` — has native pretty-print via `XMLNode.Options` |
| SQL Formatter | Custom keyword-based formatter (no mature Swift SQL formatter package) |
| Line Sort/Dedupe | Pure Swift (`Set`, `sorted()`, `String` splitting) |

### Data Converter / Parser
| Tool | Approach |
|---|---|
| URL/Query Parser | `URLComponents.queryItems` — native |
| YAML ⇄ JSON | **Custom YAML parser** covering common block/flow mappings, sequences, and scalars (a practical subset, not the full YAML 1.2 spec — flag edge cases like anchors/aliases/multi-doc streams as unsupported in the UI) |
| Number Base Converter | Native `Int(String, radix:)` / `String(Int, radix:)` |
| JSON ⇄ CSV | Custom (JSON via `JSONSerialization`; CSV via a small hand-written writer/parser — quoting/escaping rules are simple enough to implement directly) |
| HTML to JSX | Custom transform pass on the same lightweight HTML tokenizer used for HTML Beautify |
| String Case Converter | Pure Swift regex/split logic |
| PHP ⇄ JSON / Serialize | Custom PHP serialization format parser (well-documented spec, straightforward to implement) |
| SVG to CSS | Native (base64 via `Data.base64EncodedString()` + string template) |
| cURL to Code | Custom parser for curl flags → generate Swift/Python/JS snippets (no Swift equivalent of `curlconverter`; scope down to a few target languages) |
| JSON to Code (typed models) | Custom codegen (parse JSON → infer types → emit Swift/TS structs); a lighter-scope version of quicktype focused on 1–2 languages |
| Hex ⇄ ASCII | Native (`Data`, `String(format:)`) |

### Inspect / Preview / Debug
| Tool | Approach |
|---|---|
| Unix Time Converter | `Date(timeIntervalSince1970:)` + `DateFormatter`/`ISO8601DateFormatter` — native |
| JWT Debugger | Native: split on `.`, base64url-decode header/payload with `Data(base64Encoded:)` (handle URL-safe padding manually) |
| RegExp Tester | Swift's native `Regex`/`RegexBuilder` (Swift 5.7+) or `NSRegularExpression` for match highlighting |
| HTML Preview | `WKWebView` (loads local `srcdoc`-equivalent via `loadHTMLString`, no network access needed) |
| Text Diff Checker | Custom Myers diff implementation (~100 lines, well-documented algorithm — no dependency needed) |
| String Inspector | Native (`count`, `.utf8.count`, `components(separatedBy:)`) |
| Markdown Preview | `AttributedString(markdown:)` — **built into Foundation since macOS 12**, zero dependencies |
| Cron Job Parser | Custom cron-expression parser + human-readable description generator (well-defined grammar) |
| Color Converter | Native `NSColor` color-space conversions (RGB/HSB), custom HEX parsing |

### Generators
| Tool | Approach |
|---|---|
| UUID/ULID Generate/Decode | `UUID()` native; ULID via small custom implementation (simple spec: timestamp + randomness, base32-encoded) |
| Lorem Ipsum Generator | Static word bank + native random selection |
| QR Code Generator | `CIFilter.qrCodeGenerator` — **built into CoreImage**, zero dependencies |
| QR Code Reader | `CIDetector(ofType: CIDetectorTypeQRCode)` — also built into CoreImage |
| Hash Generator (MD5/SHA1/SHA2) | **`CryptoKit`** — a genuine system framework, imported directly (no bridging header needed). Uses `Insecure.MD5`/`Insecure.SHA1` — Apple's own non-deprecated replacement for CommonCrypto's `CC_MD5`/`CC_SHA1`, meant exactly for legacy/compatibility hashing — plus `SHA256`. This is *not* a third-party dependency, and produces byte-identical digests to CommonCrypto |
| Hash Generator (Keccak-256) | **Custom pure-Swift implementation** — not in CryptoKit or any system framework (it's a blockchain-specific variant of SHA-3 with different padding); the Keccak-f[1600] permutation is a well-documented, self-contained ~150-line algorithm, safe to hand-write and unit-test independently |
| Random String Generator | Native `Int.random`/`CharacterSet` |

### Encoders / Decoders
| Tool | Approach |
|---|---|
| Base64 String Encode/Decode | Native `Data(base64Encoded:)` / `.base64EncodedString()` |
| Base64 Image Encode/Decode | Native (`NSImage` + `Data`, drag-and-drop via `NSItemProvider`) |
| URL Encode/Decode | Native `addingPercentEncoding` / `removingPercentEncoding` |
| HTML Entity Encode/Decode | Small lookup-table-based encode/decode (named entities list) |
| Backslash Escape/Unescape | Pure Swift string processing |
| X.509 Certificate Decoder | **Security framework** — `SecCertificateCreateWithData`, `SecCertificateCopyValues` — genuinely native, this is actually *better supported* on macOS than in the browser |

**Net dependency count: zero.** Every tool is either a direct Apple framework call (Foundation, CoreImage, Security, CryptoKit) or a small custom implementation living in `Sources/`. No `Package.swift`, no `Package.resolved` to audit, no supply-chain surface at all — the strongest possible version of "runs absolutely locally."

---

## 6. Signing & Distribution

Same dual-identity pattern as m_capture, and for the same underlying reason: **macOS ties a permission grant (Accessibility, Screen Recording, etc.) to the signing certificate's identity, not the app's name or path.** Even if this specific tool doesn't request sensitive permissions today, using a stable identity from day one costs nothing and avoids a nasty surprise if a future tool (e.g. a global hotkey for the command palette) needs one.

- **`m_tools-dev`** — a self-signed local Code Signing cert, one per developer, used by `./build.sh --run`. Keeps your own rebuild loop from re-prompting for any permission.
- **`m_tools-release`** — the *one* shared identity every published build is signed with, so every teammate's install updates in place without re-granting anything. Exported as `.p12`, stored as CI secrets, pinned by SHA-1 in `build.sh` so a release accidentally signed by the wrong cert hard-fails instead of shipping.
- **No Mac App Store / sandbox** — direct Developer ID–style internal distribution (DMG via GitHub Releases, or an internal Homebrew tap) avoids sandbox entitlement friction entirely, matching m_capture's approach.
- **Auto-update:** m_capture rolls its own (silent daily check + "Check for Updates" menu item, comparing against GitHub Releases) rather than pulling in Sparkle as a dependency — worth mirroring that here too, to keep the zero-dependency property intact. A small custom updater is straightforward: hit the GitHub Releases API, compare `CFBundleShortVersionString`, prompt to download+swap if newer.

See the adapted `build.sh` and `CONTRIBUTING.md` "Releasing" section for the concrete implementation.

---

## 7. Build Phases (high-level — see detailed task list separately)

1. Project setup + app shell (sidebar, routing, theme follows system)
2. Core architecture (`DevTool` protocol, registry, reusable `ToolView`)
3. Pilot tools (JSON formatter, Base64, Hash generator) to validate pattern
4. Bulk tool build-out (~40 tools, parallelizable by category)
5. Menu-bar clipboard watcher + smart detection + ⌘K command palette
6. Polish (syntax highlighting via a text-view coloring pass, keyboard shortcuts, empty states)
7. Signing, notarization, distribution setup (DMG or Homebrew tap), optional Sparkle auto-update
