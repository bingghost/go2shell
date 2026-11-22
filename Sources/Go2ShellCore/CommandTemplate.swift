import Foundation


/// A user-editable shell command with a `%PATH%` placeholder.
public struct CommandTemplate: Equatable, Sendable {
    public static let placeholder = "%PATH%"
    public static let defaultTemplate = "cd %PATH%; clear; pwd"

    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    /// Renders the command for `path`.
    ///
    /// - Every `%PATH%` is replaced by the shell-quoted path.
    /// - An empty (or whitespace-only) template behaves like `cd %PATH%`.
    /// - A template without the placeholder gets `cd <path>; ` prepended so the shell
    ///   still starts in the right directory.
    public func render(path: String) -> String {
        let quoted = ShellQuote.quote(path)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "cd \(quoted)"
        }
        if raw.contains(Self.placeholder) {
            return raw.replacingOccurrences(of: Self.placeholder, with: quoted)
        }
        return "cd \(quoted); \(raw)"
    }

    /// Strips quotes the user (or legacy Go2Shell) put around the placeholder,
    /// since `render` already quotes the path: `cd "%PATH%"` → `cd %PATH%`.
    public static func normalize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\"\(placeholder)\"", with: placeholder)
            .replacingOccurrences(of: "'\(placeholder)'", with: placeholder)
    }
}

