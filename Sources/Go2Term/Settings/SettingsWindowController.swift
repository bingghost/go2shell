import AppKit
import Go2TermCore
import SwiftUI

/// Hosts the SwiftUI settings view in an AppKit window.
@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init(testAction: @escaping () -> Void) {
        let model = SettingsModel()
        let hosting = NSHostingController(rootView: SettingsView(model: model, testAction: testAction))
        let window = NSWindow(contentViewController: hosting)
        window.title = L("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
}
