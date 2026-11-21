import Foundation
import Testing
@testable import Go2TermCore

@Suite struct LegacyMigrationTests {
    @Test func currentUserConfig() {
        let s = LegacyMigration.settings(fromLegacy: [
            "Terminal Identifier": "com.googlecode.iterm2",
            "Terminal Command": "cd %PATH%; clear; pwd",
            "Use Window": NSNumber(value: 0),
        ])
        #expect(s?.terminal == .iTerm2)
        #expect(s?.commandTemplate == "cd %PATH%; clear; pwd")
        #expect(s?.openMode == .newWindow)
    }

    @Test func legacyITermIdentifier() {
        #expect(LegacyMigration.settings(fromLegacy: ["Terminal Identifier": "net.sourceforge.iTerm"])?.terminal == .iTerm2)
    }

    @Test func appleTerminal() {
        #expect(LegacyMigration.settings(fromLegacy: ["Terminal Identifier": "com.apple.Terminal"])?.terminal == .appleTerminal)
    }

    @Test func unknownTerminalKeepsDefault() {
        #expect(LegacyMigration.settings(fromLegacy: ["Terminal Identifier": "com.example.term"])?.terminal == .appleTerminal)
    }

    @Test func missingFieldsKeepDefaults() {
        let s = LegacyMigration.settings(fromLegacy: ["Terminal Identifier": "com.googlecode.iterm2"])
        #expect(s?.commandTemplate == CommandTemplate.defaultTemplate)
        #expect(s?.openMode == .newWindow)
    }

    @Test func noLegacyKeysReturnsNil() {
        #expect(LegacyMigration.settings(fromLegacy: ["SUHasLaunchedBefore": true]) == nil)
        #expect(LegacyMigration.settings(fromLegacy: [:]) == nil)
    }

    @Test func useWindowOneMeansNewTab() {
        let s = LegacyMigration.settings(fromLegacy: ["Terminal Identifier": "com.googlecode.iterm2", "Use Window": 1])
        #expect(s?.openMode == .newTab)
    }

    @Test func useWindowAsString() {
        #expect(LegacyMigration.settings(fromLegacy: ["Use Window": "1", "Terminal Identifier": "com.apple.Terminal"])?.openMode == .newTab)
    }

    @Test func quotedPlaceholderIsNormalized() {
        #expect(LegacyMigration.settings(fromLegacy: ["Terminal Command": "cd \"%PATH%\"; ls"])?.commandTemplate == "cd %PATH%; ls")
    }
}
