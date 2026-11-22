import AppKit
import Go2ShellCore

/// Opens a terminal session in a directory (docs/02-TECH-DESIGN.md §3.4).
@MainActor
protocol TerminalLauncher {
    func open(directory: URL, command: String, mode: OpenMode) throws
}

@MainActor
enum LauncherFactory {
    /// Returns a launcher for `kind`, falling back to Terminal.app when it is not installed
    /// or not yet supported. The second value is the kind actually used.
    static func make(for kind: TerminalKind) -> (TerminalLauncher, TerminalKind) {
        if let url = applicationURL(for: kind) {
            switch kind {
            case .iTerm2: return (ITermLauncher(), .iTerm2)
            case .appleTerminal: return (AppleTerminalLauncher(), .appleTerminal)
            case .ghostty, .wezterm, .kitty, .alacritty, .warp:
                return (GenericLauncher(kind: kind, appURL: url), kind)
            }
        }
        return (AppleTerminalLauncher(), .appleTerminal)
    }

    static func applicationURL(for kind: TerminalKind) -> URL? {
        for identifier in kind.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return url
            }
        }
        return nil
    }

    static func isInstalled(_ kind: TerminalKind) -> Bool {
        applicationURL(for: kind) != nil
    }

    static func isRunning(_ kind: TerminalKind) -> Bool {
        kind.bundleIdentifiers.contains {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
        }
    }
}
