import Foundation
import Testing
@testable import Go2TermCore

/// Runs `printf %s <quoted>` through /bin/sh and returns stdout verbatim.
func shellRoundTrip(_ value: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "printf %s \(ShellQuote.quote(value))"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
    return String(decoding: data, as: UTF8.self)
}

@Suite struct ShellQuoteTests {
    @Test func plainString() { #expect(ShellQuote.quote("abc") == "'abc'") }
    @Test func emptyString() { #expect(ShellQuote.quote("") == "''") }
    @Test func singleQuoteIsEscaped() { #expect(ShellQuote.quote("it's") == #"'it'\''s'"#) }
    @Test func onlySingleQuotes() { #expect(ShellQuote.quote("''") == #"''\'''\'''"#) }

    @Test(arguments: [
        "",
        "/Users/you/My Project",
        "it's",
        "say \"hi\"",
        "$HOME",
        "${PATH}",
        "`whoami`",
        "$(whoami)",
        #"back\slash"#,
        "line1\nline2",
        "tab\there",
        "🚀rocket",
        "中文 目录",
        "-dash",
        "--help",
        "semi;colon && pipe | amp & redirect > < glob * ? [x] {a,b} ~ # !",
        "'''mixed\"\"\"$`\\\n",
    ])
    func roundTripsThroughShell(_ value: String) throws {
        #expect(try shellRoundTrip(value) == value)
    }

    @Test func cdIntoQuotedDirectoryWorks() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("go2term-quote-\(UUID().uuidString)")
        let dir = base.appendingPathComponent("it's $HOME `x`\nnew line 🚀")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", CommandTemplate("cd %PATH% && printf %s \"$PWD\"").render(path: dir.path)]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        // $PWD may resolve /var → /private/var.
        #expect(out.hasSuffix(dir.lastPathComponent))
        #expect(process.terminationStatus == 0)
    }
}
