import SwiftUI
import AppKit

/// Reusable two-pane layout: input on the left, output on the right, shared by every tool.
/// A tool can offer one transform (e.g. Base64) or several named "modes" that operate on
/// the same input (e.g. CSS Beautify vs Minify) — either way this view owns no tool-specific
/// logic, just the layout, mode switch, and copy/paste/animation chrome.
struct ToolView: View {
    struct Mode {
        let label: String
        let transform: (String) throws -> String
        /// Overrides the view-level `language` for just this mode — needed by tools like
        /// JSON ⇄ CSV where each mode's *output* is a different language (CSV has no
        /// highlighter here, so that mode's `language` stays `nil` → falls back to `.none`).
        let language: SyntaxLanguage?

        init(_ label: String, language: SyntaxLanguage? = nil, _ transform: @escaping (String) throws -> String) {
            self.label = label
            self.language = language
            self.transform = transform
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    /// Watched so a quick action can hand this view the clipboard text and, for multi-mode
    /// tools, the mode that action corresponds to.
    @ObservedObject private var appState = AppState.shared
    let title: String
    let modes: [Mode]
    /// Which syntax-highlighting rules to apply to the *output* pane — `.none` (the
    /// default) means plain themed text, same as every tool had before this existed.
    let language: SyntaxLanguage

    @State private var input: String = ""
    @State private var output: String = ""
    @State private var errorMessage: String?
    @State private var selectedMode = 0

    // Brief highlight pulses so a ⌘C/⌘V (or button tap) visibly lands on the pane it
    // touched, not just the button's own "Copied"/"Pasted" label swap.
    @State private var inputFlash = false
    @State private var outputFlash = false

    /// Which pane (if any) is currently blown up to near-fullscreen — real JSON/HTML/YAML
    /// payloads are routinely hundreds of lines, and the normal half-width pane is too
    /// cramped to comfortably read or edit that; this is the "let me actually see it" escape
    /// hatch. `Identifiable` (needs `Hashable` too, since `id: Self` makes the whole enum the
    /// ID) so it can drive `.sheet(item:)` directly.
    private enum ExpandedPane: Identifiable, Hashable {
        case input, output
        var id: Self { self }
    }
    @State private var expandedPane: ExpandedPane?

    /// Raw formatted text vs. a collapsible node tree.
    private enum OutputRendering { case text, tree }
    @State private var outputRendering: OutputRendering = .text

    // Everything below is a cache, and all of it is rebuilt only in `refreshOutputViews()`.
    // These used to be computed properties, which meant SwiftUI re-tokenized (and re-parsed)
    // the entire document on *every* re-render — including ones triggered by unrelated state
    // like the copy/paste flash animation. That was the main source of the lag.

    /// Only ever built while the tree is actually on screen: parsing a large document into
    /// nodes is wasted work if the user is looking at the text view.
    @State private var outputTree: TreeNode?
    /// Incremented whenever `outputTree` is replaced, so `TreeOutlineView` knows to rebuild
    /// its row cache without needing to deep-compare two trees.
    @State private var treeVersion = 0
    @State private var highlightedOutput = NSAttributedString()

    private var theme: Theme { Theme.current(for: colorScheme) }

    /// Single-transform tools (most of them) — e.g. `ToolView(title: "Base64", transform: Base64Logic.run)`.
    init(title: String, language: SyntaxLanguage = .none, transform: @escaping (String) throws -> String) {
        self.title = title
        self.language = language
        self.modes = [Mode(title, transform)]
    }

    /// Multi-mode tools — e.g. CSS Beautify/Minify sharing one input, switched via pill toggle.
    init(title: String, language: SyntaxLanguage = .none, modes: [Mode]) {
        self.title = title
        self.language = language
        self.modes = modes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(ThemeFont.title)
                    .foregroundColor(theme.text)
                Text("⌘V paste · ⌘C copy")
                    .font(ThemeFont.manrope(11, weight: .medium))
                    .foregroundColor(theme.muted)
            }

            if modes.count > 1 {
                modeSwitcher
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ThemeFont.manrope(12, weight: .medium))
                    .foregroundColor(Theme.danger)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.danger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(alignment: .top, spacing: 14) {
                inputPane
                outputPane
            }
        }
        .padding(20)
        // Single-closure-arg onChange (not the two-arg macOS 14 variant) — target is macOS 13.
        .onChange(of: input) { newValue in runTransform(newValue) }
        .onChange(of: selectedMode) { _ in runTransform(input) }
        // Runs once up front so generator-style tools (UUID, Lorem Ipsum, ...) show
        // something immediately rather than waiting on a first keystroke.
        //
        // This also picks up anything a menu bar quick action left waiting. AppShellView
        // rebuilds the tool view per navigation (its `.id` includes a navigation token), so
        // this fires every time — including when the action targets the tool already shown.
        .onAppear {
            let pending = appState.consumePendingInput()
            if let modeIndex = pending.modeIndex, modes.indices.contains(modeIndex) {
                selectedMode = modeIndex
            }
            if let text = pending.input {
                // Assigning `input` triggers `.onChange` above, which runs the transform —
                // so no explicit run here, and no risk of running it twice.
                input = text
            } else {
                runTransform(input)
            }
        }
        // The highlighted output bakes in themed colors, so a light/dark flip has to
        // rebuild it — it's a cache now, not a computed property that would just re-run.
        .onChange(of: colorScheme) { _ in refreshOutputViews() }
        // ⌘A safety net: this app has no SwiftUI `App`/`Scene` lifecycle (see AppDelegate),
        // so it never gets the standard auto-generated Edit menu that normally supplies
        // "Select All" — without it, ⌘A has nothing to route to. Same trick already proven
        // by CopyButton/PasteButton's `.keyboardShortcut`: an invisible button registers the
        // shortcut at the SwiftUI level, and `sendAction(to: nil, ...)` forwards it through
        // the responder chain to whichever text view (input or output) is actually focused —
        // functionally identical to what a real Edit menu's Select All item would do.
        .background(
            Button("") { NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil) }
                .keyboardShortcut("a", modifiers: .command)
                .opacity(0)
        )
        .sheet(item: $expandedPane) { pane in
            expandedPaneView(pane)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                FilterChipView(
                    label: mode.label,
                    isActive: selectedMode == index,
                    theme: theme,
                    action: { selectedMode = index }
                )
            }
        }
    }

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Input")
                    .font(ThemeFont.eyebrow)
                    .foregroundColor(theme.muted)
                Spacer()
                expandButton(for: .input)
                PasteButton(target: $input, theme: theme, onPaste: { pulse($inputFlash) })
            }
            TextEditor(text: $input)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(theme.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall)
                        .stroke(inputFlash ? theme.primary : theme.border, lineWidth: inputFlash ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
                .scaleEffect(inputFlash ? 1.004 : 1.0)
                .animation(.easeOut(duration: 0.35), value: inputFlash)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Output")
                    .font(ThemeFont.eyebrow)
                    .foregroundColor(theme.muted)
                if supportsTreeView {
                    renderingToggle
                }
                Spacer()
                expandButton(for: .output)
                CopyButton(textToCopy: output, theme: theme, onCopy: { pulse($outputFlash) })
            }
            outputContent
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall)
                        .stroke(outputFlash ? Theme.success : theme.border, lineWidth: outputFlash ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
                .scaleEffect(outputFlash ? 1.004 : 1.0)
                .animation(.easeOut(duration: 0.35), value: outputFlash)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var outputContent: some View {
        if outputRendering == .tree, let tree = outputTree {
            // No `.id(...)` here on purpose: keeping one view instance is what preserves
            // which nodes the user collapsed as they keep editing the input. `version` is
            // how the outline knows the tree itself changed.
            TreeOutlineView(root: tree, version: treeVersion, theme: theme)
        } else {
            // `ReadOnlyTextView`, not `TextEditor(...).disabled(true)` — a disabled
            // TextEditor also blocks trackpad/scroll-wheel interaction on macOS, which is
            // exactly what made long beautified/minified output read as "cropped/hidden":
            // the content was all there, you just couldn't scroll to it.
            ReadOnlyTextView(attributedText: highlightedOutput)
                .padding(8)
        }
    }

    /// Compact Text/Tree switch — deliberately smaller than `FilterChipView` (used by the
    /// tool's own mode switcher) so it reads as a view option for one pane, not another
    /// transform mode.
    private var renderingToggle: some View {
        HStack(spacing: 0) {
            renderingOption("Text", value: .text)
            renderingOption("Tree", value: .tree)
        }
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
        .clipShape(Capsule())
    }

    private func renderingOption(_ label: String, value: OutputRendering) -> some View {
        let isActive = outputRendering == value
        return Button(action: {
            guard outputRendering != value else { return }
            outputRendering = value
            // Builds the representation being switched to (and releases the other one).
            refreshOutputViews()
        }) {
            Text(label)
                .font(ThemeFont.manrope(10, weight: .semibold))
                .foregroundColor(isActive ? theme.onPrimary : theme.muted)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(isActive ? theme.primary : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func runTransform(_ value: String) {
        guard modes.indices.contains(selectedMode) else { return }
        do {
            output = try modes[selectedMode].transform(value)
            withAnimation(.easeOut(duration: 0.18)) { errorMessage = nil }
        } catch {
            output = ""
            withAnimation(.easeOut(duration: 0.18)) { errorMessage = error.localizedDescription }
        }
        refreshOutputViews()
    }

    /// Rebuilds whichever output representation is actually on screen — and only that one.
    /// Called after a transform, on a mode/theme change, and when the Text/Tree toggle
    /// flips; never from `body`.
    private func refreshOutputViews() {
        switch outputRendering {
        case .text:
            // Dropping the tree frees the node graph for a document the user isn't viewing
            // as a tree; it's rebuilt on demand if they flip the toggle back.
            outputTree = nil
            highlightedOutput = buildHighlightedOutput()
        case .tree:
            // `try?`: a tree is a display convenience, so a document we can't parse into one
            // just falls back to the text view rather than surfacing an error.
            let tree = output.isEmpty ? nil : try? DataTree.build(output, language: effectiveLanguage)
            outputTree = tree
            treeVersion &+= 1
            // Skip tokenizing entirely when the tree is what's actually on screen — that's
            // the single most expensive step for a large document. Only the fallback path
            // (tree failed to parse, so `outputContent` shows text) needs it.
            highlightedOutput = tree == nil ? buildHighlightedOutput() : NSAttributedString()
        }
    }

    /// Cheap, parse-free check for whether the Text/Tree toggle should even be offered —
    /// deciding this by actually attempting a parse would reintroduce per-render parsing.
    private var supportsTreeView: Bool {
        guard !output.isEmpty else { return false }
        switch effectiveLanguage {
        case .json, .yaml, .xml: return true
        case .none, .html, .css: return false
        }
    }

    /// Briefly turns a pane's border/scale highlight on, then off — the visual "this is
    /// what just changed" cue for a copy or paste action.
    private func pulse(_ flag: Binding<Bool>) {
        flag.wrappedValue = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { flag.wrappedValue = false }
    }

    /// The mode currently selected can override the view-level `language` (see `Mode`'s
    /// doc comment) — falls back to `language` when the mode doesn't specify one.
    private var effectiveLanguage: SyntaxLanguage {
        guard modes.indices.contains(selectedMode) else { return language }
        return modes[selectedMode].language ?? language
    }

    /// Colors `output` per `effectiveLanguage`'s tokens on top of the theme's base text
    /// color — `SyntaxHighlighter` (pure Foundation, in `Sources/Core/`) does the
    /// tokenizing; this is just the AppKit-side "role -> themed NSColor" mapping, kept here
    /// rather than in that file since `Theme`/`NSColor` are both off-limits for a
    /// `Sources/Core/*` parser (same pure-logic/view split as every `DevToolLogic` tool).
    ///
    /// A function, not a computed property, so it can't accidentally be called from `body`
    /// again — the result is cached in `highlightedOutput`.
    private func buildHighlightedOutput() -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let attributed = NSMutableAttributedString(
            string: output,
            attributes: [.font: font, .foregroundColor: NSColor(theme.text)]
        )
        let language = effectiveLanguage
        guard language != .none, !output.isEmpty else { return attributed }

        let syntax = theme.syntax
        // NSColor conversion is surprisingly costly, so each role is converted once here
        // rather than once per token — a big document has tens of thousands of tokens.
        let colorsByRole: [SyntaxTokenRole: NSColor] = [
            .key: NSColor(syntax.key),
            .string: NSColor(syntax.string),
            .number: NSColor(syntax.number),
            .keyword: NSColor(syntax.keyword),
            .comment: NSColor(syntax.comment),
            .tag: NSColor(syntax.tag),
            .attribute: NSColor(syntax.attribute),
            .punctuation: NSColor(theme.muted),
        ]

        // One batched edit rather than N separate attribute writes, each of which would
        // otherwise notify the layout manager independently.
        attributed.beginEditing()
        for token in SyntaxHighlighter.tokenize(output, language: language) {
            guard let color = colorsByRole[token.role] else { continue }
            attributed.addAttribute(.foregroundColor, value: color, range: NSRange(token.range, in: output))
        }
        attributed.endEditing()
        return attributed
    }

    // MARK: Expand-to-fullscreen

    private func expandButton(for pane: ExpandedPane) -> some View {
        Button(action: { expandedPane = pane }) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.muted)
        }
        .buttonStyle(.plain)
        .help("Expand to fill the screen")
    }

    /// A near-fullscreen sheet showing just one pane — real HTML/JSON/YAML payloads are
    /// routinely hundreds of lines, and the normal half-width split pane is too cramped to
    /// comfortably read or edit that; this is the "let me actually see it" escape hatch.
    /// Sized off `NSScreen.main` (not a fixed constant) so it scales to whatever laptop/
    /// display the app is actually running on, capped just short of the full screen so the
    /// dialog's own edges/chrome stay visible rather than looking like a broken fullscreen.
    private func expandedPaneView(_ pane: ExpandedPane) -> some View {
        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(pane == .input ? "Input" : "Output")
                    .font(ThemeFont.title)
                    .foregroundColor(theme.text)
                if modes.count > 1 {
                    modeSwitcher
                }
                if pane == .output, supportsTreeView {
                    renderingToggle
                }
                Spacer()
                if pane == .input {
                    PasteButton(target: $input, theme: theme, onPaste: { pulse($inputFlash) })
                } else {
                    CopyButton(textToCopy: output, theme: theme, onCopy: { pulse($outputFlash) })
                }
                Button("Done") { expandedPane = nil }
                    .buttonStyle(.plain)
                    .font(ThemeFont.bodyMedium)
                    .foregroundColor(theme.muted)
                    .keyboardShortcut(.cancelAction)
                    .padding(.leading, 8)
            }

            Group {
                if pane == .input {
                    TextEditor(text: $input)
                        .font(.system(size: 14, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(theme.surface2)
                } else {
                    outputContent.background(theme.surface)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .frame(width: screenSize.width * 0.94, height: screenSize.height * 0.9)
        .background(theme.bg)
    }
}

/// A scrollable, read-only text view for every tool's output pane — every Format/Convert
/// tool (JSON Formatter, CSS/HTML/XML Beautify+Minify, and the rest) renders its result
/// through this, so long minified/beautified output (a whole minified stylesheet is often
/// one giant unbroken line) reliably wraps and scrolls instead of getting cropped.
///
/// Deliberately *not* `TextEditor(text: .constant(...)).disabled(true)`: disabling a
/// `TextEditor` also blocks its underlying scroll view from responding to trackpad/scroll-
/// wheel input on macOS, which is exactly what made long output read as truncated — the
/// text was all there, there was just no way to scroll down to see the rest of it. Wrapping
/// `NSTextView` directly (`isEditable = false`, `isSelectable = true`) keeps scrolling and
/// text selection/copy fully working while still being non-editable, which is the standard
/// native way to show read-only text on macOS.
struct ReadOnlyTextView: NSViewRepresentable {
    let attributedText: NSAttributedString

    /// Remembers the exact instance last pushed into the text view. `updateNSView` runs on
    /// every re-render, and the previous `isEqual(to:)` check compared the two attributed
    /// strings character-by-character — O(document) work on each pass. Since the caller now
    /// caches one stable instance per output, an identity check is enough and is O(1).
    final class Coordinator {
        var appliedText: NSAttributedString?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        // `isRichText = true` (not `false`) is required here even though the view is
        // read-only: `false` puts NSTextView in "plain text" mode, which normalizes
        // every character to one uniform `typingAttributes` and silently drops the
        // per-token colors `highlightedOutput` just assigned.
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(attributedText)
        context.coordinator.appliedText = attributedText

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Guard the write: resetting the whole text storage unconditionally would reset
        // scroll position and text selection on every SwiftUI re-render, even when the
        // content hasn't actually changed. `===` (identity), not `isEqual(to:)` — see
        // Coordinator.
        guard context.coordinator.appliedText !== attributedText else { return }
        textView.textStorage?.setAttributedString(attributedText)
        context.coordinator.appliedText = attributedText
    }
}
