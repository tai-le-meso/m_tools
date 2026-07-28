import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ManropeFonts.registerIfNeeded()

        // NSHostingController (not a bare NSHostingView) is what actually matters here:
        // SwiftUI's `.sheet()`/`.popover()` presentation goes through NSViewController
        // sheet-presentation machinery, which a raw NSHostingView isn't part of — without
        // a hosting controller in the window's contentViewController, sheets silently
        // fail to appear. The CSV Editor's cell-detail dialog is what first needed this.
        let hostingController = NSHostingController(rootView: AppShellView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "m_tools"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        // `LSUIElement` (accessory) apps aren't guaranteed to become the truly *active*
        // application on launch just because their window is key — without this, standard
        // keyDown-routed editing commands (⌘A select-all, Home/End) can silently fail to
        // reach a focused text view the first time the app opens, since some other app can
        // still be holding activation. The status-item's "Show m_tools" path already did
        // this (see below); launch needed the same call.
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        menuBarController = MenuBarController(showWindow: { [weak window] in
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        })
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // menu-bar app — stay alive when the main window closes
    }
}
