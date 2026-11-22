import AppKit
import Go2TermCore

/// Turns `Go2TermError`s into alerts (docs/02-TECH-DESIGN.md §3.6).
@MainActor
enum ErrorPresenter {
    static let automationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!

    static func present(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        var opensSettings = false

        switch error as? Go2TermError {
        case .automationDenied(let target):
            alert.messageText = L("error.automationDenied.title", target)
            alert.informativeText = L("error.automationDenied.body", target)
            alert.addButton(withTitle: L("button.openSystemSettings"))
            alert.addButton(withTitle: L("button.ok"))
            opensSettings = true
        case .notFileSystem:
            alert.messageText = L("error.notFileSystem.title")
            alert.informativeText = L("error.notFileSystem.body")
            alert.addButton(withTitle: L("button.ok"))
        case .pathNotFound(let path):
            alert.messageText = L("error.pathNotFound.title")
            alert.informativeText = path
            alert.addButton(withTitle: L("button.ok"))
        case .targetNotRunning(let target):
            alert.messageText = L("error.targetNotRunning.title", target)
            alert.addButton(withTitle: L("button.ok"))
        case .terminalNotFound(let kind):
            // Factory already fell back to Terminal.app; nothing to show.
            Log.app.notice("terminal not found: \(kind.rawValue, privacy: .public)")
            return
        case .scriptFailed(let code, let message):
            alert.messageText = L("error.scriptFailed.title")
            alert.informativeText = "\(message) (\(code))"
            alert.addButton(withTitle: L("button.ok"))
        case nil:
            alert.messageText = L("error.scriptFailed.title")
            alert.informativeText = String(describing: error)
            alert.addButton(withTitle: L("button.ok"))
        }

        NSApp.activate()
        let response = alert.runModal()
        if opensSettings && response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(automationSettingsURL)
        }
    }
}
