import Foundation

/// An app known to interrupt at the start of a call. The list lives in
/// `registry/apps.json`; `scripts/gen_registry.py` turns it into `Registry+Apps.swift`.
public struct KnownApp: Sendable, Hashable, Identifiable {
    public enum Category: String, Sendable, CaseIterable {
        case notetaker, dictation, recorder, calendar, assistant

        public var title: String {
            switch self {
            case .notetaker: "Notetakers"
            case .dictation: "Dictation"
            case .recorder: "Recorders"
            case .calendar: "Meeting reminders"
            case .assistant: "AI assistants"
            }
        }

        public var symbol: String {
            switch self {
            case .notetaker: "text.bubble"
            case .dictation: "waveform"
            case .recorder: "record.circle"
            case .calendar: "calendar.badge.clock"
            case .assistant: "sparkles"
            }
        }
    }

    /// How sure we are of the bundle ID. `nameOnly` apps are matched by their exact app name.
    public enum Confidence: String, Sendable {
        case confirmed, inferred, nameOnly = "name-only"
    }

    /// How the app's call-start prompt appears, as far as research shows.
    public enum Prompt: String, Sendable {
        case window, banner, fullscreen, autoRecord = "auto-record", unknown
    }

    public let name: String
    public let category: Category
    public let bundleIDs: [String]
    /// Exact app names (without `.app`) for apps with no public bundle ID. Never a fragment.
    public let appNames: [String]
    /// Apps with the same name that are not this one.
    public let excludeBundleIDs: [String]
    public let confidence: Confidence
    public let prompt: Prompt
    /// Its prompt can cover the screen, so size alone doesn't rule a window out.
    public let fullScreen: Bool
    /// Extra words that appear in its prompt.
    public let keywords: [String]
    /// Buttons that decline its prompt, in order of preference.
    public let press: [String]
    /// Buttons that start a recording, invite a bot or change its settings.
    public let neverPress: [String]
    /// Where to turn the prompt off inside the app itself.
    public let offSwitch: String?
    public let evidence: String
    public let discontinued: Bool
    public let note: String?

    public var id: String { name }

    public init(name: String, category: Category, bundleIDs: [String] = [], appNames: [String] = [],
                excludeBundleIDs: [String] = [], confidence: Confidence, prompt: Prompt, fullScreen: Bool = false,
                keywords: [String] = [], press: [String] = [], neverPress: [String] = [], offSwitch: String? = nil,
                evidence: String, discontinued: Bool = false, note: String? = nil) {
        self.name = name
        self.category = category
        self.bundleIDs = bundleIDs
        self.appNames = appNames
        self.excludeBundleIDs = excludeBundleIDs
        self.confidence = confidence
        self.prompt = prompt
        self.fullScreen = fullScreen
        self.keywords = keywords
        self.press = press
        self.neverPress = neverPress
        self.offSwitch = offSwitch
        self.evidence = evidence
        self.discontinued = discontinued
        self.note = note
    }
}

public enum Registry {
    private static let byBundleID: [String: KnownApp] = {
        var index: [String: KnownApp] = [:]
        for app in apps { for id in app.bundleIDs { index[id.lowercased()] = index[id.lowercased()] ?? app } }
        return index
    }()

    private static let byName: [String: KnownApp] = {
        var index: [String: KnownApp] = [:]
        for app in apps { for name in app.appNames { index[name.lowercased()] = index[name.lowercased()] ?? app } }
        return index
    }()

    /// The entry for an installed app: by bundle ID first, then by exact app name.
    /// `names` are the app's display name and file name.
    public static func match(bundleID: String, names: [String] = []) -> KnownApp? {
        if let app = byBundleID[bundleID.lowercased()] { return app }
        for name in names {
            if let app = byName[name.lowercased()],
               !app.excludeBundleIDs.contains(where: { BundleID.equal($0, bundleID) }) { return app }
        }
        return nil
    }

    /// The entry for a running process, which may be a helper of a known app.
    public static func match(processBundleID id: String) -> KnownApp? {
        if let app = byBundleID[id.lowercased()] { return app }
        return apps.first { BundleID.matchesAny(id, $0.bundleIDs) }
    }

    /// Uses the microphone but never prompts at call start (dictation, screen recorders…).
    public static func isQuietMicrophoneApp(_ bundleID: String) -> Bool {
        BundleID.matchesAny(bundleID, quietMicrophoneApps)
    }
}
