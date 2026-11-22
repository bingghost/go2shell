import AppKit
import Go2TermCore

/// Settings window host. M4 placeholder; the SwiftUI view arrives in M5.
@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("settings.title")
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}
