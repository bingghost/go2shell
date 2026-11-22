import ApplicationServices
import Foundation
import Go2ShellCore

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

    -- Experimental: Terminal has no "new tab" command, so press ⌘T via System Events.
    -- Returns "done" when the command ran, or "noTab" when no new tab appeared; the command
    -- is only sent once the tab count of the target window has grown, so it can never land
    -- in a tab the user is already working in.
    on openTab(cmd)
        tell application id "com.apple.Terminal"
            if (count of windows) is 0 then
                do script cmd
                activate
                return "done"
            end if
            activate
            try
                set targetWindow to id of front window
                set tabsBefore to count of tabs of window id targetWindow
            on error errMsg number errNum
                if errNum is -1743 then error errMsg number errNum
                return "noTab"
            end try
        end tell
        tell application id "com.apple.systemevents"
            tell (first process whose bundle identifier is "com.apple.Terminal")
                set frontmost to true
                keystroke "t" using command down
            end tell
        end tell
        repeat 30 times
            delay 0.05
            tell application id "com.apple.Terminal"
                try
                    if (count of tabs of window id targetWindow) > tabsBefore then
                        do script cmd in window id targetWindow
                        return "done"
                    end if
                end try
            end tell
        end repeat
        return "noTab"
    end openTab
    """

    static let tabOpened = "done"

    static let warnedAccessibilityKey = "warnedTerminalTabAccessibility"

    func open(directory: URL, command: String, mode: OpenMode) throws {
        let wasRunning = LauncherFactory.isRunning(.appleTerminal)
        let runner = try AppleScriptRunner(source: Self.source, target: "Terminal")

        if mode == .newTab && wasRunning && openInNewTab(command, runner: runner) {
            return
        }
        try runner.call("openWindow", [command, wasRunning ? "1" : "0"])
    }

    /// Tries the experimental ⌘T route. Returns `false` when the caller should open a new
    /// window instead: no Accessibility permission, System Events automation denied, or no
    /// new tab appeared.
    private func openInNewTab(_ command: String, runner: AppleScriptRunner) -> Bool {
        guard AXIsProcessTrusted() else {
            Log.app.notice("Terminal new tab needs Accessibility; falling back to new window")
            warnAboutAccessibilityOnce()
            return false
        }
        do {
            if try runner.call("openTab", [command]).stringValue == Self.tabOpened {
                return true
            }
            Log.app.notice("Terminal new tab did not appear; falling back to new window")
        } catch {
            // Typically System Events automation denied (-1743). If Terminal itself is the
            // problem, the new-window call that follows reports it against the right app.
            Log.app.notice("Terminal new tab failed (\(String(describing: error), privacy: .public)); falling back to new window")
        }
        return false
    }

    /// Asks once for Accessibility permission (prompt shows the system dialog).
    private func warnAboutAccessibilityOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.warnedAccessibilityKey) else { return }
        defaults.set(true, forKey: Self.warnedAccessibilityKey)
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
