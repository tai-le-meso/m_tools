import Foundation

/// User's Quick Actions configuration, persisted in `UserDefaults` (Foundation — no
/// dependency, and the right size of storage for a handful of preferences).
///
/// Reads fall back to the shipped defaults, so a fresh install and a corrupted/absent value
/// behave identically: the user sees a sensible menu rather than an empty one.
enum QuickActionSettings {
    private static let enabledKey = "quickActions.enabledIDs"
    private static let copyResultKey = "quickActions.copyResultToClipboard"

    private static var defaults: UserDefaults { .standard }

    /// Enabled action ids, in the order they appear in the menu.
    ///
    /// Ids that no longer exist in the catalog are filtered out on read rather than on
    /// write, so removing an action from a future build can't strand a user with a menu
    /// entry that does nothing.
    static var enabledIDs: [String] {
        get {
            guard let saved = defaults.array(forKey: enabledKey) as? [String] else {
                return QuickActionCatalog.defaultIDs
            }
            let known = saved.filter { QuickActionCatalog.action(withID: $0) != nil }
            // An empty saved list is a legitimate choice (user turned everything off), so
            // only fall back when nothing was ever saved — handled by the guard above.
            return known
        }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// Whether running a quick action also puts its result on the clipboard.
    ///
    /// Defaults to `true`: the feature exists so you can copy something, transform it, and
    /// paste it back somewhere else. `object(forKey:)` is checked first because
    /// `bool(forKey:)` returns `false` for a missing key, which would silently invert the
    /// intended default.
    static var copyResultToClipboard: Bool {
        get {
            guard defaults.object(forKey: copyResultKey) != nil else { return true }
            return defaults.bool(forKey: copyResultKey)
        }
        set { defaults.set(newValue, forKey: copyResultKey) }
    }

    static var enabledActions: [QuickAction] {
        QuickActionCatalog.actions(for: enabledIDs)
    }

    static func isEnabled(_ id: String) -> Bool {
        enabledIDs.contains(id)
    }

    /// Appends when enabling (so newly-added actions land at the end of the menu rather
    /// than jumping to a position the user didn't choose) and removes when disabling.
    static func setEnabled(_ id: String, _ enabled: Bool) {
        var ids = enabledIDs
        if enabled {
            guard !ids.contains(id) else { return }
            ids.append(id)
        } else {
            ids.removeAll { $0 == id }
        }
        enabledIDs = ids
    }

    /// Moves an enabled action one step up or down the menu order. No-ops at the ends.
    static func move(_ id: String, by offset: Int) {
        var ids = enabledIDs
        guard let from = ids.firstIndex(of: id) else { return }
        let to = from + offset
        guard ids.indices.contains(to) else { return }
        ids.swapAt(from, to)
        enabledIDs = ids
    }

    static func restoreDefaults() {
        enabledIDs = QuickActionCatalog.defaultIDs
        copyResultToClipboard = true
    }
}
