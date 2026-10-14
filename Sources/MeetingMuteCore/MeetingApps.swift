/// Apps people hold meetings in. They're never touched, and when one of them uses the
/// microphone a meeting may be on (browsers also need a meeting tab, see `MeetingDetection`).
public struct MeetingApp: Sendable, Hashable {
    public let name: String
    public let bundleIDs: [String]
    public let isBrowser: Bool
    /// Uses the shared `com.apple.WebKit.GPU` process for audio (Safari, Orion).
    public let usesWebKit: Bool

    public init(name: String, bundleIDs: [String], isBrowser: Bool = false, usesWebKit: Bool = false) {
        self.name = name
        self.bundleIDs = bundleIDs
        self.isBrowser = isBrowser
        self.usesWebKit = usesWebKit
    }

    public static let known: [MeetingApp] = [
        // Meeting apps
        MeetingApp(name: "Zoom", bundleIDs: ["us.zoom.xos"]),
        MeetingApp(name: "Microsoft Teams", bundleIDs: ["com.microsoft.teams2", "com.microsoft.teams"]),
        MeetingApp(name: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"]),
        MeetingApp(name: "Webex", bundleIDs: ["Cisco-Systems.Spark", "com.webex.meetingmanager"]),
        MeetingApp(name: "Discord", bundleIDs: ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"]),
        MeetingApp(name: "FaceTime", bundleIDs: ["com.apple.FaceTime"]),
        MeetingApp(name: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp", "desktop.WhatsApp"]),
        MeetingApp(name: "Skype", bundleIDs: ["com.skype.skype"]),
        MeetingApp(name: "GoTo Meeting", bundleIDs: ["com.logmein.GoToMeeting", "com.logmein.goto"]),
        MeetingApp(name: "RingCentral", bundleIDs: ["com.ringcentral.glip", "com.ringcentral.RingCentral"]),
        MeetingApp(name: "Amazon Chime", bundleIDs: ["com.amazon.Amazon-Chime"]),
        MeetingApp(name: "Telegram", bundleIDs: ["ru.keepcoder.Telegram", "org.telegram.desktop"]),
        MeetingApp(name: "Signal", bundleIDs: ["org.whispersystems.signal-desktop"]),
        MeetingApp(name: "Tuple", bundleIDs: ["app.tuple.app"]),
        MeetingApp(name: "Around", bundleIDs: ["co.teamport.around"]),
        MeetingApp(name: "Tencent Meeting", bundleIDs: ["com.tencent.meeting"]),
        MeetingApp(name: "Element", bundleIDs: ["im.riot.app"]),
        // Browsers (Google Meet, Teams on the web, Whereby…)
        MeetingApp(name: "Chrome", bundleIDs: ["com.google.Chrome"], isBrowser: true),
        MeetingApp(name: "Arc", bundleIDs: ["company.thebrowser.Browser"], isBrowser: true),
        MeetingApp(name: "Dia", bundleIDs: ["company.thebrowser.dia"], isBrowser: true),
        MeetingApp(name: "Safari", bundleIDs: ["com.apple.Safari", "com.apple.SafariTechnologyPreview"],
                   isBrowser: true, usesWebKit: true),
        MeetingApp(name: "Edge", bundleIDs: ["com.microsoft.edgemac"], isBrowser: true),
        MeetingApp(name: "Brave", bundleIDs: ["com.brave.Browser"], isBrowser: true),
        MeetingApp(name: "Firefox", bundleIDs: ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
                                                "org.mozilla.nightly", "org.mozilla.plugincontainer"], isBrowser: true),
        MeetingApp(name: "Vivaldi", bundleIDs: ["com.vivaldi.Vivaldi"], isBrowser: true),
        MeetingApp(name: "Opera", bundleIDs: ["com.operasoftware.Opera", "com.operasoftware.OperaGX"], isBrowser: true),
        MeetingApp(name: "Chromium", bundleIDs: ["org.chromium.Chromium"], isBrowser: true),
        MeetingApp(name: "Orion", bundleIDs: ["com.kagi.kagimacOS"], isBrowser: true, usesWebKit: true),
        MeetingApp(name: "Zen", bundleIDs: ["app.zen-browser.zen"], isBrowser: true),
        MeetingApp(name: "Comet", bundleIDs: ["ai.perplexity.comet"], isBrowser: true),
        MeetingApp(name: "ChatGPT Atlas", bundleIDs: ["com.openai.atlas"], isBrowser: true),
        MeetingApp(name: "Sidekick", bundleIDs: ["com.pushplaylabs.sidekick"], isBrowser: true),
    ]

    /// System processes that capture audio for FaceTime and phone calls.
    public static let faceTimeServices = ["com.apple.avconferenced", "com.apple.TelephonyUtilities"]
    /// Safari's (and every WKWebView's) shared audio process.
    public static let webKitAudio = "com.apple.WebKit"

    /// The meeting app (or browser) a process belongs to, helpers included.
    public static func matching(_ bundleID: String) -> MeetingApp? {
        known.first { BundleID.matchesAny(bundleID, $0.bundleIDs) }
    }

    /// Never touched by MeetingMute.
    public static func isProtected(_ bundleID: String) -> Bool {
        matching(bundleID) != nil
    }
}
