import Foundation

/// Converts preferences of the legacy Go2Shell app (`com.zipzapmac.Go2Shell`) into `Settings`.
public enum LegacyMigration {
    public static let legacyDomain = "com.zipzapmac.Go2Shell"

    public enum LegacyKey {
        public static let terminalIdentifier = "Terminal Identifier"
        public static let terminalCommand = "Terminal Command"
        public static let useWindow = "Use Window"
    }

    /// Returns migrated settings, or `nil` when the dictionary holds no Go2Shell preferences.
    ///
    /// `Use Window`: assumed `0` = new window, non-zero = new tab (to be confirmed in M5).
    public static func settings(fromLegacy legacy: [String: Any], base: Settings = Settings()) -> Settings? {
        let identifier = legacy[LegacyKey.terminalIdentifier] as? String
        let command = legacy[LegacyKey.terminalCommand] as? String
        let useWindow = legacy[LegacyKey.useWindow]
        guard identifier != nil || command != nil || useWindow != nil else { return nil }

        var result = base
        if let identifier, let kind = TerminalKind(bundleIdentifier: identifier) {
            result.terminal = kind
        }
        if let command {
            result.commandTemplate = CommandTemplate.normalize(command)
        }
        if let flag = intValue(useWindow) {
            result.openMode = flag == 0 ? .newWindow : .newTab
        }
        if !result.terminal.supportsNewTab {
            result.openMode = .newWindow
        }
        return result
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: number.intValue
        case let int as Int: int
        case let bool as Bool: bool ? 1 : 0
        case let string as String: Int(string)
        default: nil
        }
    }
}
