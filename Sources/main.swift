import AppKit

// No @main SwiftUI App lifecycle — plain NSApplication entry point, matching the
// "no Xcode project" build convention (a SwiftUI App struct needs an .app bundle built
// by Xcode to resolve @main correctly in some configurations; this path is more robust
// for a hand-built bundle via swiftc).
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.regular)
NSApplication.shared.run()
