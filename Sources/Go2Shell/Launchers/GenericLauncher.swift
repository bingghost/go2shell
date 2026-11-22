import AppKit
import Go2ShellCore

/// Launches terminals without an AppleScript dictionary through NSWorkspace — no shell involved.
///
/// Strategy per terminal (see docs/02-TECH-DESIGN.md §3.1; marked "not tested on this Mac"
/// where the app was not installed during development):
/// - Ghostty / Warp: open the folder with the app (both open a new window/tab in that folder).
/// - WezTerm / kitty / Alacritty: start a new instance with a working-directory argument.
@MainActor
final class GenericLauncher: TerminalLauncher {
    /// How long to wait for Launch Services to confirm the launch.
    private static let launchWait: TimeInterval = 5

    private let kind: TerminalKind
    private let appURL: URL

    init(kind: TerminalKind, appURL: URL) {
        self.kind = kind
        self.appURL = appURL
    }

    func open(directory: URL, command: String, mode: OpenMode) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true

        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: Error?
        let completion: @Sendable (NSRunningApplication?, Error?) -> Void = { _, error in
            failure = error
            done.signal()
        }

        if let arguments = kind.workingDirectoryArguments(directory.path) {
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: completion)
        } else {
            NSWorkspace.shared.open([directory], withApplicationAt: appURL, configuration: configuration, completionHandler: completion)
        }

        // Wait (off the completion queue) so the app does not quit before Launch Services acts.
        // A timeout is not a failure: the request is already with Launch Services, and the
        // terminal still opens once the user answers a first-launch (Gatekeeper) prompt.
        if done.wait(timeout: .now() + Self.launchWait) == .timedOut {
            Log.app.notice("\(self.kind.rawValue, privacy: .public) has not confirmed launch after \(Int(Self.launchWait))s; not waiting further")
            return
        }
        if let failure {
            throw Go2ShellError.scriptFailed(code: (failure as NSError).code, message: failure.localizedDescription)
        }
    }
}
