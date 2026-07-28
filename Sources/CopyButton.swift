import SwiftUI
import AppKit

/// Copies `textToCopy` to the pasteboard. Also bound to ⌘C as a "smart copy" — this fires
/// when no text selection is active elsewhere in the window (a focused text field's own
/// native ⌘C for a selection always takes priority, which is the expected split).
struct CopyButton: View {
    let textToCopy: String
    let theme: Theme
    var onCopy: (() -> Void)?
    @State private var justCopied = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 4) {
                Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                Text(justCopied ? "Copied" : "Copy")
            }
            .font(ThemeFont.manrope(11, weight: .medium))
            .foregroundColor(justCopied ? Theme.success : theme.muted)
        }
        .buttonStyle(.plain)
        .disabled(textToCopy.isEmpty)
        .keyboardShortcut("c", modifiers: .command)
        .scaleEffect(justCopied ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: justCopied)
    }

    private func copy() {
        guard !textToCopy.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
        justCopied = true
        onCopy?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
    }
}

/// Pastes clipboard text into `target`, replacing its contents. Also bound to ⌘V as a
/// "smart paste" — same focus-priority split as `CopyButton`'s ⌘C: a focused text field
/// handles its own native ⌘V (insert at cursor) first; this fires as the window-level
/// fallback otherwise.
struct PasteButton: View {
    @Binding var target: String
    let theme: Theme
    var onPaste: (() -> Void)?
    @State private var justPasted = false

    private var clipboardHasText: Bool {
        !(NSPasteboard.general.string(forType: .string)?.isEmpty ?? true)
    }

    var body: some View {
        Button(action: paste) {
            HStack(spacing: 4) {
                Image(systemName: justPasted ? "checkmark" : "doc.on.clipboard")
                Text(justPasted ? "Pasted" : "Paste")
            }
            .font(ThemeFont.manrope(11, weight: .medium))
            .foregroundColor(justPasted ? Theme.success : theme.muted)
        }
        .buttonStyle(.plain)
        .disabled(!clipboardHasText)
        .keyboardShortcut("v", modifiers: .command)
        .scaleEffect(justPasted ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: justPasted)
    }

    private func paste() {
        guard let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty else { return }
        target = clipboard
        justPasted = true
        onPaste?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justPasted = false }
    }
}
