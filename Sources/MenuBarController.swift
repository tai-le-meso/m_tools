import AppKit

/// Menu-bar icon + clipboard watcher, per Phase 3 of the task plan. This is a scaffold —
/// wire in `Detection.swift` heuristics and a real popover/menu once tools exist to detect.
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let showWindow: () -> Void

    init(showWindow: @escaping () -> Void) {
        self.showWindow = showWindow
        setupStatusItem()
        startWatchingClipboard()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon()

        // The app runs as LSUIElement (no Dock icon, no standard app menu bar), so this
        // status-item menu is the only way to reach Quit — clicking the toolbar icon alone
        // used to just reopen the window with no way to quit at all.
        let menu = NSMenu()

        // Informational header showing which build is running — disabled rather than
        // removed from the responder chain, which is the standard way macOS menus render
        // non-actionable text (it greys out instead of looking like a broken menu item).
        let versionItem = menu.addItem(withTitle: AppInfo.nameAndVersion, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(.separator())

        let showItem = menu.addItem(withTitle: "Show m_tools", action: #selector(showWindowFromMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(.separator())
        // `target: nil` on Quit routes the action up the responder chain to NSApplication,
        // which implements `terminate(_:)` — the standard trick for status-bar-only apps.
        menu.addItem(withTitle: "Quit m_tools", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    @objc private func showWindowFromMenu() {
        showWindow()
    }

    /// The `{ m }` mark from the app icon, drawn in code as a *template* image.
    ///
    /// Template means macOS recolors it automatically — black in a light menu bar, white in
    /// a dark one — which is why this is monochrome rather than the full purple/amber icon:
    /// a colored status item ignores the user's menu bar appearance and looks out of place
    /// next to every system item. Drawn rather than shipped as an asset, per the project's
    /// no-image-assets convention.
    private static func menuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let braces = NSAttributedString(string: "{ }", attributes: [
            .font: NSFont(name: "Manrope-ExtraBold", size: 15)
                ?? NSFont.systemFont(ofSize: 14, weight: .heavy),
            .foregroundColor: NSColor.black, // ignored: template images use the alpha channel only
        ])
        let bracesSize = braces.size()
        braces.draw(at: NSPoint(x: (size.width - bracesSize.width) / 2,
                                y: (size.height - bracesSize.height) / 2))

        // The `m` sits between the braces, scaled down so the whole mark stays legible at
        // the menu bar's 18pt.
        let monogram = NSAttributedString(string: "m", attributes: [
            .font: NSFont(name: "Manrope-ExtraBold", size: 9)
                ?? NSFont.systemFont(ofSize: 9, weight: .heavy),
            .foregroundColor: NSColor.black,
        ])
        let monogramSize = monogram.size()
        monogram.draw(at: NSPoint(x: (size.width - monogramSize.width) / 2,
                                  y: (size.height - monogramSize.height) / 2))

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "m_tools"
        return image
    }

    private func startWatchingClipboard() {
        // Polling NSPasteboard.general.changeCount is the standard approach — there's no
        // push notification for clipboard changes on macOS.
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let count = NSPasteboard.general.changeCount
            guard count != self.lastChangeCount else { return }
            self.lastChangeCount = count
            self.handleClipboardChange()
        }
    }

    private func handleClipboardChange() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        // TODO: run Detection.swift heuristics against `text`, update statusItem menu with
        // an "Open in [Tool]" action if a match is found.
        _ = text
    }
}
