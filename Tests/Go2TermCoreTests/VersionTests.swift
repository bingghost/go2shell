import Testing
@testable import Go2TermCore

@Test func bundleIdentifierIsStable() {
    #expect(Go2TermInfo.bundleIdentifier == "com.bingghost.Go2Term")
    #expect(Go2TermInfo.appName == "Go2Term")
}
