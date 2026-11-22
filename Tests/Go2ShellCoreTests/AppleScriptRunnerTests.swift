import Foundation
import Testing
@testable import Go2ShellCore

@MainActor
@Suite struct AppleScriptRunnerTests {
    let source = """
    on echo(x)
        return x
    end echo
    on joinTwo(a, b)
        return a & "|" & b
    end joinTwo
    on fail()
        error "boom" number -1728
    end fail
    """

    @Test(arguments: [
        "plain",
        "",
        "quote \" inside",
        #"back\slash"#,
        "\" & (do shell script \"echo pwned\") & \"",
        "line1\nline2\rline3",
        "$HOME `x` 'y'",
        "中文 🚀",
    ])
    func echoRoundTrip(_ value: String) throws {
        let runner = try AppleScriptRunner(source: source, target: "test")
        #expect(try runner.call("echo", [value]).stringValue == value)
    }

    @Test func multipleArguments() throws {
        let runner = try AppleScriptRunner(source: source, target: "test")
        #expect(try runner.call("joinTwo", ["a b", "c\"d"]).stringValue == "a b|c\"d")
    }

    @Test func handlerNameIsCaseInsensitive() throws {
        let runner = try AppleScriptRunner(source: source, target: "test")
        #expect(try runner.call("ECHO", ["x"]).stringValue == "x")
    }

    @Test func scriptErrorsAreMapped() throws {
        let runner = try AppleScriptRunner(source: source, target: "test")
        #expect(throws: Go2ShellError.scriptFailed(code: -1728, message: "boom")) {
            try runner.call("fail")
        }
    }

    @Test func compileErrorThrows() {
        #expect(throws: Go2ShellError.self) {
            try AppleScriptRunner(source: "on broken(\n", target: "test")
        }
    }

    @Test func fourCCValues() {
        #expect(FourCC.code("ascr") == 0x61736372)
        #expect(FourCC.code("psbr") == 0x70736272)
    }
}
