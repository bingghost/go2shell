import Testing
@testable import Go2ShellCore

@Test func bundleIdentifierIsStable() {
    #expect(Go2ShellInfo.bundleIdentifier == "com.bingghost.Go2Shell")
}
