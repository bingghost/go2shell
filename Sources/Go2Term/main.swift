import AppKit
import Go2TermCore

let launchStart = ContinuousClock.now

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
let action = LaunchRouter.route(context)

if action == .printFinderPath {
    exit(MainActor.assumeIsolated { printFinderPath() })
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let controller = AppController(action: action, launchStart: launchStart)
    app.delegate = controller
    withExtendedLifetime(controller) { app.run() }
}
