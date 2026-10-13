import AppKit
import Observation
import UniformTypeIdentifiers

/// A notetaker / recorder that may show its own "meeting detected" prompt.
struct KnownRecorder {
    let name: String
    /// Bundle IDs confirmed from a real Info.plist.
    let bundleIDs: [String]
    /// Lowercased app-name fragments, used when the bundle ID isn't confirmed.
    let nameMatches: [String]

    static let all: [KnownRecorder] = [
        KnownRecorder(name: "Granola", bundleIDs: ["com.granola.app"], nameMatches: ["granola"]),
        KnownRecorder(name: "Wispr Flow", bundleIDs: ["com.electron.wispr-flow"], nameMatches: ["wispr"]),
        KnownRecorder(name: "MacWhisper", bundleIDs: ["com.goodsnooze.MacWhisper"], nameMatches: ["macwhisper"]),
        KnownRecorder(name: "Circleback", bundleIDs: [], nameMatches: ["circleback"]),
        KnownRecorder(name: "Otter", bundleIDs: [], nameMatches: ["otter"]),
        KnownRecorder(name: "Fireflies", bundleIDs: [], nameMatches: ["fireflies"]),
        KnownRecorder(name: "Fathom", bundleIDs: [], nameMatches: ["fathom"]),
        KnownRecorder(name: "superwhisper", bundleIDs: [], nameMatches: ["superwhisper"]),
        KnownRecorder(name: "Krisp", bundleIDs: [], nameMatches: ["krisp"]),
        KnownRecorder(name: "tl;dv", bundleIDs: [], nameMatches: ["tl;dv", "tldv"]),
        KnownRecorder(name: "Jamie", bundleIDs: [], nameMatches: ["jamie"]),
        KnownRecorder(name: "Bluedot", bundleIDs: [], nameMatches: ["bluedot"]),
        KnownRecorder(name: "Read AI", bundleIDs: [], nameMatches: ["read ai", "read.ai"]),
        KnownRecorder(name: "Notion", bundleIDs: [], nameMatches: ["notion"]),
        KnownRecorder(name: "Limitless", bundleIDs: [], nameMatches: ["limitless"]),
        KnownRecorder(name: "Tactiq", bundleIDs: [], nameMatches: ["tactiq"]),
        KnownRecorder(name: "Avoma", bundleIDs: [], nameMatches: ["avoma"]),
    ]

    func matches(_ app: InstalledApp) -> Bool {
        if bundleIDs.contains(app.bundleID) { return true }
        let name = app.name.lowercased()
        return nameMatches.contains { name.contains($0) }
    }
}

/// A recorder app on this Mac.
struct RecorderApp: Identifiable {
    let app: InstalledApp
    let displayName: String

    var id: String { app.bundleID }

    /// System Settings > Notifications, scrolled to this app.
    var notificationSettingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(app.bundleID)")!
    }
}

/// How muting is decided.
enum MuteMode: String {
    /// Each app is muted or not on its own.
    case custom
    /// Every app is muted except `onlyID`.
    case allButOne
    /// Every app is muted, including ones detected later.
    case all
}

struct ActivityEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let message: String
}

/// Which recorder apps are muted during meetings. Everything is allowed until the user mutes
/// it, so a fresh install changes nothing.
@MainActor
@Observable
final class MeetingPromptsStore {
    private let catalog: AppCatalog
    private let defaults = UserDefaults.standard

    private(set) var mode: MuteMode
    /// The one app that can prompt in `.allButOne`.
    private(set) var onlyID: String?
    /// Muted apps in `.custom`.
    private(set) var mutedIDs: Set<String>
    /// Apps found on the fly (picked by hand, or seen using the microphone).
    private(set) var extraIDs: [String]
    /// Apps the user removed from the list; never re-detected.
    private(set) var hiddenIDs: Set<String>
    private(set) var log: [ActivityEntry]

    /// Master switch.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "enabled") }
    }

    init(catalog: AppCatalog) {
        self.catalog = catalog
        mode = MuteMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .custom
        onlyID = defaults.string(forKey: "onlyID")
        mutedIDs = Set(defaults.stringArray(forKey: "muted") ?? [])
        extraIDs = defaults.stringArray(forKey: "extra") ?? []
        hiddenIDs = Set(defaults.stringArray(forKey: "hidden") ?? [])
        isEnabled = defaults.object(forKey: "enabled") as? Bool ?? true
        log = defaults.data(forKey: "log")
            .flatMap { try? JSONDecoder().decode([ActivityEntry].self, from: $0) } ?? []
        // Extra apps may live outside the scanned folders.
        for path in defaults.stringArray(forKey: "extraPaths") ?? [] {
            catalog.register(URL(fileURLWithPath: path))
        }
    }

    /// Known recorders on disk plus extra ones, sorted by name.
    var recorders: [RecorderApp] {
        catalog.installed.values
            .filter { !hiddenIDs.contains($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .compactMap { app in
                if let known = KnownRecorder.all.first(where: { $0.matches(app) }) {
                    return RecorderApp(app: app, displayName: known.name)
                }
                return extraIDs.contains(app.bundleID) ? RecorderApp(app: app, displayName: app.name) : nil
            }
    }

    var allowed: [RecorderApp] { recorders.filter(isAllowed) }
    var muted: [RecorderApp] { recorders.filter { !isAllowed($0) } }

    func isAllowed(_ recorder: RecorderApp) -> Bool {
        switch mode {
        case .custom: !mutedIDs.contains(recorder.id)
        case .allButOne: recorder.id == onlyID
        case .all: false
        }
    }
    func isRunning(_ recorder: RecorderApp) -> Bool { catalog.isRunning(recorder.id) }

    func setMuted(_ recorder: RecorderApp, _ mute: Bool) {
        switch (mode, mute) {
        case (.custom, _):
            if mute { mutedIDs.insert(recorder.id) } else { mutedIDs.remove(recorder.id) }
            save()
            record("\(mute ? "Muted" : "Unmuted") \(recorder.displayName)")
        case (.allButOne, true):
            setMode(.all)  // Muting the one allowed app leaves nothing allowed.
        case (_, false):
            allowOnly(recorder)  // Unmuting one app in a mute-all mode swaps which one may prompt.
        case (.all, true):
            break
        }
    }

    /// Mute every recorder except one.
    func allowOnly(_ recorder: RecorderApp) {
        mode = .allButOne
        onlyID = recorder.id
        save()
        record("Only \(recorder.displayName) can prompt")
    }

    func setMode(_ next: MuteMode) {
        guard next != mode else { return }
        if next == .custom {
            mutedIDs = Set(muted.map(\.id))  // Keep what's muted right now.
        }
        if next == .allButOne, !recorders.contains(where: { $0.id == onlyID }) {
            onlyID = (allowed.first ?? recorders.first)?.id
        }
        mode = next
        save()
        let message = switch next {
        case .custom: "Choosing apps one by one"
        case .allButOne: "Only \(recorders.first { $0.id == onlyID }?.displayName ?? "one app") can prompt"
        case .all: "Muted all"
        }
        record(message)
    }

    func unmuteAll() {
        guard !muted.isEmpty else { return }
        mode = .custom
        mutedIDs = []
        save()
        record("Unmuted all")
    }

    // MARK: Adding and removing apps

    /// Lets the user pick any app to treat as a recorder.
    func addManually() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let app = catalog.register(url) else { return }
        hiddenIDs.remove(app.bundleID)
        addExtra(app)
        record("Added \(app.name)")
    }

    /// Called with the bundle IDs of processes using the microphone. A non-meeting app
    /// recording audio is probably a notetaker or dictation app, so it joins the list.
    func noteMicrophoneUsers(_ bundleIDs: [String]) {
        let meetingIDs = MeetingApp.known.flatMap(\.bundleIDs)
        let ignored = hiddenIDs.union(extraIDs).union(recorders.map(\.id))
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            guard let id = app.bundleIdentifier, let url = app.bundleURL,
                  !id.hasPrefix("com.apple."), id != Bundle.main.bundleIdentifier, !ignored.contains(id),
                  // Meeting apps and their helpers (e.g. com.google.Chrome.helper).
                  !meetingIDs.contains(where: { id == $0 || id.hasPrefix($0 + ".") }),
                  // Helper bundles nested inside another app.
                  !url.deletingLastPathComponent().path.contains(".app/"),
                  bundleIDs.contains(where: { $0 == id || $0.hasPrefix(id + ".") }),
                  let installed = catalog.register(url) else { continue }
            addExtra(installed)
            record("Found \(installed.name)")
        }
    }

    /// Takes an app off the list; it won't be detected again until added by hand.
    func remove(_ recorder: RecorderApp) {
        extraIDs.removeAll { $0 == recorder.id }
        mutedIDs.remove(recorder.id)
        if onlyID == recorder.id { onlyID = nil }
        hiddenIDs.insert(recorder.id)
        save()
    }

    /// Apps the user took off the list that are still installed.
    var removedApps: [InstalledApp] {
        hiddenIDs.compactMap { catalog.installed[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Puts a removed app back on the list.
    func restore(_ app: InstalledApp) {
        hiddenIDs.remove(app.bundleID)
        if !KnownRecorder.all.contains(where: { $0.matches(app) }) { addExtra(app) }
        save()
        record("Added \(app.name)")
    }

    /// Where an app on the list came from.
    func source(of recorder: RecorderApp) -> String {
        KnownRecorder.all.contains { $0.matches(recorder.app) } ? "Built-in" : "Added"
    }

    private func addExtra(_ app: InstalledApp) {
        guard !extraIDs.contains(app.bundleID) else { return }
        extraIDs.append(app.bundleID)
        var paths = defaults.stringArray(forKey: "extraPaths") ?? []
        paths.append(app.url.path)
        defaults.set(paths, forKey: "extraPaths")
        save()
    }

    func open(_ recorder: RecorderApp) {
        NSWorkspace.shared.openApplication(at: recorder.app.url, configuration: .init())
    }

    // MARK: Activity

    func record(_ message: String) {
        log.insert(ActivityEntry(date: .now, message: message), at: 0)
        if log.count > 100 { log.removeLast(log.count - 100) }
        if let data = try? JSONEncoder().encode(log) { defaults.set(data, forKey: "log") }
    }

    func clearLog() {
        log = []
        defaults.removeObject(forKey: "log")
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(onlyID, forKey: "onlyID")
        defaults.set(Array(mutedIDs), forKey: "muted")
        defaults.set(extraIDs, forKey: "extra")
        defaults.set(Array(hiddenIDs), forKey: "hidden")
    }
}
