import Testing
@testable import Go2ShellCore

@Suite struct CommandTemplateTests {
    let path = "/Users/you/My Project"

    @Test func defaultTemplate() {
        #expect(CommandTemplate(CommandTemplate.defaultTemplate).render(path: path)
            == "cd '/Users/you/My Project'; clear; pwd")
    }

    @Test func templateWithoutPlaceholderGetsCdPrefix() {
        #expect(CommandTemplate("ls -la").render(path: path) == "cd '/Users/you/My Project'; ls -la")
    }

    @Test func multiplePlaceholders() {
        #expect(CommandTemplate("cd %PATH%; echo %PATH%").render(path: "/a b")
            == "cd '/a b'; echo '/a b'")
    }

    @Test func emptyTemplateBehavesLikeCd() {
        #expect(CommandTemplate("").render(path: path) == "cd '/Users/you/My Project'")
    }

    @Test func whitespaceTemplateBehavesLikeCd() {
        #expect(CommandTemplate("  \n ").render(path: "/x") == "cd '/x'")
    }

    @Test func pathWithQuoteIsQuoted() {
        #expect(CommandTemplate("cd %PATH%").render(path: "/it's") == #"cd '/it'\''s'"#)
    }

    @Test func normalizeStripsDoubleQuotes() {
        #expect(CommandTemplate.normalize("cd \"%PATH%\"; clear") == "cd %PATH%; clear")
    }

    @Test func normalizeStripsSingleQuotes() {
        #expect(CommandTemplate.normalize("cd '%PATH%'; pwd") == "cd %PATH%; pwd")
    }

    @Test func normalizeLeavesBareTemplateAlone() {
        #expect(CommandTemplate.normalize(CommandTemplate.defaultTemplate) == CommandTemplate.defaultTemplate)
    }
}
