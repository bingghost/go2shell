import Foundation

/// Runs handlers of a *constant* AppleScript source, passing runtime values as
/// Apple Event parameters. Runtime strings are never spliced into script source,
/// which rules out AppleScript injection (docs/02-TECH-DESIGN.md §3.2).
@MainActor
public final class AppleScriptRunner {
    private let script: NSAppleScript
    private let target: String

    /// - Parameters:
    ///   - source: constant script source containing `on handlerName(...)` definitions.
    ///   - target: human-readable name of the app the script talks to, used in errors.
    public init(source: String, target: String) throws {
        guard let script = NSAppleScript(source: source) else {
            throw Go2ShellError.scriptFailed(code: 0, message: "Could not create script")
        }
        var errorInfo: NSDictionary?
        guard script.compileAndReturnError(&errorInfo) else {
            throw Self.error(from: errorInfo, target: target)
        }
        self.script = script
        self.target = target
    }

    /// Calls `handler` with string arguments and returns the result descriptor.
    @discardableResult
    public func call(_ handler: String, _ arguments: [String] = []) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: FourCC.appleScriptSuite,
            eventID: FourCC.subroutineEvent,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        // AppleScript stores handler names in lower case.
        event.setDescriptor(NSAppleEventDescriptor(string: handler.lowercased()), forKeyword: FourCC.subroutineName)

        let list = NSAppleEventDescriptor.list()
        for (index, argument) in arguments.enumerated() {
            list.insert(NSAppleEventDescriptor(string: argument), at: index + 1)
        }
        event.setParam(list, forKeyword: keyDirectObject)

        var errorInfo: NSDictionary?
        let result = script.executeAppleEvent(event, error: &errorInfo)
        if let errorInfo {
            throw Self.error(from: errorInfo, target: target)
        }
        return result
    }

    static func error(from info: NSDictionary?, target: String) -> Go2ShellError {
        let code = (info?[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
        let message = info?[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        return Go2ShellError.fromAppleScript(code: code, message: message, target: target)
    }
}

/// Four-character codes from OpenScripting / AE headers (avoids importing Carbon).
enum FourCC {
    static let appleScriptSuite = code("ascr")   // kASAppleScriptSuite
    static let subroutineEvent = code("psbr")    // kASSubroutineEvent
    static let subroutineName = code("snam")     // keyASSubroutineName

    static func code(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }
}
