import Foundation
import Go2TermCore

/// Asks Finder which folder its front window shows (docs/02-TECH-DESIGN.md §3.3).
@MainActor
final class FinderLocator {
    static let noWindow = "::NO_WINDOW::"
    static let notFileSystem = "::NOT_FILESYSTEM::"

    // Constant source: runtime values never enter this string.
    private static let source = """
    on frontWindowPath()
        tell application id "com.apple.finder"
            if (count of Finder windows) is 0 then return "::NO_WINDOW::"
            try
                return POSIX path of ((target of front Finder window) as alias)
            on error errMsg number errNum
                if errNum is -1743 then error errMsg number errNum
                return "::NOT_FILESYSTEM::"
            end try
        end tell
    end frontWindowPath
    """

    private let runner: AppleScriptRunner

    init() throws {
        runner = try AppleScriptRunner(source: Self.source, target: "Finder")
    }

    /// Directory of the front Finder window; `~/Desktop` when no window is open.
    func frontWindowDirectory() throws -> URL {
        let raw = try runner.call("frontWindowPath").stringValue ?? Self.notFileSystem
        switch raw {
        case Self.noWindow:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop", isDirectory: true)
        case Self.notFileSystem:
            throw Go2TermError.notFileSystem
        default:
            return try Self.validatedDirectory(path: raw)
        }
    }

    /// Ensures `path` exists; a file resolves to its parent folder.
    static func validatedDirectory(path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw Go2TermError.pathNotFound(path)
        }
        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }
}
