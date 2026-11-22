import Foundation
import Go2TermCore

/// iTerm2 via its AppleScript dictionary. Command text is passed as a handler parameter.
@MainActor
final class ITermLauncher: TerminalLauncher {
    // Constant source — see AppleScriptRunner.
    private static let source = """
    on waitForWindow()
        tell application id "com.googlecode.iterm2"
            repeat 20 times
                if (count of windows) > 0 then return true
                delay 0.1
            end repeat
        end tell
        return false
    end waitForWindow

    on openWindow(cmd, wasRunning)
        tell application id "com.googlecode.iterm2"
            activate
            if wasRunning is "0" and my waitForWindow() then
                -- Cold start: iTerm opened its own window; reuse it instead of adding a second.
                set w to current window
            else
                set w to (create window with default profile)
            end if
            tell current session of w to write text cmd
        end tell
    end openWindow

    on openTab(cmd, wasRunning)
        tell application id "com.googlecode.iterm2"
            activate
            if wasRunning is "0" and my waitForWindow() then
                set w to current window
            else if (count of windows) is 0 then
                set w to (create window with default profile)
            else
                set w to current window
                tell w to create tab with default profile
            end if
            tell current session of w to write text cmd
        end tell
    end openTab
    """

    func open(directory: URL, command: String, mode: OpenMode) throws {
        let wasRunning = LauncherFactory.isRunning(.iTerm2)
        let runner = try AppleScriptRunner(source: Self.source, target: "iTerm2")
        let handler = mode == .newTab ? "openTab" : "openWindow"
        try runner.call(handler, [command, wasRunning ? "1" : "0"])
    }
}
