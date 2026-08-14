import AppKit

/// Menu-bar icon and its menu, which is where Quick Actions live: copy something, pick a
/// conversion here, and the app opens on that tool with the clipboard already in it.
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let showWindow: () -> Void

    init(showWindow: @escaping () -> Void) {
        self.showWindow = showWindow
        super.init()
        setupStatusItem()
        startWatchingClipboard()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuBarIcon()

        let menu = NSMenu()
        // Rebuilt on every open (see `menuNeedsUpdate`) so edits in the settings sheet show
        // up immediately — a menu built once at launch would keep showing the old list until
        // the app restarted.
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuild(menu)
    }

    // MARK: Menu construction

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        // Informational header showing which build is running — disabled rather than
        // removed from the responder chain, which is the standard way macOS menus render
        // non-actionable text (it greys out instead of looking like a broken menu item).
        let versionItem = menu.addItem(withTitle: AppInfo.nameAndVersion, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(.separator())

        addQuickActions(to: menu)

        let showItem = menu.addItem(withTitle: "Show m_tools", action: #selector(showWindowFromMenu), keyEquivalent: "")
        showItem.target = self

        let settingsItem = menu.addItem(withTitle: "Quick Action Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())
        // `target: nil` on Quit routes the action up the responder chain to NSApplication,
        // which implements `terminate(_:)` — the standard trick for status-bar-only apps.
        menu.addItem(withTitle: "Quit m_tools", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func addQuickActions(to menu: NSMenu) {
        let actions = QuickActionSettings.enabledActions
        guard !actions.isEmpty else {
            // Every action turned off is a valid choice, but an unexplained gap in the menu
            // isn't — say where they went.
            let empty = menu.addItem(withTitle: "No quick actions enabled", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(.separator())
            return
        }

        let header = menu.addItem(withTitle: "Quick Actions — run on clipboard", action: nil, keyEquivalent: "")
        header.isEnabled = false

        for (index, action) in actions.enumerated() {
            let item = menu.addItem(withTitle: action.title, action: #selector(runQuickAction(_:)), keyEquivalent: "")
            item.target = self
            // The id, not the index — the menu is rebuilt on every open, and identifying by
            // position would break the moment the list is reordered while the menu is up.
            item.representedObject = action.id
            // ⌘1…⌘9 for the first nine, matching how tab/window shortcuts work elsewhere.
            if index < 9 {
                item.keyEquivalent = String(index + 1)
                item.keyEquivalentModifierMask = [.command]
            }
        }
        menu.addItem(.separator())
    }

    // MARK: Actions

    @objc private func runQuickAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let action = QuickActionCatalog.action(withID: id) else { return }

        let outcome = QuickActionRunner.run(action) { [weak self] in
            self?.showWindow()
        }
        flashStatus(outcome.statusText)
    }

    @objc private func openSettings() {
        AppState.shared.isSettingsPresented = true
        showWindow()
    }

    /// Briefly replaces the menu bar icon with a word, then restores it. The window is
    /// coming forward anyway, so this is a secondary cue — mainly useful for confirming the
    /// result reached the clipboard when the copy setting is on.
    private func flashStatus(_ text: String) {
        guard let button = statusItem?.button else { return }
        let previousImage = button.image
        button.image = nil
        button.title = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak button] in
            button?.title = ""
            button?.image = previousImage
        }
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
