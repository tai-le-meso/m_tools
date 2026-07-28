import SwiftUI
import AppKit

/// A collapsible tree view over a parsed document (JSON / YAML / XML) — the "JSON Viewer"
/// half of each format tool's output pane.
///
/// Built on AppKit's `NSOutlineView` rather than a SwiftUI list, because expand/collapse is
/// exactly the operation SwiftUI handles worst here. A SwiftUI `ForEach` needs the whole
/// visible-row array up front, so every toggle means re-flattening the tree *and* diffing
/// thousands of `Identifiable` rows to work out what moved — the cost scales with document
/// size even though the user only touched one node. `NSOutlineView` is the purpose-built
/// control for this: it only ever asks for the children of items that are actually
/// expanded, recycles row views while scrolling, and animates disclosure natively, so a
/// toggle costs about what the one subtree costs. It also brings keyboard navigation,
/// arrow-key expand/collapse, and native selection for free.
///
/// Still zero dependencies — `NSOutlineView` is AppKit, the same system framework the rest
/// of the app already sits on.
struct TreeOutlineView: View {
    let root: TreeNode
    /// Bumped by the owner whenever `root` is replaced. `TreeNode` identity is per-parse, so
    /// this is the cheap "the document actually changed, reload" signal — as opposed to the
    /// countless re-renders where it hasn't.
    let version: Int
    let theme: Theme

    @Environment(\.colorScheme) private var colorScheme

    /// Expand/Collapse-all are one-shot commands, but `NSViewRepresentable` only ever sees
    /// state. Incrementing a counter gives the representable something to compare against
    /// what it last acted on, which is how a command survives the trip through `updateNSView`.
    @State private var expandAllToken = 0
    @State private var collapseAllToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()
            OutlineRepresentable(
                root: root,
                version: version,
                theme: theme,
                isDarkMode: colorScheme == .dark,
                expandAllToken: expandAllToken,
                collapseAllToken: collapseAllToken
            )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            toolbarButton("Expand all", icon: "chevron.down") { expandAllToken &+= 1 }
            toolbarButton("Collapse all", icon: "chevron.right") { collapseAllToken &+= 1 }
            Spacer()
            // Total nodes, not visible rows: it's free (precomputed during parsing) and
            // doesn't need syncing back out of AppKit every time something is folded.
            Text("\(root.nodeCount) nodes")
                .font(ThemeFont.manrope(10, weight: .medium))
                .foregroundColor(theme.muted)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private func toolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(title).font(ThemeFont.manrope(11, weight: .medium))
            }
            .foregroundColor(theme.muted)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AppKit bridge

private struct OutlineRepresentable: NSViewRepresentable {
    let root: TreeNode
    let version: Int
    let theme: Theme
    /// Compared instead of the `Theme` itself (which isn't `Equatable`) or its converted
    /// `NSColor`s (whose equality across color spaces isn't dependable) — a plain Bool is
    /// the one signal that reliably says "the palette changed, redraw".
    let isDarkMode: Bool
    let expandAllToken: Int
    let collapseAllToken: Int

    /// Below this many nodes the document opens fully expanded, which is what you want for
    /// a small payload. Above it, only the root is opened — expanding tens of thousands of
    /// rows on load is slow *and* useless to look at.
    private let autoExpandThreshold = 1_500

    func makeCoordinator() -> Coordinator {
        Coordinator(root: root, theme: theme, isDarkMode: isDarkMode)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outline = NSOutlineView()
        outline.headerView = nil
        outline.style = .plain // not .inset/.sourceList — no extra leading inset or capsule rows
        outline.rowSizeStyle = .custom
        outline.rowHeight = 18
        outline.indentationPerLevel = 14
        outline.usesAlternatingRowBackgroundColors = false
        outline.backgroundColor = .clear
        outline.gridStyleMask = []
        outline.autoresizesOutlineColumn = false
        outline.dataSource = context.coordinator
        outline.delegate = context.coordinator

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tree"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        let scrollView = NSScrollView()
        scrollView.documentView = outline
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // Explicit first load: NSOutlineView otherwise defers loading until it's displayed,
        // and `expandItem` on rows it hasn't asked the data source about yet does nothing.
        outline.reloadData()
        context.coordinator.applyInitialExpansion(outline, threshold: autoExpandThreshold)
        context.coordinator.lastVersion = version
        context.coordinator.lastExpandAllToken = expandAllToken
        context.coordinator.lastCollapseAllToken = collapseAllToken
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let outline = scrollView.documentView as? NSOutlineView else { return }
        let coordinator = context.coordinator

        if coordinator.lastVersion != version {
            coordinator.lastVersion = version
            coordinator.replaceRoot(root, in: outline, threshold: autoExpandThreshold)
        }

        // A light/dark flip changes the cached row colors but not the structure, so the
        // rows just need redrawing — no reload, no expansion churn.
        if coordinator.updateThemeIfNeeded(theme, isDarkMode: isDarkMode) {
            outline.reloadData()
            coordinator.restoreExpansion(in: outline)
        }

        if coordinator.lastExpandAllToken != expandAllToken {
            coordinator.lastExpandAllToken = expandAllToken
            outline.expandItem(nil, expandChildren: true)
        }
        if coordinator.lastCollapseAllToken != collapseAllToken {
            coordinator.lastCollapseAllToken = collapseAllToken
            outline.collapseItem(nil, collapseChildren: true)
            // Root itself stays open — collapsing everything would leave one useless line.
            outline.expandItem(coordinator.root)
        }
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private(set) var root: TreeNode
        private var theme: Theme
        private var colorsByRole: [SyntaxTokenRole: NSColor] = [:]
        private var keyColor: NSColor = .labelColor
        private var mutedColor: NSColor = .secondaryLabelColor
        private var textColor: NSColor = .labelColor
        /// Ids of nodes expanded before the last reload, so the same ones can be reopened
        /// afterwards — otherwise every keystroke would silently fold the user's place away.
        private var expandedIDs: Set<String> = []

        var lastVersion = -1
        var lastExpandAllToken = 0
        var lastCollapseAllToken = 0

        private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private let cellIdentifier = NSUserInterfaceItemIdentifier("treeCell")

        private var isDarkMode: Bool

        init(root: TreeNode, theme: Theme, isDarkMode: Bool) {
            self.root = root
            self.theme = theme
            self.isDarkMode = isDarkMode
            super.init()
            cacheColors()
        }

        // MARK: Content updates

        func replaceRoot(_ newRoot: TreeNode, in outline: NSOutlineView, threshold: Int) {
            captureExpansion(from: outline)
            root = newRoot
            outline.reloadData()
            if expandedIDs.isEmpty {
                applyInitialExpansion(outline, threshold: threshold)
            } else {
                restoreExpansion(in: outline)
            }
        }

        func applyInitialExpansion(_ outline: NSOutlineView, threshold: Int) {
            if root.nodeCount <= threshold {
                outline.expandItem(nil, expandChildren: true)
            } else {
                outline.expandItem(root)
            }
            captureExpansion(from: outline)
        }

        /// Walks only the currently-visible rows (AppKit doesn't materialize collapsed ones),
        /// so this is proportional to what's on screen, not to the document.
        private func captureExpansion(from outline: NSOutlineView) {
            var ids: Set<String> = []
            for row in 0..<outline.numberOfRows {
                guard let node = outline.item(atRow: row) as? TreeNode else { continue }
                if outline.isItemExpanded(node) { ids.insert(node.id) }
            }
            expandedIDs = ids
        }

        func restoreExpansion(in outline: NSOutlineView) {
            reopen(node: root, in: outline)
        }

        private func reopen(node: TreeNode, in outline: NSOutlineView) {
            guard !node.isLeaf, expandedIDs.contains(node.id) else { return }
            // Parents must be expanded before their children are addressable, so this walks
            // strictly top-down — and only down branches that were open.
            outline.expandItem(node)
            for child in node.children {
                reopen(node: child, in: outline)
            }
        }

        /// Returns whether anything changed, so the caller only redraws when it must.
        func updateThemeIfNeeded(_ newTheme: Theme, isDarkMode newIsDarkMode: Bool) -> Bool {
            guard isDarkMode != newIsDarkMode else { return false }
            isDarkMode = newIsDarkMode
            theme = newTheme
            cacheColors()
            return true
        }

        /// SwiftUI `Color` -> `NSColor` conversion isn't free, and a row is rebuilt every
        /// time it scrolls into view, so the palette is converted once per theme instead.
        private func cacheColors() {
            let syntax = theme.syntax
            keyColor = NSColor(syntax.key)
            mutedColor = NSColor(theme.muted)
            textColor = NSColor(theme.text)
            colorsByRole = [
                .key: keyColor,
                .string: NSColor(syntax.string),
                .number: NSColor(syntax.number),
                .keyword: NSColor(syntax.keyword),
                .comment: NSColor(syntax.comment),
                .tag: NSColor(syntax.tag),
                .attribute: NSColor(syntax.attribute),
                .punctuation: mutedColor,
            ]
        }

        // MARK: NSOutlineViewDataSource

        // `item == nil` means the outline is asking about the invisible container above the
        // root, which holds exactly one child: the root itself.
        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            guard let node = item as? TreeNode else { return 1 }
            return node.children.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            guard let node = item as? TreeNode else { return root }
            return node.children[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? TreeNode else { return false }
            return !node.isLeaf
        }

        // MARK: NSOutlineViewDelegate

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? TreeNode else { return nil }

            // Recycled from AppKit's reuse pool — this is the part a SwiftUI list can't do.
            let field: NSTextField
            if let reused = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField {
                field = reused
            } else {
                field = NSTextField(labelWithString: "")
                field.identifier = cellIdentifier
                field.font = font
                field.lineBreakMode = .byTruncatingTail
                field.drawsBackground = false
                field.isBordered = false
            }
            field.attributedStringValue = attributedLine(for: node)
            field.toolTip = plainText(for: node)
            return field
        }

        private func attributedLine(for node: TreeNode) -> NSAttributedString {
            let line = NSMutableAttributedString()
            if let key = node.key {
                line.append(NSAttributedString(
                    string: key, attributes: [.font: font, .foregroundColor: keyColor]
                ))
                line.append(NSAttributedString(
                    string: ": ", attributes: [.font: font, .foregroundColor: mutedColor]
                ))
            }
            if let value = node.valueText {
                let color = node.valueRole.flatMap { colorsByRole[$0] } ?? textColor
                line.append(NSAttributedString(
                    string: value, attributes: [.font: font, .foregroundColor: color]
                ))
            }
            if let badge = node.badge {
                line.append(NSAttributedString(
                    string: badge, attributes: [.font: font, .foregroundColor: mutedColor]
                ))
            }
            return line
        }

        private func plainText(for node: TreeNode) -> String {
            var parts: [String] = []
            if let key = node.key { parts.append("\(key):") }
            if let value = node.valueText { parts.append(value) }
            if let badge = node.badge { parts.append(badge) }
            return parts.joined(separator: " ")
        }

        // Keeping the remembered set current as the user folds things means an incoming
        // document edit reopens exactly what was open a moment ago.
        func outlineViewItemDidExpand(_ notification: Notification) {
            if let node = notification.userInfo?["NSObject"] as? TreeNode {
                expandedIDs.insert(node.id)
            }
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            if let node = notification.userInfo?["NSObject"] as? TreeNode {
                expandedIDs.remove(node.id)
            }
        }
    }
}
