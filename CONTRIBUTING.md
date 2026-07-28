# m_tools — contributing

## Prerequisites

- macOS **13.0** (Ventura) or later
- **Xcode Command Line Tools** (`xcode-select --install`) — full Xcode not needed

## Build & run

```sh
./build.sh                       # → build/m_tools.app + m_tools.dmg (repo root)
./build.sh --pkg                 # also → m_tools-<version>.pkg (for MDM deployment)
open build/m_tools.app    # menu-bar app
```

`build.sh` compiles `Sources/**/*.swift` with `swiftc`, assembles the bundle, draws the icon, signs, and packages
the DMG. No Xcode project, no SPM, no `Package.swift` — one script is the whole build system.

- **Faster development loop**
  - `./build.sh --run` — rebuild, quit, and relaunch in place (skips the DMG).
  - **If a future tool needs a permission grant** (e.g. a global hotkey for the command
    palette needing Accessibility access): ad-hoc signing resets any such grant every
    build. Create a self-signed **Code Signing** cert named **`m_tools-dev`** in Keychain
    Access (*Self Signed Root*); `./build.sh --run` then signs with it automatically. It's
    local and per-developer, separate from the shared release identity (see *Releasing*).
    Not needed today since this tool requests no sensitive permissions, but costs nothing
    to set up now and avoids a surprise later.

## Tests

```sh
./tests/run.sh
```

Plain assert-based smoke tests over the pure-logic types — no XCTest (there's no Xcode
project to host a test target). `tests/run.sh` holds the list of files the test binary
compiles against, because the test file and `Sources/main.swift` both have top-level code
and Swift allows only one such file per module, so the target can't just be "all of
`Sources/`". Add pure-logic files to that list; view files don't belong there.

## First-time repo setup

Only needed once, when the repo is created — see the checklist in `docs/repo-setup.md`.

## Releasing

CI does the work: push a version tag and a signed `m_tools.dmg` is published to a
GitHub Release (`.github/workflows/release.yml`). Every release is signed with one shared
identity, **`m_tools-release`**, so if this app ever does request a permission grant, users
keep it across updates — the grant is tied to the signing cert, not the app name/path.

### One-time setup (admin, once)

1. **Create the cert** — Keychain Access → *Certificate Assistant → Create a Certificate* → a
   **Code Signing** cert (*Self Signed Root*) named exactly **`m_tools-release`**.
2. **Export it** — right-click the cert → *Export* → `m_tools-release.p12`, and set a password.
3. **Add two GitHub secrets** — repo → **Settings → Secrets and variables → Actions → New
   repository secret**:
   - `RELEASE_CERT_P12_BASE64` — run `base64 -i m_tools-release.p12 | pbcopy`, then paste.
   - `RELEASE_CERT_PASSWORD` — the password from step 2.
4. **Pin it** — set `RELEASE_CERT_SHA` in `build.sh` to the cert's SHA-1 (from
   `security find-identity -p codesigning`), so a build signed by any other cert hard-fails
   instead of shipping. Left blank by default until you've done step 1–3.

### Cut a release (anyone)

1. Bump `VERSION` in `build.sh` and commit.
2. Tag (no `v` prefix, equal to `VERSION`) and push:
   `git tag 0.1.0 && git push origin 0.1.0`.

CI checks the tag matches `VERSION`, signs the build, and publishes the release with **both**
a `.dmg` (manual install) and a `.pkg` (MDM deployment). The repo's releases (and issues, for
bug reports) should be readable by everyone on the team — keep the repo internal-org-accessible.

### Managed Macs

On MDM-managed fleets the `.pkg` is the path that matters: an MDM installs it as root, which
avoids both the admin prompt (writing to `/Applications` needs admin) and the Gatekeeper
"unidentified developer" prompt (Gatekeeper only checks files carrying a download quarantine
flag, and MDM-installed files don't). No notarization or paid Developer ID needed for that
path — see `docs/deployment.md`.

## Conventions

- **No external dependencies** — system frameworks only (Foundation, AppKit, SwiftUI,
  CoreImage, Security, WebKit, CryptoKit). No SPM, no `Package.swift`.
- **All styling via `Theme.swift`** — no hardcoded colors or fonts elsewhere.
- **Icons drawn in code** (SF Symbols or CoreGraphics) — no image assets.
- **Tool logic stays pure** — each tool's transformation lives in a side-effect-free
  function/type separate from its View, so it's testable without touching SwiftUI.
- **Comments explain *why*, not *what*** — prefer one `///` doc comment over scattered
  inline notes.
- Write original code; match the surrounding Swift.

## Adding a new tool

1. Create `Sources/Tools/<ToolName>.swift`.
2. Implement the pure logic function(s) first — no SwiftUI imports needed in this part.
3. Build the view using the shared `ToolView` two-pane layout.
4. Register the tool in `ToolRegistry.swift` (name, category, keywords for search/smart-detect).
5. Add a case to `Detection.swift` if the tool should be clipboard-auto-detected.
6. Add a smoke-test entry in `tests/main.swift`.

## Testing

No formal test framework (no Xcode project to host an XCTest target) — a small standalone
`tests/main.swift` asserts against each tool's pure logic functions, compiled and run
directly by `./tests/run.sh`, plus manual
smoke-testing after a build. Cover what your change touches, plus a baseline pass:

- **Sidebar & search** — filtering and category grouping work.
- **Command palette** (`⌘K`) — fuzzy search finds tools by name and keyword.
- **Smart detect** — paste a JSON blob / JWT / Base64 string / Unix timestamp into the
  menu-bar quick-paste and confirm the right tool is suggested.
- **Each tool touched** — input → transform → output round-trips correctly; error states
  show for invalid input instead of crashing.
- **Copy/clear buttons** work in both panes.
- **Light/dark appearance** — check contrast in both.

## Reporting issues

Open an issue with your macOS version, the tool involved, steps to reproduce, and expected
vs. actual result.

## Pull requests

1. Branch off `main` (or `trunk`, pick one convention and stick to it).
2. Run `./build.sh` — confirm it builds and launches.
3. Smoke-test the areas you touched.
4. Update `README.md` when behavior, tools, or shortcuts change.
5. Open a focused PR with imperative commits and a clear what / why / how-tested.
