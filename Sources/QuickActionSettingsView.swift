import SwiftUI

/// Editor for the menu bar's Quick Actions list, presented as a sheet from the sidebar's
/// Settings item.
///
/// Split into "in your menu" (ordered, the thing being configured) and "available" (the
/// rest of the catalog) rather than one list of checkboxes, because order matters here —
/// the first nine get ⌘1…⌘9 — and a single list can't show position and membership at once.
struct QuickActionSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appState = AppState.shared

    /// Mirrors of the persisted values. `QuickActionSettings` is a plain UserDefaults
    /// wrapper rather than an ObservableObject, so the view holds its own copy and writes
    /// through on every edit; `reload()` pulls it back in when the sheet opens.
    @State private var enabledIDs: [String] = []
    @State private var copyResult = true

    private var theme: Theme { Theme.current(for: colorScheme) }

    private var enabledActions: [QuickAction] { QuickActionCatalog.actions(for: enabledIDs) }
    private var availableActions: [QuickAction] {
        QuickActionCatalog.all.filter { !enabledIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    behaviorSection
                    enabledSection
                    availableSection
                }
                .padding(22)
            }

            Divider()
            footer
        }
        .frame(width: 560, height: 620)
        .background(theme.bg)
        .onAppear(perform: reload)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick Actions")
                .font(ThemeFont.title)
                .foregroundColor(theme.text)
            Text("Copy something, pick an action from the menu bar, and m_tools opens on that tool with your clipboard already in it.")
                .font(ThemeFont.manrope(12))
                .foregroundColor(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Behavior")
            Toggle(isOn: $copyResult) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Copy the result back to the clipboard")
                        .font(ThemeFont.bodyMedium)
                        .foregroundColor(theme.text)
                    Text("Leave this on to paste the converted text straight into something else. The app opens on the tool either way.")
                        .font(ThemeFont.manrope(11))
                        .foregroundColor(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)
            .onChange(of: copyResult) { newValue in
                QuickActionSettings.copyResultToClipboard = newValue
            }
        }
    }

    private var enabledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("In your menu", trailing: "\(enabledActions.count)")

            if enabledActions.isEmpty {
                emptyHint("Nothing enabled — your menu bar will only show Show and Quit. Add some below.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(enabledActions.enumerated()), id: \.element.id) { index, action in
                        enabledRow(action, index: index)
                        if index < enabledActions.count - 1 { Divider() }
                    }
                }
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
            }
        }
    }

    private var availableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Available", trailing: "\(availableActions.count)")

            if availableActions.isEmpty {
                emptyHint("Every action is already in your menu.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(availableActions.enumerated()), id: \.element.id) { index, action in
                        availableRow(action)
                        if index < availableActions.count - 1 { Divider() }
                    }
                }
                .background(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Restore Defaults") {
                QuickActionSettings.restoreDefaults()
                reload()
            }
            .buttonStyle(.plain)
            .font(ThemeFont.bodyMedium)
            .foregroundColor(theme.muted)

            Spacer()

            PrimaryButton(title: "Done", icon: nil, theme: theme) {
                appState.isSettingsPresented = false
            }
        }
        .padding(18)
        .background(theme.surface)
    }

    // MARK: Rows

    private func enabledRow(_ action: QuickAction, index: Int) -> some View {
        HStack(spacing: 10) {
            // The first nine get a ⌘-number shortcut, so showing the position is showing
            // the shortcut — which is the main reason order is worth configuring.
            Text(index < 9 ? "⌘\(index + 1)" : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(index < 9 ? theme.primary : theme.muted)
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(ThemeFont.bodyMedium)
                    .foregroundColor(theme.text)
                Text(toolName(for: action))
                    .font(ThemeFont.manrope(10))
                    .foregroundColor(theme.muted)
            }

            Spacer()

            iconButton("chevron.up", disabled: index == 0) {
                QuickActionSettings.move(action.id, by: -1)
                reload()
            }
            iconButton("chevron.down", disabled: index == enabledActions.count - 1) {
                QuickActionSettings.move(action.id, by: 1)
                reload()
            }
            iconButton("minus.circle") {
                QuickActionSettings.setEnabled(action.id, false)
                reload()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    private func availableRow(_ action: QuickAction) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(ThemeFont.bodyMedium)
                    .foregroundColor(theme.text)
                Text(toolName(for: action))
                    .font(ThemeFont.manrope(10))
                    .foregroundColor(theme.muted)
            }
            Spacer()
            iconButton("plus.circle") {
                QuickActionSettings.setEnabled(action.id, true)
                reload()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    // MARK: Pieces

    private func sectionTitle(_ text: String, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(text.uppercased())
                .font(ThemeFont.eyebrow)
                .foregroundColor(theme.muted)
            if let trailing {
                Text(trailing)
                    .font(ThemeFont.manrope(10, weight: .bold))
                    .foregroundColor(theme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(theme.surface2)
                    .clipShape(Capsule())
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(ThemeFont.manrope(12))
            .foregroundColor(theme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface2.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
    }

    private func iconButton(_ icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(disabled ? theme.muted.opacity(0.35) : theme.muted)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// The tool a given action opens, shown as a subtitle so it's clear where a menu entry
    /// will land — several actions share one tool (Beautify/Minify) and the mapping isn't
    /// always obvious from the action's own name.
    private func toolName(for action: QuickAction) -> String {
        ToolRegistry.shared.all.first { $0.id == action.toolId }?.name ?? action.toolId
    }

    private func reload() {
        enabledIDs = QuickActionSettings.enabledIDs
        copyResult = QuickActionSettings.copyResultToClipboard
    }
}
