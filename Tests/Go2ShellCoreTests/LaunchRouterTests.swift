import Testing
@testable import Go2ShellCore

@Suite struct LaunchRouterTests {
    let exe = "/Applications/Go2Shell.app/Contents/MacOS/Go2Shell"

    func route(_ args: [String] = [], front: String? = nil, option: Bool = false) -> LaunchAction {
        LaunchRouter.route(LaunchContext(arguments: [exe] + args, frontmostBundleID: front, optionKeyDown: option))
    }

    @Test func finderFrontmostOpensTerminal() { #expect(route(front: "com.apple.finder") == .openTerminal(explicitPath: nil)) }
    @Test func otherAppFrontmostShowsSettings() { #expect(route(front: "com.apple.dt.Xcode") == .showSettings) }
    @Test func noFrontmostShowsSettings() { #expect(route() == .showSettings) }
    @Test func optionKeyShowsSettings() { #expect(route(front: "com.apple.finder", option: true) == .showSettings) }
    @Test func settingsFlag() { #expect(route(["--settings"], front: "com.apple.finder") == .showSettings) }
    @Test func openFlag() { #expect(route(["--open", "/tmp/a b"]) == .openTerminal(explicitPath: "/tmp/a b")) }
    @Test func openFlagBeatsSettingsAndOption() {
        #expect(route(["--settings", "--open", "/x"], option: true) == .openTerminal(explicitPath: "/x"))
    }
    @Test func openFlagWithoutPathIsIgnored() { #expect(route(["--open"], front: "com.apple.finder") == .openTerminal(explicitPath: nil)) }
    @Test func printFinderPathHasTopPriority() {
        #expect(route(["--open", "/x", "--print-finder-path", "--settings"], option: true) == .printFinderPath)
    }
    @Test func unrelatedArgumentsIgnored() {
        // Launch Services may pass -psn_… or -NSDocumentRevisionsDebugMode.
        #expect(route(["-psn_0_12345"], front: "com.apple.finder") == .openTerminal(explicitPath: nil))
    }
}
