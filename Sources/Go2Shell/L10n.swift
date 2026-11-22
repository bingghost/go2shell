import Foundation

/// Localized string from Contents/Resources/<lang>.lproj/Localizable.strings.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

/// Localized format string with arguments.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
