/// POSIX shell quoting.
///
/// Wraps the whole string in single quotes. Inside single quotes nothing is special
/// except `'` itself, which is emitted as `'\''` (close, escaped quote, reopen).
/// This is safe for every byte sequence, including newlines, `$`, backticks and backslashes.
public enum ShellQuote {
    public static func quote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
