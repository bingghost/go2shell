public enum Go2ShellError: Error, Equatable, Sendable {
    case automationDenied(target: String)
    case targetNotRunning(target: String)
    case notFileSystem
    case pathNotFound(String)
    case terminalNotFound(TerminalKind)
    case scriptFailed(code: Int, message: String)

    /// Maps an AppleScript / Apple Event error number to a `Go2ShellError`.
    public static func fromAppleScript(code: Int, message: String, target: String) -> Go2ShellError {
        switch code {
        case -1743: .automationDenied(target: target)   // errAEEventNotPermitted
        case -600, -609: .targetNotRunning(target: target) // procNotFound, connectionInvalid
        default: .scriptFailed(code: code, message: message)
        }
    }
}
