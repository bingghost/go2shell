import AppKit
import Go2ShellCore
import Observation

/// Observable wrapper around `SettingsStore`; every change is saved immediately.
@MainActor
@Observable
final class SettingsModel {
    private let store: SettingsStore
    private(set) var settings: Settings

    init(store: SettingsStore = UserDefaultsSettingsStore()) {
        self.store = store
        settings = store.load()
        installedTerminals = TerminalKind.allCases.filter(LauncherFactory.isInstalled)
    }

    /// Terminals found on this Mac, in catalog order.
    let installedTerminals: [TerminalKind]

    var terminal: TerminalKind {
        get { settings.terminal }
        set {
            settings.terminal = newValue
            if !newValue.supportsNewTab { settings.openMode = .newWindow }
            save()
        }
    }

    var commandTemplate: String {
        get { settings.commandTemplate }
        set { settings.commandTemplate = newValue; save() }
    }

    var openMode: OpenMode {
        get { settings.openMode }
        set { settings.openMode = newValue; save() }
    }

    var preferSelectedFolder: Bool {
        get { settings.preferSelectedFolder }
        set { settings.preferSelectedFolder = newValue; save() }
    }

    /// True when the stored terminal is missing and launches fall back to Terminal.app.
    var configuredTerminalMissing: Bool { !installedTerminals.contains(settings.terminal) }

    static let previewPath = "/Users/you/My Project"
    var commandPreview: String { CommandTemplate(settings.commandTemplate).render(path: Self.previewPath) }

    func resetCommand() { commandTemplate = CommandTemplate.defaultTemplate }

    func icon(for kind: TerminalKind) -> NSImage? {
        guard let url = LauncherFactory.applicationURL(for: kind) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 20, height: 20)
        return image
    }

    private func save() { store.save(settings) }
}
