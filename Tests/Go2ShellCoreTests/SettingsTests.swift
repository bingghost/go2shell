import Foundation
import Testing
@testable import Go2ShellCore

@Suite struct SettingsTests {
    @Test func defaults() {
        let s = Settings()
        #expect(s.terminal == .appleTerminal)
        #expect(s.commandTemplate == "cd %PATH%; clear; pwd")
        #expect(s.openMode == .newWindow)
        #expect(!s.preferSelectedFolder)
        #expect(!s.didMigrate)
    }

    @Test func codableRoundTrip() throws {
        let s = Settings(terminal: .iTerm2, commandTemplate: "cd %PATH%", openMode: .newTab,
                         preferSelectedFolder: true, didMigrate: true)
        let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        #expect(decoded == s)
    }

    private func makeStore() -> (UserDefaultsSettingsStore, UserDefaults, String) {
        let suite = "go2shell.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (UserDefaultsSettingsStore(defaults: defaults), defaults, suite)
    }

    @Test func emptyStoreLoadsDefaults() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.load() == Settings())
    }

    @Test func storeRoundTrip() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        let s = Settings(terminal: .iTerm2, commandTemplate: "pwd", openMode: .newTab,
                         preferSelectedFolder: true, didMigrate: true)
        store.save(s)
        #expect(store.load() == s)
        #expect(defaults.string(forKey: "terminal") == "iTerm2")
        #expect(defaults.string(forKey: "openMode") == "newTab")
    }

    @Test func invalidStoredValuesFallBack() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("bogus", forKey: "terminal")
        defaults.set("sideways", forKey: "openMode")
        #expect(store.load().terminal == .appleTerminal)
        #expect(store.load().openMode == .newWindow)
    }
}
