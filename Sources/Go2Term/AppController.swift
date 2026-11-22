import AppKit
import Go2TermCore

/// Orchestrates a launch: open a terminal and quit, or show settings (docs/02-TECH-DESIGN.md §3.5).
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let initialAction: LaunchAction
    private let launchStart: ContinuousClock.Instant
    private var settingsController: SettingsWindowController?
    private let store = UserDefaultsSettingsStore()

    init(action: LaunchAction, launchStart: ContinuousClock.Instant) {
        initialAction = action
        self.launchStart = launchStart
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let actionName: String = switch initialAction {
        case .openTerminal(let path): path == nil ? "openTerminal(finder)" : "openTerminal(--open)"
        case .showSettings: "showSettings"
        case .printFinderPath: "printFinderPath"
        }
        Log.app.info("launch action: \(actionName, privacy: .public), startup \(elapsedMS(since: self.launchStart))ms")
        LegacyImporter.runIfNeeded(store: store)
        switch initialAction {
        case .openTerminal(let explicitPath):
            openTerminal(explicitPath: explicitPath)
            NSApp.terminate(nil)
        case .showSettings, .printFinderPath:
            showSettings()
        }
    }

    /// Clicking the toolbar button while Go2Term is already running (settings open)
    /// sends a reopen event; treat it as a regular click when Finder is in front.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Log.app.info("reopen, frontmost=\(front ?? "nil", privacy: .public)")
        if front == LaunchRouter.finderBundleID {
            openTerminal(explicitPath: nil)
            return false
        }
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Actions

    func showSettings() {
        NSApp.setActivationPolicy(.regular)
        if settingsController == nil {
            settingsController = SettingsWindowController { [weak self] in
                self?.openTerminal(explicitPath: FileManager.default.homeDirectoryForCurrentUser.path)
            }
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Opens the configured terminal at `explicitPath`, or the Finder location when nil.
    func openTerminal(explicitPath: String?) {
        let start = ContinuousClock.now
        do {
            let directory: URL
            if let explicitPath {
                directory = try FinderLocator.validatedDirectory(path: explicitPath)
            } else {
                directory = try FinderLocator().frontWindowDirectory()
            }
            let finderMS = elapsedMS(since: start)
            Log.app.info("directory: \(directory.path, privacy: .private) (\(finderMS)ms)")

            let settings = store.load()
            let (launcher, used) = LauncherFactory.make(for: settings.terminal)
            if used != settings.terminal {
                Log.app.notice("\(settings.terminal.rawValue, privacy: .public) not available, using \(used.rawValue, privacy: .public)")
            }
            let command = CommandTemplate(settings.commandTemplate).render(path: directory.path)
            let mode: OpenMode = used.supportsNewTab ? settings.openMode : .newWindow
            try launcher.open(directory: directory, command: command, mode: mode)
            Log.app.info("opened \(used.rawValue, privacy: .public) mode=\(mode.rawValue, privacy: .public) finder=\(finderMS)ms total=\(elapsedMS(since: start))ms sinceLaunch=\(elapsedMS(since: self.launchStart))ms")
        } catch {
            Log.app.error("open failed: \(String(describing: error), privacy: .public)")
            ErrorPresenter.present(error)
        }
    }
}
