import Foundation

/// Bundle ID matching shared by every rule in the app, so detection, protection and
/// muting always agree.
public enum BundleID {
    /// True when `id` is `base` or one of its helpers (`base.helper`, `base.Renderer`…),
    /// ignoring case. `com.google.Chrome.helper` matches `com.google.Chrome`;
    /// `org.mozilla.firefoxdeveloperedition` does not match `org.mozilla.firefox`.
    public static func matches(_ id: String, base: String) -> Bool {
        let id = id.lowercased(), base = base.lowercased()
        return id == base || id.hasPrefix(base + ".")
    }

    public static func matchesAny<S: Sequence>(_ id: String, _ bases: S) -> Bool where S.Element == String {
        bases.contains { matches(id, base: $0) }
    }

    /// Exact match, ignoring case.
    public static func equal(_ a: String, _ b: String) -> Bool {
        a.caseInsensitiveCompare(b) == .orderedSame
    }
}
