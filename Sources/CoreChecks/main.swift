// Checks for MeetingMuteCore. Run with `swift run CoreChecks`; exits non-zero on failure.
import Foundation
import MeetingMuteCore

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var passed = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() { passed += 1 } else { failures += 1; print("FAIL line \(line): \(message)") }
}

func checkEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, line: Int = #line) {
    check(a == b, "\(message): got \(a), expected \(b)", line: line)
}

// MARK: Bundle IDs

check(BundleID.matches("com.google.Chrome.helper", base: "com.google.Chrome"), "helper matches its app")
check(BundleID.matches("COM.GOODSNOOZE.macwhisper", base: "com.goodsnooze.MacWhisper"), "case is ignored")
check(!BundleID.matches("org.mozilla.firefoxdeveloperedition", base: "org.mozilla.firefox"), "dot boundary")
check(!BundleID.matches("com.electron.wispr-flowx", base: "com.electron.wispr-flow"), "no fragment match")

// MARK: Registry

let allIDs = Registry.apps.flatMap(\.bundleIDs).map { $0.lowercased() }
checkEqual(allIDs.count, Set(allIDs).count, "no bundle ID is listed twice")
checkEqual(Registry.apps.count, Set(Registry.apps.map(\.name)).count, "no app name is listed twice")
check(Registry.apps.count >= 80, "registry has the researched apps")
check(Registry.apps.allSatisfy { $0.evidence.hasPrefix("http") }, "every entry has evidence")
check(Registry.apps.allSatisfy { $0.confidence != .nameOnly || $0.bundleIDs.isEmpty }, "name-only means no IDs")

checkEqual(Registry.match(bundleID: "com.cron.electron", names: ["Notion Calendar"])?.name, "Notion Calendar",
           "Notion Calendar is not Notion")
checkEqual(Registry.match(bundleID: "notion.id", names: ["Notion"])?.name, "Notion", "Notion by bundle ID")
checkEqual(Registry.match(bundleID: "com.notion.mail", names: ["Notion Mail"])?.name, nil, "Notion Mail is not listed")
checkEqual(Registry.match(bundleID: "com.example.fireflies", names: ["Fireflies"])?.name, "Fireflies",
           "exact app name for an app with no public ID")
checkEqual(Registry.match(bundleID: "com.example.spotter", names: ["Spotter"])?.name, nil, "no fragment match on names")
checkEqual(Registry.match(bundleID: "com.electron.shadow", names: ["Shadow"])?.name, nil, "Shadow PC is excluded")
checkEqual(Registry.match(bundleID: "do.shadow.app", names: ["Shadow"])?.name, "Shadow", "Shadow notetaker by name")
checkEqual(Registry.match(bundleID: "com.openai.codex")?.name, "ChatGPT", "new ChatGPT app")
checkEqual(Registry.match(bundleID: "com.openai.chat")?.name, "ChatGPT", "ChatGPT Classic")
checkEqual(Registry.match(bundleID: "com.hyprnote.stable")?.name, "Anarlog", "renamed app keeps old ID")
checkEqual(Registry.match(processBundleID: "com.electron.wispr-flow.helper")?.name, "Wispr Flow", "helper process")
checkEqual(Registry.match(bundleID: "so.cap.desktop")?.name, nil, "Cap never prompts")
check(Registry.isQuietMicrophoneApp("so.cap.desktop"), "Cap is a quiet microphone app")
check(Registry.isQuietMicrophoneApp("xyz.block.buzz.app"), "Block's Buzz is quiet")
check(Registry.isQuietMicrophoneApp("com.chidiwilliams.buzz"), "Buzz transcription is quiet")
check(!Registry.isQuietMicrophoneApp("com.granola.app"), "Granola is not quiet")
check(Registry.apps.allSatisfy { !MeetingApp.isProtected($0.bundleIDs.first ?? "x.y") }, "no notetaker is a meeting app")

// MARK: Meeting apps

checkEqual(MeetingApp.matching("com.google.Chrome.helper")?.name, "Chrome", "Chrome helper")
checkEqual(MeetingApp.matching("org.mozilla.firefoxdeveloperedition")?.name, "Firefox", "Firefox Developer Edition")
checkEqual(MeetingApp.matching("company.thebrowser.dia")?.name, "Dia", "Dia")
check(MeetingApp.isProtected("us.zoom.xos"), "Zoom is protected")
check(!MeetingApp.isProtected("com.granola.app"), "Granola is not protected")

// MARK: Meeting detection

func detect(_ inputs: [String], zoom: Bool = false, anyBrowser: Bool = false,
            titles: [String: [String]] = [:]) -> MeetingSignal? {
    MeetingDetection.evaluate(inputs: inputs, zoomMeetingRunning: zoom, anyBrowserMicCounts: anyBrowser) {
        titles[$0.name] ?? []
    }
}

checkEqual(detect([], zoom: true)?.source, "Zoom", "Zoom meeting helper")
checkEqual(detect(["us.zoom.xos"])?.source, "Zoom", "Zoom on the microphone")
checkEqual(detect(["com.microsoft.teams2.helper"])?.source, "Microsoft Teams", "Teams helper")
checkEqual(detect(["com.apple.avconferenced"])?.source, "FaceTime", "FaceTime service")
checkEqual(detect(["com.apple.CoreSpeech"])?.source, nil, "Hey Siri is not a meeting")
checkEqual(detect(["com.granola.app"])?.source, nil, "a notetaker alone is not a meeting")
checkEqual(detect(["com.google.Chrome.helper"], titles: ["Chrome": ["Inbox - Gmail"]])?.source, nil,
           "browser mic without a meeting tab")
checkEqual(detect(["com.google.Chrome.helper"], titles: ["Chrome": ["Meet - abc-defg-hij"]])?.source, "Chrome",
           "Google Meet in Chrome")
checkEqual(detect(["com.google.Chrome.helper"], anyBrowser: true)?.source, "Chrome", "any browser mic setting")
checkEqual(detect(["com.apple.WebKit.GPU"], titles: ["Safari": ["Weekly sync | Microsoft Teams"]])?.source, "Safari",
           "Teams in Safari through WebKit")
checkEqual(detect(["com.google.Chrome.helper", "us.zoom.xos"])?.isBrowser, false, "native app wins over browser")
check(MeetingDetection.titleLooksLikeMeeting("Meet - xyz-abcd-efg"), "Meet title")
check(!MeetingDetection.titleLooksLikeMeeting("Docs - Untitled"), "not a meeting title")

// MARK: Dismiss policy

let wispr = Registry.match(bundleID: "com.electron.wispr-flow")
let circleback = Registry.match(bundleID: "x", names: ["Circleback"])
let anarlog = Registry.match(bundleID: "com.hyprnote.stable")
let fireflies = Registry.match(bundleID: "x", names: ["Fireflies"])

checkEqual(DismissPolicy.rank(of: "Not now", for: wispr), 0, "Wispr's own decline first")
checkEqual(DismissPolicy.rank(of: "Start Notetaker", for: wispr), nil, "never start Wispr's Notetaker")
checkEqual(DismissPolicy.bestLabel(among: ["Keep Recording", "Don\u{2019}t Record"], for: circleback), "Don\u{2019}t Record",
           "Circleback's decline with a curly quote")
checkEqual(DismissPolicy.bestLabel(among: ["Yes", "Close"], for: anarlog), "Close", "Anarlog: Close, never Yes")
checkEqual(DismissPolicy.bestLabel(among: ["Take Notes", "Invite Notetaker"], for: fireflies), nil,
           "Fireflies: nothing safe to press")
checkEqual(DismissPolicy.bestLabel(among: ["Record", "Join"], for: nil), nil, "unknown app: record and join are unsafe")
checkEqual(DismissPolicy.bestLabel(among: ["Close", "Dismiss"], for: nil), "Dismiss", "Dismiss before Close")
checkEqual(DismissPolicy.normalize("  Not now. "), "not now", "normalize")
check(DismissPolicy.looksLikeMeetingPrompt(["Meeting detected", "Take Notes"], for: nil), "meeting prompt text")
check(!DismissPolicy.looksLikeMeetingPrompt(["Preferences", "General", "Account"], for: nil), "settings window text")
check(DismissPolicy.looksLikeMeetingPrompt(["Are you in a meeting?"], for: anarlog), "Anarlog prompt text")
let granola = Registry.match(bundleID: "com.granola.app")!
check(DismissPolicy.isConfidentPrompt(["Meeting detected", "Take Notes"], for: granola), "Granola prompt is confident")
check(!DismissPolicy.isConfidentPrompt(["Recording", "00:42", "Stop"], for: granola), "a recording bar is not a prompt")
check(!DismissPolicy.isConfidentPrompt(["My notes", "Call with Sam"], for: granola), "loose words are not enough")
check(DismissPolicy.isConfidentPrompt(["Weekly sync starts in 1 minute", "Join"], for: Registry.match(bundleID: "leits.MeetingBar")!),
      "calendar reminder is confident")
check(DismissPolicy.isConfidentPrompt(["Don\u{2019}t Record", "Keep Recording"], for: circleback!), "curly quote in a phrase")
check(DismissPolicy.isPromptSized(width: 360, height: 120, fullScreenAllowed: false), "toast is prompt sized")
check(!DismissPolicy.isPromptSized(width: 1200, height: 800, fullScreenAllowed: false), "main window is not")
check(DismissPolicy.isPromptSized(width: 1728, height: 1117, fullScreenAllowed: true), "full-screen reminder apps")

// MARK: Banners

checkEqual(BannerText.appName(fromDescription: "Granola, Meeting detected, Chrome"), "Granola", "banner app name")
checkEqual(BannerText.actionLabel("Name:Close\nTarget:0x0\nSelector:(null)"), "Close", "custom action label")
checkEqual(BannerText.actionLabel("AXPress"), "AXPress", "plain action label")
let names: Set<String> = ["Close", "Schließen", "Fermer"]
checkEqual(BannerText.closeAction(in: ["AXPress", "Name:Schließen\nTarget:0x0\nSelector:(null)"], closeNames: names),
           "Name:Schließen\nTarget:0x0\nSelector:(null)", "German Close")
checkEqual(BannerText.closeAction(in: ["Name:Close\nTarget:0x1", "Name:Close\nTarget:0x2"], closeNames: names), nil,
           "two Close actions are ambiguous")
check(BannerText.subroles.contains("AXNotificationCenterAlertStack"), "alert stacks")
check(!BannerText.subroles.contains("AXNotificationCenterNextFocus"), "full subrole match")

// MARK: Activity log

let start = Date(timeIntervalSince1970: 1_000_000)
var log = ActivityLog.appending("Closed Granola popup", at: start, to: [])
log = ActivityLog.appending("Closed Granola popup", at: start.addingTimeInterval(30), to: log)
checkEqual(log.count, 1, "repeats fold into one entry")
checkEqual(log.first?.text, "Closed Granola popup ×2", "repeat count")
log = ActivityLog.appending("Meeting ended", at: start.addingTimeInterval(60), to: log)
checkEqual(log.first?.message, "Meeting ended", "newest first")
log = ActivityLog.appending("Closed Granola popup", at: start.addingTimeInterval(2_000), to: log)
checkEqual(log.count, 3, "an old repeat starts a new entry")
checkEqual((0..<300).reduce([ActivityEntry]()) { ActivityLog.appending("m\($1)", at: start, to: $0) }.count, 200, "limit")
let legacy = #"[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","date":0,"message":"Meeting started"}]"#
let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: Data(legacy.utf8))
checkEqual(decoded?.first?.count, 1, "v1.0 logs still load")

print(failures == 0 ? "All \(passed) checks passed." : "\(failures) of \(passed + failures) checks failed.")
exit(failures == 0 ? 0 : 1)
