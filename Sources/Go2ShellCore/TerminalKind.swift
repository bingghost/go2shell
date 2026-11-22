/// Terminal applications Go2Shell knows how to drive.
///
/// Bundle identifiers and capabilities for third-party terminals are verified in M6;
/// see docs/02-TECH-DESIGN.md §3.1.
public enum TerminalKind: String, CaseIterable, Codable, Sendable {
    case appleTerminal
    case iTerm2
    case ghostty
    case wezterm
    case kitty
    case alacritty
    case warp

    /// Known bundle identifiers; the first is preferred, later ones are historical aliases.
    public var bundleIdentifiers: [String] {
        switch self {
        case .appleTerminal: ["com.apple.Terminal"]
        case .iTerm2: ["com.googlecode.iterm2", "net.sourceforge.iTerm"]
        case .ghostty: ["com.mitchellh.ghostty"]
        case .wezterm: ["com.github.wez.wezterm"]
        case .kitty: ["net.kovidgoyal.kitty"]
        case .alacritty: ["org.alacritty", "io.alacritty"]
        case .warp: ["dev.warp.Warp-Stable"]
        }
    }

    public var primaryBundleIdentifier: String { bundleIdentifiers[0] }

    public var displayName: String {
        switch self {
        case .appleTerminal: "Terminal"
        case .iTerm2: "iTerm2"
        case .ghostty: "Ghostty"
        case .wezterm: "WezTerm"
        case .kitty: "kitty"
        case .alacritty: "Alacritty"
        case .warp: "Warp"
        }
    }

    /// Whether the command template can be executed in the new session.
    public var supportsCommand: Bool {
        switch self {
        case .appleTerminal, .iTerm2: true
        default: false
        }
    }

    /// Whether "open in new tab" is available.
    public var supportsNewTab: Bool {
        switch self {
        case .appleTerminal, .iTerm2: true
        default: false
        }
    }

    /// New-tab support that relies on simulated keystrokes (needs Accessibility permission).
    public var newTabIsExperimental: Bool { self == .appleTerminal }

    /// Arguments that start a new instance in `directory`, for terminals launched by argument.
    /// `nil` means "open the folder with the app" (Ghostty, Warp) or AppleScript (Terminal, iTerm2).
    public func workingDirectoryArguments(_ directory: String) -> [String]? {
        switch self {
        case .wezterm: ["start", "--cwd", directory]
        case .kitty: ["--directory", directory]
        case .alacritty: ["--working-directory", directory]
        default: nil
        }
    }

    /// Finds the kind for a bundle identifier (case-insensitive), including aliases.
    public init?(bundleIdentifier: String) {
        let needle = bundleIdentifier.lowercased()
        guard let match = Self.allCases.first(where: { kind in
            kind.bundleIdentifiers.contains { $0.lowercased() == needle }
        }) else { return nil }
        self = match
    }
}
