# Mesoneer Design System — Extracted Reference

Source: `Mesoneer_Console__standalone_.html` (Claude Design `.dc.html` export). This doc captures
the design tokens and component patterns so they can be applied consistently across mesoneer's
internal tools (m_capture, m_tools, and future ones) — not a port of the specific KYC
screen content in the export, just its visual language.

---

## 1. Typography

- **Primary typeface:** Manrope (400/500/600/700/800) — not a macOS system font, needs bundling.
- **Icon font:** Phosphor (regular / bold / fill weights) — web-only; mapped to SF Symbols below
  for native use, per the "icons drawn in code, no image assets" convention.
- Fallback stack used in the source: `Manrope, system-ui, -apple-system, sans-serif`.

### Native mapping
Bundle Manrope's `.ttf` files as resources (`Resources/Fonts/`), register at launch with
`CTFontManagerRegisterFontsForURL`. This is a resource, not a code dependency — consistent with
"no external dependencies, system frameworks only" (CoreText is a system framework).
Fallback to `.system` font if registration fails for any reason.

---

## 2. Color Tokens

| Token | Light | Dark | Notes |
|---|---|---|---|
| `bg` | `#F5F5F9` | `#0D0C13` | app background |
| `surface` | `#FFFFFF` | `#17151F` | cards, header, panels |
| `surface2` | `#F0F0F5` | `#211E2C` | inputs, hover states, secondary chips |
| `border` | `#E7E7EF` | `#2A2837` | 1px hairlines |
| `text` | `#15131E` | `#F3F2F9` | primary text |
| `muted` | `#6D6B7E` | `#9794A8` | secondary text, labels |
| `primary` | `#3B2A78` (base) | lightened 30% | brand purple, buttons, active states |
| `primaryBright` | lightened 34% from base | lightened 46% from base | active nav highlight |
| `primary100` | `rgba(primary, 0.10)` | `rgba(primaryBright, 0.16)` | tinted backgrounds (stat icon bg, active tab count bg) |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | text/icons on primary-filled surfaces |
| `navBg` | `#141220` (fixed, doesn't flip with theme) | `#08070C` | sidebar background |
| `navText` | `#B7B5C6` | `#8B8899` | sidebar inactive item text |
| `navHover` | `rgba(255,255,255,.06)` | same | sidebar hover/divider |
| `shadow` | `rgba(20,18,30,.06)` | `rgba(0,0,0,.45)` | card elevation |

**Status colors** (used for risk/health indicators, deltas, badges):
- Success / low-risk: `#12A150`
- Warning / medium-risk: `#B4820A`
- Danger / high-risk: `#E5484D`

**Accent palette** (used for avatar/identity colors, cycled by hash): `#6A4FD0, #12A150, #B4820A, #2A7DE1, #E5484D, #0E9AA5`

---

## 3. Spacing & Shape

- Sidebar width: `250px` fixed
- Header height: `66px`
- Border radius: `9px` (buttons, inputs, small cards), `14px` (larger cards), pill/`20px` (badges, chips)
- Card padding: `16–18px` horizontal, `15–16px` vertical
- Row vertical padding: `14px` default, `9px` "compact density" mode — an existing density toggle worth carrying over as a user preference
- Card shadow: `0 1px 2px var(--shadow)` — subtle, not heavy elevation

---

## 4. Component Patterns (translate, don't copy verbatim)

- **Fixed dark sidebar** — wordmark + small accent square logo mark, nav items with icon + label
  + optional pill badge count, active state = bright-primary background + white text + bold weight
- **Header bar** — left: eyebrow label (uppercase, small, muted) + bold title; center: search field
  with leading icon; right: icon buttons (theme toggle, notifications with dot indicator) + a
  primary filled CTA button
- **Stat cards** — 4-column grid, label + tinted icon badge top row, large value + colored delta
  (icon + text) bottom row
- **Segmented tabs with counts** — underline-style active state, pill count badge tinted when active
- **Filter chips** — pill-shaped, filled when active (primary bg + white text), outlined when inactive
- **Data rows** — avatar/initials badge (colored per identity hash) + primary/secondary text +
  status pill (tinted background matching status color) + trailing meta
- **Checklist items** — custom checkbox (filled square when checked) + title/subtitle + status label
- **Toggle switch** — track fills with primary color when on, knob slides from 2px to 20px

---

## 5. Icon Mapping (Phosphor → SF Symbols)

Only the icons actually used in the source, mapped to native equivalents:

| Phosphor | SF Symbol |
|---|---|
| `ph-squares-four` | `square.grid.2x2` |
| `ph-identification-card` | `person.text.rectangle` |
| `ph-fingerprint` | `touchid` |
| `ph-pen-nib` | `signature` |
| `ph-folders` | `folder.fill` / `folder` |
| `ph-chart-bar` | `chart.bar` |
| `ph-gear` | `gearshape` |
| `ph-caret-up-down` | `chevron.up.chevron.down` |
| `ph-magnifying-glass` | `magnifyingglass` |
| `ph-bell` | `bell` |
| `ph-plus` | `plus` |
| `ph-sun` / `ph-moon` | `sun.max` / `moon` |
| `ph-hourglass-medium` | `hourglass` |
| `ph-timer` | `timer` |
| `ph-shield-check` | `checkmark.shield` |
| `ph-trend-up` / `ph-trend-down` | `arrow.up.right` / `arrow.down.right` |
| `ph-device-mobile` | `iphone` |
| `ph-identification-badge` | `person.badge.shield.checkmark` |
| `ph-browser` | `safari` / `globe` |
| `ph-x` (implied close) | `xmark` |

For any future icon not in this table: pick the closest SF Symbol first; only reach for a custom
CoreGraphics-drawn glyph if nothing in SF Symbols fits — keeps zero image assets.

---

## 6. Applying This to m_tools

The KYC-specific content (verification queue, risk chips, compliance checklist) doesn't carry
over — what carries over is the visual system:

- Sidebar becomes the tool-category nav (registry-driven), same fixed-dark treatment, same
  active-state highlight (bright-primary bg, bold white label), same badge-count pattern (could
  show e.g. "New" badges on recently-added tools instead of case counts).
- Header becomes: eyebrow "Category" + bold tool name, center search = the same command-palette
  search field styled identically, right side keeps the theme toggle in the same spot.
- Stat cards pattern isn't very relevant to a dev-tool grid, but the **tab + count** and
  **filter chip** patterns are perfect for the tool list itself (tabs = categories, chips =
  quick filters like "recently used").
- Two-pane tool view (input/output) adopts `surface`/`surface2`/`border` tokens directly —
  input pane = `surface2` background, output = `surface`, both with `border` hairline and `9px`
  radius, matching the existing card language.
