import SwiftUI
import AppKit

// devutils.com-style shell: a sidebar listing every tool grouped by category (searchable,
// collapsible sections) with the selected tool's own two-pane view filling the main area —
// no card-grid dashboard. Sidebar stays fixed-dark per the Mesoneer design system
// (docs/mesoneer-design-system.md); only the navigation *pattern* borrows from devutils.com.

struct AppShellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var collapsedCategories: Set<ToolCategory> = []

    /// Selection lives in `AppState`, not local `@State`, so the menu bar's quick actions
    /// can navigate the window. It opens on the first registered tool — this app has no
    /// home/dashboard screen, per docs/mesoneer-design-system.md intent.
    @ObservedObject private var appState = AppState.shared

    private let registry = ToolRegistry.shared

    private var theme: Theme { Theme.current(for: colorScheme) }

    private var selectedTool: DevToolSummary? {
        registry.all.first { $0.id == appState.selectedToolId }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                content
            }
            .background(theme.bg)
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(theme.bg)
        .sheet(isPresented: $appState.isSettingsPresented) {
            QuickActionSettingsView()
        }
    }

    // MARK: Sidebar — fixed-dark regardless of app theme, per the source design

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wordmark from the branding doc's "1b" lockup: white `m` + `tools` with the
            // underscore in the icon's amber, so the sidebar and the app icon share one mark.
            // Concatenated `Text` (not an HStack) so the pieces sit on one baseline with
            // real letter spacing rather than manually-tuned gaps.
            (
                Text("m").foregroundColor(.white)
                    + Text("_").foregroundColor(Theme.brandAccent)
                    + Text("tools").foregroundColor(.white)
            )
            .font(ThemeFont.manrope(22, weight: .heavy))
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)

            Text("INTERNAL TOOLBOX")
                .font(ThemeFont.eyebrow)
                .foregroundColor(Theme.navText(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.bottom, 14)

            sidebarSearchField
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(registry.groupedCategories) { category in
                        categorySection(category)
                    }
                }
            }

            Spacer(minLength: 8)

            Rectangle()
                .fill(Theme.navHover)
                .frame(height: 1)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

            NavItemView(
                icon: "gearshape",
                label: "Settings",
                badge: nil,
                isActive: false,
                colorScheme: colorScheme,
                action: { appState.isSettingsPresented = true }
            )

            // Which build is running, in the conventional spot for it. Read from the bundle
            // via AppInfo, so it can't drift from build.sh's VERSION.
            Text(AppInfo.displayVersion)
                .font(ThemeFont.manrope(10, weight: .medium))
                .foregroundColor(Theme.navText(for: colorScheme))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .help("\(AppInfo.name) \(AppInfo.version)")
        }
        .padding(14)
        .frame(width: ThemeMetrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(Theme.navBackground(for: colorScheme))
    }

    /// A dark-sidebar-tinted search field — the same visual language as
    /// `ThemedSearchField` but colored for the fixed-dark nav rather than the app surface.
    private var sidebarSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.navText(for: colorScheme))
                .font(.system(size: 12))
            TextField("Search tools…", text: $searchText)
                .textFieldStyle(.plain)
                .font(ThemeFont.manrope(13))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Theme.navHover)
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
    }

    @ViewBuilder
    private func categorySection(_ category: ToolCategory) -> some View {
        let tools = registry.tools(in: category, matching: searchText)
        if !tools.isEmpty {
            // While actively searching, force sections open so matches are never hidden.
            let expanded = !searchText.isEmpty || !collapsedCategories.contains(category)

            CategorySectionHeader(
                label: category.label,
                count: tools.count,
                isExpanded: expanded,
                colorScheme: colorScheme,
                action: {
                    if collapsedCategories.contains(category) {
                        collapsedCategories.remove(category)
                    } else {
                        collapsedCategories.insert(category)
                    }
                }
            )

            if expanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(tools) { tool in
                        NavItemView(
                            icon: tool.icon,
                            label: tool.name,
                            badge: nil,
                            isActive: tool.id == appState.selectedToolId,
                            colorScheme: colorScheme,
                            action: { appState.navigate(toToolID: tool.id) }
                        )
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text((selectedTool?.category.label ?? "").uppercased())
                    .font(ThemeFont.eyebrow)
                    .foregroundColor(theme.muted)
                Text(selectedTool?.name ?? "Select a tool")
                    .font(ThemeFont.title)
                    .foregroundColor(theme.text)
            }

            Spacer()

            HStack(spacing: 6) {
                ThemedIconButton(icon: colorScheme == .dark ? "sun.max" : "moon", theme: theme) {
                    toggleAppearance()
                }
                ThemedIconButton(icon: "command", theme: theme) {
                    // open ⌘K command palette
                }
            }
        }
        .padding(.horizontal, 26)
        .frame(height: ThemeMetrics.headerHeight)
        .background(theme.surface)
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
    }

    /// Flips light/dark. This app has no SwiftUI `App`/`Scene` lifecycle (plain
    /// `NSApplication` + a hand-hosted `NSHostingController`, per CLAUDE.md's "no Xcode
    /// project" build), so there's no `.preferredColorScheme` root to attach an override to —
    /// `@Environment(\.colorScheme)` here only ever reflects the actual window appearance.
    /// Setting `NSApp.appearance` alone doesn't repaint an already-visible window, so the
    /// window's own `appearance` is set directly too.
    private func toggleAppearance() {
        let appearance = NSAppearance(named: colorScheme == .dark ? .aqua : .darkAqua)
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }

    // MARK: Content — the selected tool's own view, filling the main pane directly

    private var content: some View {
        Group {
            if let selectedTool {
                ToolViewFactory.view(for: selectedTool.id)
                    // Folding the navigation token into the identity forces a fresh
                    // tool view per navigation, so `onAppear` fires and the pending
                    // clipboard text is picked up — even when a quick action targets
                    // the tool that is already on screen.
                    .id("\(selectedTool.id)-\(appState.navigationToken)")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 28))
                        .foregroundColor(theme.muted)
                    Text("Pick a tool from the sidebar to get started")
                        .font(ThemeFont.body)
                        .foregroundColor(theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
