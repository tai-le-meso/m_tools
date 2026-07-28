# CLAUDE.md

Context for Claude Code (or any AI assistant) working in this repo. Read `CONTRIBUTING.md`
too — this file is the short version for quick orientation, not a replacement.

## What this is

An internal, offline-first developer toolbox for macOS (native Swift, no Electron/web
tech), styled with mesoneer's shared design system. ~40 planned tools (JSON/YAML/Base64/
hash/JWT/regex/etc.), each a pure-logic function + a SwiftUI view sharing one two-pane
layout.

## Non-negotiable conventions

- **No external dependencies — system frameworks only.** No SPM, no `Package.swift`,
  no CocoaPods. `CryptoKit` (MD5/SHA-1/SHA-256 for the Hash Generator) is a system
  framework, not an added dependency. If a tool seems to need a third-party
  package, write a small custom implementation instead (see `docs/task-plan.md` for
  which tools already have one planned, e.g. the YAML parser, the HTML tokenizer).
- **No Xcode project.** `build.sh` compiles everything under `Sources/**/*.swift` with
  a single `swiftc` invocation. Don't add a `.xcodeproj` or suggest opening one.
- **All styling via `Theme.swift`.** No hardcoded hex colors or font names anywhere
  else. If a component needs a new token, add it to `Theme.swift`, not inline.
- **Icons via SF Symbols, drawn in code — no image assets.** The design source
  (`docs/mesoneer-design-system.md`) uses a Phosphor icon font; that file has the
  Phosphor → SF Symbol mapping table for everything already ported. If a new icon is
  needed and no SF Symbol fits, draw it with CoreGraphics rather than adding an asset.
- **Tool logic stays pure.** Each tool's transform is a `static func run(_ input:
  String) throws -> String` conforming to `DevToolLogic`, with zero SwiftUI imports.
  The View only binds to it via the shared `ToolView` component. This is what makes
  `tests/main.swift` possible without XCTest/Xcode.
- **Comments explain *why*, not *what*.**

## Architecture at a glance

- `Sources/ToolRegistry.swift` — the single source of truth: every tool is one entry
  here (`DevToolSummary`) plus a category. Add a tool = add one entry + one file under
  `Sources/Tools/`.
- `Sources/ToolView.swift` — the shared two-pane input/output layout every tool uses.
  Don't build bespoke layouts per tool unless a tool genuinely can't fit the pattern
  (e.g. a future QR reader needing an image drop zone — extend `ToolView` rather than
  duplicating it).
- `Sources/AppShellView.swift` — sidebar (fixed-dark per the design system, doesn't
  follow light/dark mode), header with search, category tabs, tool grid.
- `Sources/MenuBarController.swift` — clipboard-watching scaffold for smart tool
  detection (Phase 3 in the task plan — not implemented yet, just wired to a timer).

## Design system

Full token reference: `docs/mesoneer-design-system.md`. Short version: colors/type/
spacing come from the Mesoneer Console brand (Manrope font, purple `#3B2A78` primary,
fixed-dark sidebar). When implementing a new UI piece, check that doc before inventing
a new visual pattern — there's very likely an existing component language (chip, tab,
card, nav item) that fits.

## Signing

Two identities, same reasoning as `m_capture`: `m_tools-dev` (local, per-developer,
optional today since this app requests no permissions) and `m_tools-release` (the one
shared identity for shipped builds, pinned by SHA-1 in `build.sh`). See `CONTRIBUTING.md`
→ Releasing for the one-time admin setup.

## Where things stand

Skeleton stage: app shell + theme + 3 pilot tools (JSON Formatter, Base64, Hash
Generator) are wired end-to-end. Everything else in `docs/task-plan.md` Phase 2
onward is not yet built — when asked to add a tool, follow the pattern of the 3
existing ones in `Sources/Tools/` rather than inventing a new structure.

## Known gaps / TODOs

- The app icon and wordmark come from branding direction "1b — Brand solid" (purple
  squircle, white braces, `m` monogram, amber cursor). `tools/makeicon.swift` draws it in
  code and packs a real multi-resolution `.icns`; `docs/index.html` holds the same artwork
  as an SVG symbol. Changing one means changing the other — the coordinates are shared.
- `Sources/Resources/Fonts/` is empty — Manrope `.ttf` files need to be added before
  the custom font actually renders (falls back to system font silently otherwise).
- No YAML/HTML/SQL/cURL/JSON-to-code tools implemented yet — these need custom parsers
  per `docs/mesoneer-design-system.md` §"no external dependencies" and
  `docs/architecture-plan.md` §5.
- `Sources/MenuBarController.swift` polls the clipboard but doesn't run detection
  heuristics yet (`Detection.swift` doesn't exist yet — Phase 3).
