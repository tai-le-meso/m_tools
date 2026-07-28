import Foundation

/// Single source of truth for the app's identity at runtime.
///
/// The version is read from the bundle rather than hardcoded in Swift, so `VERSION` in
/// `build.sh` stays the only place it's defined — that's the value the release workflow
/// checks the git tag against, so duplicating it here would just create a second thing to
/// forget to bump.
enum AppInfo {
    static let name = "m_tools"

    /// `CFBundleShortVersionString` — the human-facing "0.1.0". Falls back to "dev" when
    /// there's no Info.plist to read, which happens if the binary is run directly rather
    /// than from the built .app bundle.
    static var version: String {
        guard let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              !value.isEmpty
        else { return "dev" }
        return value
    }

    /// "v0.1.0" — the form shown in the UI.
    static var displayVersion: String { "v\(version)" }

    /// "m_tools 0.1.0" — for the menu bar's informational header.
    static var nameAndVersion: String { "\(name) \(version)" }
}
