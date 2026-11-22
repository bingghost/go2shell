import Testing
@testable import Go2ShellCore

@Suite struct TerminalKindTests {
    @Test func hasSevenTerminals() { #expect(TerminalKind.allCases.count == 7) }

    @Test(arguments: TerminalKind.allCases)
    func metadataIsComplete(_ kind: TerminalKind) {
        #expect(!kind.bundleIdentifiers.isEmpty)
        #expect(!kind.displayName.isEmpty)
        #expect(kind.primaryBundleIdentifier == kind.bundleIdentifiers[0])
        #expect(TerminalKind(bundleIdentifier: kind.primaryBundleIdentifier) == kind)
        #expect(TerminalKind(rawValue: kind.rawValue) == kind)
    }

    @Test func bundleIdentifiersAreUnique() {
        let all = TerminalKind.allCases.flatMap(\.bundleIdentifiers).map { $0.lowercased() }
        #expect(Set(all).count == all.count)
    }

    @Test func iTermAliasesResolve() {
        #expect(TerminalKind(bundleIdentifier: "net.sourceforge.iTerm") == .iTerm2)
        #expect(TerminalKind(bundleIdentifier: "COM.GOOGLECODE.ITERM2") == .iTerm2)
    }

    @Test func unknownBundleIdentifier() { #expect(TerminalKind(bundleIdentifier: "com.example.nope") == nil) }

    @Test func capabilities() {
        #expect(TerminalKind.iTerm2.supportsCommand && TerminalKind.iTerm2.supportsNewTab)
        #expect(TerminalKind.appleTerminal.supportsCommand && TerminalKind.appleTerminal.supportsNewTab)
        #expect(TerminalKind.appleTerminal.newTabIsExperimental)
        #expect(!TerminalKind.iTerm2.newTabIsExperimental)
        #expect(!TerminalKind.ghostty.supportsCommand)
    }

    @Test func workingDirectoryArguments() {
        let dir = "/a b/it's"
        #expect(TerminalKind.wezterm.workingDirectoryArguments(dir) == ["start", "--cwd", dir])
        #expect(TerminalKind.kitty.workingDirectoryArguments(dir) == ["--directory", dir])
        #expect(TerminalKind.alacritty.workingDirectoryArguments(dir) == ["--working-directory", dir])
        #expect(TerminalKind.ghostty.workingDirectoryArguments(dir) == nil)
        #expect(TerminalKind.warp.workingDirectoryArguments(dir) == nil)
        #expect(TerminalKind.iTerm2.workingDirectoryArguments(dir) == nil)
    }
}
