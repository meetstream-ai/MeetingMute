/// Apps people hold meetings in. Their windows are never touched, and when one of them
/// uses the microphone a meeting is considered to be on.
struct MeetingApp {
    let name: String
    let bundleIDs: [String]

    static let known: [MeetingApp] = [
        MeetingApp(name: "Zoom", bundleIDs: ["us.zoom.xos"]),
        MeetingApp(name: "Microsoft Teams", bundleIDs: ["com.microsoft.teams2", "com.microsoft.teams"]),
        MeetingApp(name: "Slack", bundleIDs: ["com.tinyspeck.slackmacgap"]),
        MeetingApp(name: "Webex", bundleIDs: ["Cisco-Systems.Spark", "com.cisco.webexmeetingsapp"]),
        MeetingApp(name: "Discord", bundleIDs: ["com.hnc.Discord"]),
        MeetingApp(name: "FaceTime", bundleIDs: ["com.apple.FaceTime"]),
        MeetingApp(name: "Google Chrome", bundleIDs: ["com.google.Chrome"]),
        MeetingApp(name: "Arc", bundleIDs: ["company.thebrowser.Browser"]),
        MeetingApp(name: "Safari", bundleIDs: ["com.apple.Safari"]),
        MeetingApp(name: "Microsoft Edge", bundleIDs: ["com.microsoft.edgemac"]),
        MeetingApp(name: "Brave", bundleIDs: ["com.brave.Browser"]),
        MeetingApp(name: "Firefox", bundleIDs: ["org.mozilla.firefox"]),
        MeetingApp(name: "WhatsApp", bundleIDs: ["net.whatsapp.WhatsApp"]),
    ]
}
