import Foundation

/// Reads macOS Notification Center banners through their accessibility data.
public enum BannerText {
    /// Banner subroles on macOS 14, 15 and 26 ("Temporary" banners and "Persistent" alerts,
    /// alone or stacked). Matched in full: a prefix would also catch AXNotificationCenterNextFocus.
    public static let subroles: Set<String> = [
        "AXNotificationCenterBanner", "AXNotificationCenterBannerStack",
        "AXNotificationCenterAlert", "AXNotificationCenterAlertStack",
    ]

    /// The posting app's name: a banner's description reads "App, Title, Body".
    public static func appName(fromDescription description: String) -> String? {
        let name = description.components(separatedBy: ", ").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    /// The visible label of an AX action. Custom actions look like
    /// "Name:Close\nTarget:0x0\nSelector:(null)".
    public static func actionLabel(_ raw: String) -> String {
        guard raw.hasPrefix("Name:") else { return raw }
        let rest = raw.dropFirst("Name:".count)
        return String(rest.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
    }

    /// The one action whose label is "Close" in any language. Nil when none match, or when
    /// more than one does (an app can name its own action "Close").
    public static func closeAction(in actions: [String], closeNames: Set<String>) -> String? {
        let names = Set(closeNames.map { $0.lowercased() })
        let matches = actions.filter { names.contains(actionLabel($0).lowercased()) }
        return matches.count == 1 ? matches[0] : nil
    }
}
