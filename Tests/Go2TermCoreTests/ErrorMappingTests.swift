import Testing
@testable import Go2TermCore

@Suite struct ErrorMappingTests {
    @Test func notPermitted() {
        #expect(Go2TermError.fromAppleScript(code: -1743, message: "x", target: "Finder") == .automationDenied(target: "Finder"))
    }
    @Test func notRunning() {
        #expect(Go2TermError.fromAppleScript(code: -600, message: "x", target: "iTerm2") == .targetNotRunning(target: "iTerm2"))
        #expect(Go2TermError.fromAppleScript(code: -609, message: "x", target: "iTerm2") == .targetNotRunning(target: "iTerm2"))
    }
    @Test func otherCodes() {
        #expect(Go2TermError.fromAppleScript(code: -1728, message: "Can't get", target: "Finder") == .scriptFailed(code: -1728, message: "Can't get"))
    }
}
