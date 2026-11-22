import Foundation
import Go2TermCore

/// One-time import of legacy Go2Shell preferences (REQ-APP-04).
@MainActor
enum LegacyImporter {
    static func runIfNeeded(store: SettingsStore) {
        var settings = store.load()
        guard !settings.didMigrate else { return }

        if let legacy = readLegacyDomain(), let migrated = LegacyMigration.settings(fromLegacy: legacy, base: settings) {
            settings = migrated
            Log.app.notice("migrated Go2Shell settings: terminal=\(settings.terminal.rawValue, privacy: .public) mode=\(settings.openMode.rawValue, privacy: .public)")
        } else {
            Log.app.info("no Go2Shell settings to migrate")
        }
        settings.didMigrate = true
        store.save(settings)
    }

    /// Reads `com.zipzapmac.Go2Shell` via cfprefsd, falling back to `defaults export`.
    static func readLegacyDomain() -> [String: Any]? {
        if let domain = UserDefaults.standard.persistentDomain(forName: LegacyMigration.legacyDomain), !domain.isEmpty {
            return domain
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["export", LegacyMigration.legacyDomain, "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
