/// What the app should do for a given launch.
public enum LaunchAction: Equatable, Sendable {
    case showSettings
    /// Open a terminal; `explicitPath` comes from `--open <path>`, `nil` means "ask Finder".
    case openTerminal(explicitPath: String?)
    case printFinderPath
}

public struct LaunchContext: Equatable, Sendable {
    public var arguments: [String]
    public var frontmostBundleID: String?
    public var optionKeyDown: Bool

    public init(arguments: [String], frontmostBundleID: String?, optionKeyDown: Bool) {
        self.arguments = arguments
        self.frontmostBundleID = frontmostBundleID
        self.optionKeyDown = optionKeyDown
    }
}

/// Routing rules, in priority order (docs/02-TECH-DESIGN.md §3.1):
/// 1. `--print-finder-path` → print Finder path (debug)
/// 2. `--open <path>` → open terminal at path
/// 3. `--settings` or ⌥ held → settings
/// 4. Finder frontmost → open terminal at Finder location
/// 5. otherwise → settings
public enum LaunchRouter {
    public static let finderBundleID = "com.apple.finder"

    public static func route(_ context: LaunchContext) -> LaunchAction {
        let args = context.arguments
        if args.contains("--print-finder-path") {
            return .printFinderPath
        }
        if let index = args.firstIndex(of: "--open"), index + 1 < args.count {
            return .openTerminal(explicitPath: args[index + 1])
        }
        if args.contains("--settings") || context.optionKeyDown {
            return .showSettings
        }
        if context.frontmostBundleID == finderBundleID {
            return .openTerminal(explicitPath: nil)
        }
        return .showSettings
    }
}
