import AppKit
import Go2TermCore

// M0 placeholder: show an empty window titled "Go2Term".
// Launch routing, Finder integration and settings UI arrive in M1–M5.

@MainActor
final class PlaceholderAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Info.plist sets LSUIElement=true; promote to a regular app so the window is visible.
        NSApp.setActivationPolicy(.regular)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = Go2TermInfo.appName
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = PlaceholderAppDelegate()
app.delegate = delegate
app.run()
