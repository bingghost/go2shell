import Foundation
import Go2TermCore

/// Terminal.app via `do script`. Command text is passed as a handler parameter.
@MainActor
final class AppleTerminalLauncher: TerminalLauncher {
    private static let source = """
    on openWindow(cmd, wasRunning)
        tell application id "com.apple.Terminal"
            if wasRunning is "0" then
                -- Cold start: Terminal opens a default window; run the command there.
                launch
                repeat 20 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.1
                end repeat
                if (count of windows) > 0 then
                    do script cmd in front window
                else
                    do script cmd
                end if
            else
                do script cmd
            end if
            activate
        end tell
    end openWindow
    """

    func open(directory: URL, command: String, mode: OpenMode) throws {
        // New-tab mode for Terminal.app is experimental and arrives in M6.
        let wasRunning = LauncherFactory.isRunning(.appleTerminal)
        let runner = try AppleScriptRunner(source: Self.source, target: "Terminal")
        try runner.call("openWindow", [command, wasRunning ? "1" : "0"])
    }
}
