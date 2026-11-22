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

/// Opens the configured terminal at `explicitPath`, or at the Finder location when nil.
/// Temporary CLI-style flow; M4 moves this into AppController with alerts.
@MainActor
func openTerminal(explicitPath: String?) -> Int32 {
    do {
        let directory = try explicitPath.map { try FinderLocator.validatedDirectory(path: $0) }
            ?? FinderLocator().frontWindowDirectory()
        let settings = UserDefaultsSettingsStore().load()
        let (launcher, _) = LauncherFactory.make(for: settings.terminal)
        let command = CommandTemplate(settings.commandTemplate).render(path: directory.path)
        try launcher.open(directory: directory, command: command, mode: settings.openMode)
        return 0
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        return 1
    }
}

switch LaunchRouter.route(context) {
case .printFinderPath:
    exit(MainActor.assumeIsolated { printFinderPath() })
case .openTerminal(let explicitPath):
    exit(MainActor.assumeIsolated { openTerminal(explicitPath: explicitPath) })
default:
    let app = NSApplication.shared
    let delegate = PlaceholderAppDelegate()
    app.delegate = delegate
    app.run()
}
