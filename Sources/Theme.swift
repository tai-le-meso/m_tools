import SwiftUI
import CoreText

// All styling lives here — no hardcoded colors or fonts anywhere else in Sources/.
// Tokens ported from Mesoneer_Console__standalone_.html's theme() function.

// MARK: - Font registration (Manrope bundled as a resource, not a dependency)

enum ManropeFonts {
    /// Call once at app launch (e.g. from AppDelegate.applicationDidFinishLaunching).
    /// Registers the bundled Manrope .ttf files via CoreText. If registration fails for
    /// any reason, `Theme.font` falls back to the system font automatically.
    static func registerIfNeeded() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let fontsDir = resourceURL.appendingPathComponent("Fonts", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: fontsDir, includingPropertiesForKeys: nil
        ) else { return }

        for url in files where url.pathExtension.lowercased() == "ttf" {
            var errorRef: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
            // Ignore "already registered" errors from repeated --run rebuilds; anything
            // else just means we silently fall back to the system font below.
        }
    }
}

// MARK: - Theme

/// Central design-token source. All values below mirror the extracted `--m-*` CSS custom
/// properties. Light/dark variants are picked via `Theme.current(for:)`, driven by
/// `@Environment(\.colorScheme)` in views — except `navBackground`/`navText`, which are
/// intentionally fixed-dark regardless of app theme, matching the source design.
struct Theme {
    let bg: Color
    let surface: Color
    let surface2: Color
    let border: Color
    let text: Color
    let muted: Color
    let primary: Color
    let primaryBright: Color
    let primary100: Color
    let onPrimary: Color
    let shadow: Color
    let syntax: SyntaxColors

    /// Color-per-token-role for the output pane's syntax highlighting (JSON/HTML/XML/CSS/
    /// YAML) — a separate nested set rather than more top-level `Theme` fields, since these
    /// only ever apply to `SyntaxToken.role` and nothing else. Picked for legibility in both
    /// modes (roughly GitHub's light/dark syntax palettes) rather than reusing `success`/
    /// `warning`/`danger`, which would visually read as status/error coloring instead.
    struct SyntaxColors {
        let key: Color
        let string: Color
        let number: Color
        let keyword: Color
        let comment: Color
        let tag: Color
        let attribute: Color
    }

    // Fixed regardless of color scheme — the sidebar never flips to light.
    static let navBackground = Color(hex: 0x141220)
    static let navBackgroundDark = Color(hex: 0x08070C) // used when app is in dark mode
    static let navText = Color(hex: 0xB7B5C6)
    static let navTextDark = Color(hex: 0x8B8899)
    static let navHover = Color.white.opacity(0.06)

    // Status colors — same in both modes.
    static let success = Color(hex: 0x12A150)
    static let warning = Color(hex: 0xB4820A)
    static let danger = Color(hex: 0xE5484D)

    /// The amber cursor block from the app icon (direction "1b — Brand solid"), reused as
    /// the accent on the `m_tools` wordmark so the sidebar lockup and the icon read as one
    /// mark. Fixed in both modes, like the nav colors — it always sits on the dark sidebar.
    static let brandAccent = Color(hex: 0xFFB020)

    // Brand base purple, before per-mode lighten adjustments.
    private static let primaryBase = Color(hex: 0x3B2A78)

    static let light = Theme(
        bg: Color(hex: 0xF5F5F9),
        surface: Color(hex: 0xFFFFFF),
        surface2: Color(hex: 0xF0F0F5),
        border: Color(hex: 0xE7E7EF),
        text: Color(hex: 0x15131E),
        muted: Color(hex: 0x6D6B7E),
        primary: primaryBase,
        primaryBright: primaryBase.lightened(by: 0.34),
        primary100: primaryBase.opacity(0.10),
        onPrimary: .white,
        shadow: Color(hex: 0x14121E).opacity(0.06),
        syntax: SyntaxColors(
            key: Color(hex: 0x0550AE),
            string: Color(hex: 0x116329),
            number: Color(hex: 0xB35900),
            keyword: Color(hex: 0x8250DF),
            comment: Color(hex: 0x6E7781),
            tag: Color(hex: 0xB31D28),
            attribute: Color(hex: 0x6639BA)
        )
    )

    static let dark = Theme(
        bg: Color(hex: 0x0D0C13),
        surface: Color(hex: 0x17151F),
        surface2: Color(hex: 0x211E2C),
        border: Color(hex: 0x2A2837),
        text: Color(hex: 0xF3F2F9),
        muted: Color(hex: 0x9794A8),
        primary: primaryBase.lightened(by: 0.30),
        primaryBright: primaryBase.lightened(by: 0.46),
        primary100: primaryBase.lightened(by: 0.46).opacity(0.16),
        onPrimary: .white,
        shadow: Color.black.opacity(0.45),
        syntax: SyntaxColors(
            key: Color(hex: 0x79C0FF),
            string: Color(hex: 0x7EE787),
            number: Color(hex: 0xFFA657),
            keyword: Color(hex: 0xD2A8FF),
            comment: Color(hex: 0x8B949E),
            tag: Color(hex: 0xFF7B72),
            attribute: Color(hex: 0xB392F0)
        )
    )

    static func current(for scheme: ColorScheme) -> Theme {
        scheme == .dark ? .dark : .light
    }

    // Nav colors also depend on app-level (not system) color scheme, since it's fixed-dark.
    static func navBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? navBackgroundDark : navBackground
    }
    static func navText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? navTextDark : navText
    }
}

// MARK: - Typography

enum ThemeFont {
    static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Custom("Manrope", ...) silently falls back to the system font if the family
        // isn't registered (e.g. registration failed) — no crash, just a visual fallback.
        .custom("Manrope", size: size).weight(weight)
    }

    static let title = manrope(18, weight: .bold)          // header title
    static let eyebrow = manrope(11, weight: .semibold)    // uppercase small labels
    static let body = manrope(14, weight: .regular)
    static let bodyMedium = manrope(14, weight: .medium)
    static let statValue = manrope(26, weight: .heavy)     // stat card big number
    static let sidebarLabel = manrope(14, weight: .medium)
    static let sidebarLabelActive = manrope(14, weight: .bold)
    static let badge = manrope(11, weight: .bold)
}

// MARK: - Shape constants

enum ThemeMetrics {
    static let sidebarWidth: CGFloat = 250
    static let headerHeight: CGFloat = 66
    static let radiusSmall: CGFloat = 9   // buttons, inputs, small cards
    static let radiusLarge: CGFloat = 14  // stat cards, panels
    static let radiusPill: CGFloat = 20   // badges, chips
    static let rowPaddingComfortable: CGFloat = 14
    static let rowPaddingCompact: CGFloat = 9
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Mixes toward white by `amount` (0...1) — mirrors the source's `lighten()` helper,
    /// used for the dark-mode primary variants which are computed, not hardcoded.
    func lightened(by amount: Double) -> Color {
        let ui = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = CGFloat(amount)
        return Color(
            .sRGB,
            red: Double(r + (1 - r) * t),
            green: Double(g + (1 - g) * t),
            blue: Double(b + (1 - b) * t),
            opacity: Double(a)
        )
    }
}

// MARK: - Reusable card/shadow modifier

struct ThemedCard: ViewModifier {
    let theme: Theme
    var radius: CGFloat = ThemeMetrics.radiusLarge

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .shadow(color: theme.shadow, radius: 2, x: 0, y: 1)
    }
}

extension View {
    func themedCard(_ theme: Theme, radius: CGFloat = ThemeMetrics.radiusLarge) -> some View {
        modifier(ThemedCard(theme: theme, radius: radius))
    }
}
