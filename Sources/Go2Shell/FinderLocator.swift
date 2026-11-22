import Foundation
import Go2ShellCore

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

    on selectedItemPath()
        tell application id "com.apple.finder"
            try
                set sel to selection as alias list
            on error errMsg number errNum
                if errNum is -1743 then error errMsg number errNum
                return ""
            end try
            if (count of sel) is not 1 then return ""
            return POSIX path of (item 1 of sel)
        end tell
    end selectedItemPath
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
            throw Go2ShellError.notFileSystem
        default:
            return try Self.validatedDirectory(path: raw)
        }
    }

    /// The single selected item when it is a plain folder (not a package such as an .app).
    func selectedFolder() throws -> URL? {
        let raw = try runner.call("selectedItemPath").stringValue ?? ""
        guard !raw.isEmpty else { return nil }
        let url = URL(fileURLWithPath: raw).standardizedFileURL
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values?.isDirectory == true, values?.isPackage != true else { return nil }
        return url
    }

    /// Ensures `path` exists; a file resolves to its parent folder.
    static func validatedDirectory(path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw Go2ShellError.pathNotFound(path)
        }
        return isDirectory.boolValue ? url : url.deletingLastPathComponent()
    }
}
