import AppKit

/// Executes a quick action: read the clipboard, transform it, optionally write the result
/// back, and open the app at the matching tool.
///
/// Split out of `MenuBarController` because this is the part worth reasoning about on its
/// own — the menu is just one possible trigger (a global hotkey would be another), and none
/// of this needs to know anything about `NSMenu`.
enum QuickActionRunner {
    enum Outcome {
        case success(String)
        /// The clipboard held nothing usable — not an error worth a dialog, just nothing to do.
        case emptyClipboard
        /// The transform threw; the message is the tool's own, e.g. "Invalid JSON: ...".
        case failed(String)

        /// Short confirmation for the menu bar. Deliberately terse: this is glanced at, not read.
        var statusText: String {
            switch self {
            case .success: return "Copied"
            case .emptyClipboard: return "Clipboard empty"
            case .failed: return "Couldn't convert"
            }
        }
    }

    @discardableResult
    static func run(_ action: QuickAction, activate: @escaping () -> Void) -> Outcome {
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        guard !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Still open the tool. Someone who copied nothing probably wants to paste
            // something in by hand, and an empty window beats a menu that appears to do
            // nothing at all.
            AppState.shared.navigate(toToolID: action.toolId, modeIndex: action.modeIndex)
            activate()
            return .emptyClipboard
        }

        let outcome: Outcome
        var result: String?
        do {
            let output = try action.run(clipboard)
            result = output
            outcome = .success(output)
        } catch {
            outcome = .failed(error.localizedDescription)
        }

        // The input goes to the tool either way. On failure that's the point — the tool
        // shows the same error inline, next to the text that caused it, where it can be
        // fixed. Swallowing the input would leave the user to paste it again themselves.
        AppState.shared.navigate(
            toToolID: action.toolId,
            input: clipboard,
            modeIndex: action.modeIndex
        )
        activate()

        if let result, QuickActionSettings.copyResultToClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
        }

        return outcome
    }
}
