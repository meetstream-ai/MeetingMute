import Foundation

/// What started the current meeting.
public struct MeetingSignal: Sendable, Equatable {
    public let source: String
    public let isBrowser: Bool

    public init(source: String, isBrowser: Bool) {
        self.source = source
        self.isBrowser = isBrowser
    }
}

/// Decides whether a call is on from the processes recording audio.
///
/// A native meeting app (Zoom, Teams, FaceTime…) using the microphone is a meeting. A browser
/// using it is only a meeting when one of its windows shows a meeting (Google Meet, Teams on the
/// web, Whereby…), because voice search and dictation sites use the microphone too.
public enum MeetingDetection {
    /// Lower-case fragments of browser window titles that mean a call is open.
    public static let meetingTitleHints: [String] = [
        "meet - ", "google meet", "meet.google.com", "zoom meeting", "zoom workplace", "| zoom", "zoom.us",
        "microsoft teams", "| teams", "teams meeting", "teams.microsoft.com", "teams.live.com", "webex",
        "whereby", "jitsi", "huddle", "discord", "gather", "riverside", "streamyard", "skype", "chime",
        "gotomeeting", "goto meeting", "ringcentral", "livestorm", "daily.co", "around", "tuple",
    ]

    public static func titleLooksLikeMeeting(_ title: String) -> Bool {
        let t = title.lowercased()
        return meetingTitleHints.contains { t.contains($0) }
    }

    /// - Parameters:
    ///   - inputs: bundle IDs of processes with audio input running.
    ///   - zoomMeetingRunning: Zoom's meeting helper (CptHost) is running.
    ///   - anyBrowserMicCounts: treat any browser microphone use as a meeting.
    ///   - browserTitles: window titles of a running browser.
    public static func evaluate(inputs: [String], zoomMeetingRunning: Bool, anyBrowserMicCounts: Bool,
                                browserTitles: (MeetingApp) -> [String]) -> MeetingSignal? {
        if zoomMeetingRunning { return MeetingSignal(source: "Zoom", isBrowser: false) }

        var browsers: [MeetingApp] = []
        for id in inputs {
            if BundleID.matchesAny(id, MeetingApp.faceTimeServices) {
                return MeetingSignal(source: "FaceTime", isBrowser: false)
            }
            if BundleID.matches(id, base: MeetingApp.webKitAudio) {
                browsers += MeetingApp.known.filter(\.usesWebKit)
                continue
            }
            guard let app = MeetingApp.matching(id) else { continue }
            if app.isBrowser { browsers.append(app) } else { return MeetingSignal(source: app.name, isBrowser: false) }
        }

        for browser in browsers {
            if anyBrowserMicCounts || browserTitles(browser).contains(where: titleLooksLikeMeeting) {
                return MeetingSignal(source: browser.name, isBrowser: true)
            }
        }
        return nil
    }
}
