import AppKit
import MeetingMuteCore
import SwiftUI

/// Screenshot mode for docs and contributors: `open build/MeetingMute.app --args --demo`.
/// Sample apps, settings in a separate store, and no Accessibility work at all.
/// Extra flags: `--demo-meeting`, `--demo-onboarding`, `--demo-settings`, `--demo-rows`,
/// `--light`, `--dark`, and `--demo-icons <folder>` with one `<App name>.png` per app (icons
/// are not shipped; without them the installed app's icon or a monogram is used).
enum Demo {
    static let isOn = CommandLine.arguments.contains("--demo")
    static let inMeeting = isOn && CommandLine.arguments.contains("--demo-meeting")
    static let onboarding = isOn && CommandLine.arguments.contains("--demo-onboarding")
    static let showsSettings = isOn && CommandLine.arguments.contains("--demo-settings")
    /// Tall enough to show every group in a screenshot.
    static var windowHeight: CGFloat { onboarding ? 640 : 1040 }

    /// Where settings live: a throwaway suite in demo mode, so real settings are never touched.
    nonisolated(unsafe) static let defaults: UserDefaults = {
        guard isOn, let suite = UserDefaults(suiteName: "ai.meetstream.MeetingMute.demo") else { return .standard }
        suite.removePersistentDomain(forName: "ai.meetstream.MeetingMute.demo")
        return suite
    }()

    private static let apps: [(id: String, name: String, hue: Double, running: Bool, muted: Bool)] = [
        ("com.granola.app", "Granola", 0.30, true, true),
        ("com.otterai.desktop", "Otter", 0.58, false, true),
        ("demo.fireflies", "Fireflies", 0.83, true, true),
        ("video.fathom.electron", "Fathom", 0.75, false, false),
        ("demo.circleback", "Circleback", 0.05, true, true),
        ("com.jamie.app", "Jamie", 0.7, false, true),
        ("com.electron.wispr-flow", "Wispr Flow", 0.0, true, false),
        ("com.goodsnooze.MacWhisper", "MacWhisper", 0.6, false, true),
        ("com.cron.electron", "Notion Calendar", 0.0, true, true),
        ("leits.MeetingBar", "MeetingBar", 0.12, false, false),
    ]

    private static let iconFolder: URL? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo-icons"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }()

    static var installed: [String: InstalledApp] {
        Dictionary(uniqueKeysWithValues: apps.map { app in
            let url = URL(fileURLWithPath: "/Applications/\(app.name).app")
            return (app.id, InstalledApp(bundleID: app.id, name: app.name, url: url))
        })
    }

    static var running: Set<String> { Set(apps.filter(\.running).map(\.id)) }

    @MainActor
    static func icon(for url: URL) -> NSImage? {
        guard isOn, let app = apps.first(where: { url.lastPathComponent == "\($0.name).app" }) else { return nil }
        if let folder = iconFolder, let icon = NSImage(contentsOf: folder.appendingPathComponent("\(app.name).png")) {
            return icon
        }
        if let real = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: app.id).first {
            return NSWorkspace.shared.icon(forFile: real.path)
        }
        return monogram(String(app.name.prefix(1)), hue: app.hue, grey: app.hue == 0)
    }

    /// Seeds the demo store with muted apps, a running total and a believable activity log.
    @MainActor
    static func seed(_ d: UserDefaults) {
        guard isOn else { return }
        d.set(apps.filter(\.muted).map(\.id), forKey: "muted")
        d.set(128, forKey: "silencedTotal")
        d.set(!onboarding, forKey: "onboarded")
        if CommandLine.arguments.contains("--demo-rows") { d.set("rows", forKey: "layout") }
        let now = Date()
        let lines: [(TimeInterval, String, Int)] = [
            (-26_000, "Meeting started in Google Meet · muting Granola, Otter and Fireflies", 1),
            (-25_990, "Closed Granola popup", 1),
            (-25_985, "Closed Fireflies popup", 1),
            (-23_000, "Meeting ended · 2 silenced", 1),
            (-760, "Meeting started in Zoom · muting Granola, Otter, Fireflies, Jamie, MacWhisper and Notion Calendar", 1),
            (-752, "Closed Granola popup", 1),
            (-751, "Closed Circleback popup", 1),
            (-750, "Closed Fireflies popup", 1),
            (-748, "Closed MacWhisper notification", 1),
            (-120, "Closed Notion Calendar popup", 1),
        ]
        let log = lines.reversed().map { ActivityEntry(date: now.addingTimeInterval($0.0), message: $0.1, count: $0.2) }
        d.set(try? JSONEncoder().encode(log), forKey: "log")
    }

    /// Brings the main window forward at a size that fits every group.
    @MainActor
    static func showWindow() {
        guard isOn else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSApp.activate()
            guard let window = NSApp.windows.first(where: { $0.title == "MeetingMute" }) else { return }
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.setContentSize(NSSize(width: 600, height: windowHeight))
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            guard showsSettings else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                for other in NSApp.windows where other !== window && other.isVisible && other.styleMask.contains(.titled) {
                    other.collectionBehavior.insert(.canJoinAllSpaces)
                    other.makeKeyAndOrderFront(nil)
                    other.orderFrontRegardless()
                }
            }
        }
    }

    @MainActor
    static func applyAppearance() {
        guard isOn else { return }
        let args = CommandLine.arguments
        if args.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        if args.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
    }

    /// In screenshots, controls render as in a focused window even when another app is in front.
    struct ActiveState: ViewModifier {
        func body(content: Content) -> some View {
            if Demo.isOn { content.environment(\.controlActiveState, .key) } else { content }
        }
    }

    /// A rounded tile with a letter: stands in for real app icons in screenshots.
    @MainActor
    private static func monogram(_ letter: String, hue: Double, grey: Bool) -> NSImage {
        let size = NSSize(width: 256, height: 256)
        return NSImage(size: size, flipped: false) { rect in
            let tile = rect.insetBy(dx: 22, dy: 22)
            let path = NSBezierPath(roundedRect: tile, xRadius: 50, yRadius: 50)
            let top = grey ? NSColor(white: 0.97, alpha: 1)
                : NSColor(hue: hue, saturation: 0.55, brightness: 0.98, alpha: 1)
            let bottom = grey ? NSColor(white: 0.84, alpha: 1)
                : NSColor(hue: hue, saturation: 0.75, brightness: 0.72, alpha: 1)
            NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -90)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 118, weight: .bold),
                .foregroundColor: grey ? NSColor(white: 0.15, alpha: 1) : NSColor.white,
            ]
            let text = NSAttributedString(string: letter, attributes: attrs)
            let t = text.size()
            text.draw(at: NSPoint(x: tile.midX - t.width / 2, y: tile.midY - t.height / 2 - 4))
            return true
        }
    }
}
