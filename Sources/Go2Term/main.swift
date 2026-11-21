import AppKit
import Go2TermCore

// Entry point. Full launch orchestration (terminal opening, settings, reopen) lands in M3/M4.

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

@MainActor
func printFinderPath() -> Int32 {
    do {
        let url = try FinderLocator().frontWindowDirectory()
        print(url.path)
        return 0
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        return 1
    }
}

let context = LaunchContext(
    arguments: CommandLine.arguments,
    frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
    optionKeyDown: NSEvent.modifierFlags.contains(.option)
)

switch LaunchRouter.route(context) {
case .printFinderPath:
    exit(MainActor.assumeIsolated { printFinderPath() })
default:
    let app = NSApplication.shared
    let delegate = PlaceholderAppDelegate()
    app.delegate = delegate
    app.run()
}
