import SwiftUI

// Reusable pieces that carry the Mesoneer visual language into m_tools.
// Content differs from the source KYC screens; the styling patterns don't.

// MARK: - Sidebar nav item (fixed-dark sidebar, same in light or dark app theme)

struct NavItemView: View {
    let icon: String          // SF Symbol name (see icon mapping doc)
    let label: String
    let badge: String?
    let isActive: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                    .frame(width: 20)
                Text(label)
                    .font(isActive ? ThemeFont.sidebarLabelActive : ThemeFont.sidebarLabel)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(ThemeFont.badge)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Theme.light.primaryBright) // brand accent, not theme-dependent
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isActive ? .white : Theme.navText(for: colorScheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isActive ? Theme.light.primaryBright
                    : (isHovering ? Theme.navHover : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Filter chip (pill, filled when active)

struct FilterChipView: View {
    let label: String
    let isActive: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ThemeFont.bodyMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundColor(isActive ? theme.onPrimary : theme.text)
                .background(isActive ? theme.primary : Color.clear)
                .overlay(
                    Capsule().stroke(isActive ? theme.primary : theme.border, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab with count (underline-style active state)

struct CountTabView: View {
    let label: String
    let count: Int
    let isActive: Bool
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(isActive ? ThemeFont.manrope(14, weight: .bold) : ThemeFont.body)
                    .foregroundColor(isActive ? theme.text : theme.muted)
                Text("\(count)")
                    .font(ThemeFont.manrope(12, weight: .semibold))
                    .foregroundColor(isActive ? theme.primary : theme.muted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(isActive ? theme.primary100 : theme.surface2)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 10)
            .overlay(
                Rectangle()
                    .fill(isActive ? theme.primary : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible sidebar category header (devutils.com-style grouped tool list)

struct CategorySectionHeader: View {
    let label: String
    let count: Int
    let isExpanded: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                Text(label.uppercased())
                    .font(ThemeFont.manrope(10, weight: .semibold))
                Spacer()
                Text("\(count)")
                    .font(ThemeFont.manrope(10, weight: .medium))
            }
            .foregroundColor(Theme.navText(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isExpanded)
    }
}

// MARK: - Search field (header center, matches the palette/⌘K trigger look)

struct ThemedSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search tools…"
    let theme: Theme
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.muted)
                .font(.system(size: 14))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(ThemeFont.body)
                .focused($focused)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(theme.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall)
                .stroke(focused ? theme.primary : theme.border, lineWidth: focused ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

// MARK: - Icon button (theme toggle, notifications, etc.)

struct ThemedIconButton: View {
    let icon: String
    let theme: Theme
    var showDot: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.text)
                    .frame(width: 40, height: 40)
                if showDot {
                    Circle()
                        .fill(Theme.danger)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(theme.surface, lineWidth: 2))
                        .offset(x: -8, y: 8)
                }
            }
        }
        .buttonStyle(.plain)
        .background(isHovering ? theme.surface2 : theme.surface)
        .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
        .onHover { isHovering = $0 }
    }
}

// MARK: - Primary filled button (header CTA style)

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let theme: Theme
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(ThemeFont.bodyMedium)
            }
            .foregroundColor(theme.onPrimary)
            .padding(.horizontal, 16)
            .frame(height: 40)
        }
        .buttonStyle(.plain)
        .background(theme.primary.brightness(isHovering ? 0.08 : 0))
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
        .onHover { isHovering = $0 }
    }
}
