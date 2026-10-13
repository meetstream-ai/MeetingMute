import Foundation

/// Decides which windows are meeting prompts and which buttons are safe to press.
///
/// A wrong press can start a recording, invite a bot into the call or change the other
/// app's settings, so MeetingMute only presses labels that decline, compared in full
/// (never as fragments), and never the ones an app's registry entry forbids.
public enum DismissPolicy {
    /// Labels that decline a prompt, in order of preference.
    public static let safeLabels: [String] = [
        "not now", "dismiss", "no thanks", "no, thanks", "not this one", "maybe later", "don't record",
        "do not record", "not today", "decline", "skip", "ignore", "later", "close", "cancel",
        "x", "×", "✕", "✖", "xmark", "close notification",
    ]

    /// Words that show a window is about a meeting.
    public static let meetingWords: [String] = [
        "meeting", "call", "huddle", "record", "transcri", "notes", "notetaker", "detected", "join",
        "capture", "starts in", "starting", "event", "conference",
    ]

    /// Lower case, trimmed, curly quotes made straight, trailing punctuation removed.
    public static func normalize(_ label: String) -> String {
        var s = label.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2026}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = s.last, ".!…:".contains(last) { s.removeLast() }
        return s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Lower is better; nil means never press.
    public static func rank(of label: String, for app: KnownApp?) -> Int? {
        let n = normalize(label)
        guard !n.isEmpty else { return nil }
        if let app {
            if app.neverPress.contains(where: { normalize($0) == n }) { return nil }
            if let i = app.press.firstIndex(where: { normalize($0) == n }) { return i }
        }
        return safeLabels.firstIndex(of: n).map { 100 + $0 }
    }

    /// The label of the best button to press, if any is safe.
    public static func bestLabel(among labels: [String], for app: KnownApp?) -> String? {
        labels.compactMap { label in rank(of: label, for: app).map { (label, $0) } }
            .min { $0.1 < $1.1 }?.0
    }

    /// True when the window's text reads like a call-start prompt.
    public static func looksLikeMeetingPrompt(_ texts: [String], for app: KnownApp?) -> Bool {
        let text = texts.joined(separator: " ").lowercased()
        guard !text.isEmpty else { return false }
        let words = meetingWords + (app?.keywords.map { $0.lowercased() } ?? [])
        return words.contains { text.contains($0) }
    }

    /// Phrases that only call-start prompts use. Words like "record" or "notes" alone are not
    /// enough: a notetaker's own recording bar has them too.
    public static let promptPhrases: [String] = [
        "detected", "in a meeting", "record this", "start recording", "start notetaker", "take notes",
        "transcribe this", "notes for this", "want notes", "starts in", "starting now", "has started",
        "event starts", "join now", "join meeting", "join the call", "don't record", "start ai meeting notes",
        "are you in",
    ]

    /// Sure enough that a window is a call-start prompt to close or hide it when no decline
    /// button was found: the app's own prompt wording, or a phrase only prompts use.
    public static func isConfidentPrompt(_ texts: [String], for app: KnownApp) -> Bool {
        let text = texts.joined(separator: " ").lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        guard !text.isEmpty else { return false }
        return (app.keywords.map { $0.lowercased() } + promptPhrases).contains { text.contains($0) }
    }

    /// Small enough to be a prompt rather than an app's own window (points).
    public static func isPromptSized(width: Double, height: Double, fullScreenAllowed: Bool) -> Bool {
        if fullScreenAllowed { return true }
        return width * height <= 640 * 480 && width <= 900 && height <= 640
    }
}
