import Foundation

public enum OpenMode: String, Codable, CaseIterable, Sendable {
    case newWindow
    case newTab
}

/// User preferences. Defaults match the PRD (Terminal.app, `cd %PATH%; clear; pwd`, new window).
public struct Settings: Codable, Equatable, Sendable {
    public var terminal: TerminalKind
    public var commandTemplate: String
    public var openMode: OpenMode
    public var preferSelectedFolder: Bool
    public var didMigrate: Bool

    public init(
        terminal: TerminalKind = .appleTerminal,
        commandTemplate: String = CommandTemplate.defaultTemplate,
        openMode: OpenMode = .newWindow,
        preferSelectedFolder: Bool = false,
        didMigrate: Bool = false
    ) {
        self.terminal = terminal
        self.commandTemplate = commandTemplate
        self.openMode = openMode
        self.preferSelectedFolder = preferSelectedFolder
        self.didMigrate = didMigrate
    }
}

public protocol SettingsStore {
    func load() -> Settings
    func save(_ settings: Settings)
}

/// Stores each field under its own key so `defaults read com.bingghost.Go2Term` stays readable.
public final class UserDefaultsSettingsStore: SettingsStore {
    public enum Key {
        public static let terminal = "terminal"
        public static let commandTemplate = "commandTemplate"
        public static let openMode = "openMode"
        public static let preferSelectedFolder = "preferSelectedFolder"
        public static let didMigrate = "didMigrate"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        let fallback = Settings()
        return Settings(
            terminal: defaults.string(forKey: Key.terminal).flatMap(TerminalKind.init(rawValue:)) ?? fallback.terminal,
            commandTemplate: defaults.string(forKey: Key.commandTemplate) ?? fallback.commandTemplate,
            openMode: defaults.string(forKey: Key.openMode).flatMap(OpenMode.init(rawValue:)) ?? fallback.openMode,
            preferSelectedFolder: defaults.object(forKey: Key.preferSelectedFolder) as? Bool ?? fallback.preferSelectedFolder,
            didMigrate: defaults.object(forKey: Key.didMigrate) as? Bool ?? fallback.didMigrate
        )
    }

    public func save(_ settings: Settings) {
        defaults.set(settings.terminal.rawValue, forKey: Key.terminal)
        defaults.set(settings.commandTemplate, forKey: Key.commandTemplate)
        defaults.set(settings.openMode.rawValue, forKey: Key.openMode)
        defaults.set(settings.preferSelectedFolder, forKey: Key.preferSelectedFolder)
        defaults.set(settings.didMigrate, forKey: Key.didMigrate)
    }
}
