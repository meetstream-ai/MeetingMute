import AppKit
import MeetingMuteCore
import Observation
import UniformTypeIdentifiers

/// An app on the list: a known notetaker (from the registry) or one added by hand.
struct RecorderApp: Identifiable, Hashable {
    let app: InstalledApp
    let known: KnownApp?
    let displayName: String

    var id: String { app.bundleID }
    var category: KnownApp.Category? { known?.category }

    /// Where to turn the prompt off inside the app, without the app's own name in front.
    var offSwitchPath: String? {
        guard let off = known?.offSwitch else { return nil }
        for name in [known?.name, displayName].compactMap({ $0 }) where off.hasPrefix(name + " › ") {
            return String(off.dropFirst(name.count + 3))
        }
        return off
    }

    /// System Settings › Notifications, scrolled to this app.
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
    /// Every app is muted, including known apps installed later.
    case all
}

/// When Notification Center banners from muted apps are closed.
enum BannerScope: String {
    /// During meetings: the prompts, plus "next meeting in 1 minute" reminders mid-call.
    case meetings
    /// Always, e.g. for calendar reminders before a call starts.
    case always
}

/// Which apps are muted during meetings. Everything is allowed until the user mutes it,
/// so a fresh install changes nothing.
@MainActor
@Observable
final class MeetingPromptsStore {
    private let catalog: AppCatalog
    private let defaults = Demo.defaults

    private(set) var mode: MuteMode
    /// The one app that can prompt in `.allButOne`.
    private(set) var onlyID: String?
    /// Muted apps in `.custom`.
    private(set) var mutedIDs: Set<String>
    /// Apps added by hand or found using the microphone.
    private(set) var extraIDs: [String]
    /// Apps found using the microphone that the user hasn't looked at yet. Never muted until
    /// the user mutes them, whatever the mode.
    private(set) var suggestedIDs: Set<String>
    /// Apps the user removed from the list; never suggested again.
    private(set) var hiddenIDs: Set<String>
    private(set) var log: [ActivityEntry]
    /// Popups and banners closed since install.
    private(set) var silencedTotal: Int

    /// Master switch.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "enabled") }
    }
    var bannerScope: BannerScope {
        didSet { defaults.set(bannerScope.rawValue, forKey: "bannerScope") }
    }
    /// Count any browser microphone use as a meeting, not just tabs that look like calls.
    var anyBrowserMicCounts: Bool {
        didSet { defaults.set(anyBrowserMicCounts, forKey: "anyBrowserMic") }
    }

    init(catalog: AppCatalog) {
        self.catalog = catalog
        if Demo.isOn { Demo.seed(defaults) } else { Self.migrateFromV1(defaults) }
        mode = MuteMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .custom
        onlyID = defaults.string(forKey: "onlyID")
        mutedIDs = Set(defaults.stringArray(forKey: "muted") ?? [])
        extraIDs = defaults.stringArray(forKey: "extra") ?? []
        suggestedIDs = Set(defaults.stringArray(forKey: "suggested") ?? [])
        hiddenIDs = Set(defaults.stringArray(forKey: "hidden") ?? [])
        isEnabled = defaults.object(forKey: "enabled") as? Bool ?? true
        bannerScope = BannerScope(rawValue: defaults.string(forKey: "bannerScope") ?? "") ?? .meetings
        anyBrowserMicCounts = defaults.bool(forKey: "anyBrowserMic")
        silencedTotal = defaults.integer(forKey: "silencedTotal")
        log = defaults.data(forKey: "log")
            .flatMap { try? JSONDecoder().decode([ActivityEntry].self, from: $0) } ?? []
        // Extra apps may live outside the scanned folders.
        for path in Set(defaults.stringArray(forKey: "extraPaths") ?? []) {
            catalog.register(URL(fileURLWithPath: path))
        }
    }

    /// v1.0 used the bundle ID com.rohanganesh.MeetingMute; carry its settings over once.
    private static func migrateFromV1(_ defaults: UserDefaults) {
        guard !defaults.bool(forKey: "migratedFromV1") else { return }
        defaults.set(true, forKey: "migratedFromV1")
        guard let old = defaults.persistentDomain(forName: "com.rohanganesh.MeetingMute") else { return }
        for (key, value) in old where defaults.object(forKey: key) == nil { defaults.set(value, forKey: key) }
    }

    // MARK: The list

    @ObservationIgnored private var cache: (key: String, list: [RecorderApp])?

    /// Known apps on this Mac plus apps added by hand, grouped by category, then by name.
    /// Cached until the installed apps or the list's own settings change.
    var recorders: [RecorderApp] {
        let key = "\(catalog.generation)|\(hiddenIDs.sorted())|\(extraIDs)"
        if let cache, cache.key == key { return cache.list }
        let list = buildRecorders()
        cache = (key, list)
        return list
    }

    private func buildRecorders() -> [RecorderApp] {
        let me = Bundle.main.bundleIdentifier ?? ""
        var list: [RecorderApp] = catalog.installed.values.compactMap { app in
            guard !hiddenIDs.contains(app.bundleID), app.bundleID != me, !MeetingApp.isProtected(app.bundleID) else {
                return nil
            }
            let known = Registry.match(bundleID: app.bundleID, names: [app.name, app.fileName])
            guard known != nil || extraIDs.contains(app.bundleID) else { return nil }
            return RecorderApp(app: app, known: known, displayName: known?.name ?? app.name)
        }
        // Two apps for one entry (ChatGPT and ChatGPT Classic): show their own names.
        let counts = Dictionary(grouping: list, by: \.displayName).mapValues(\.count)
        list = list.map { r in
            counts[r.displayName, default: 0] > 1 ? RecorderApp(app: r.app, known: r.known, displayName: r.app.name) : r
        }
        let order = KnownApp.Category.allCases
        return list.sorted { a, b in
            let ia = a.category.flatMap { order.firstIndex(of: $0) } ?? order.count
            let ib = b.category.flatMap { order.firstIndex(of: $0) } ?? order.count
            if ia != ib { return ia < ib }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    struct Group: Identifiable {
        let title: String
        let symbol: String
        let apps: [RecorderApp]
        var id: String { title }
    }

    /// The list split by category, with apps added by hand last.
    var groups: [Group] {
        let list = recorders
        var groups = KnownApp.Category.allCases.compactMap { category -> Group? in
            let apps = list.filter { $0.category == category }
            return apps.isEmpty ? nil : Group(title: category.title, symbol: category.symbol, apps: apps)
        }
        let added = list.filter { $0.category == nil }
        if !added.isEmpty { groups.append(Group(title: "Added", symbol: "plus.app", apps: added)) }
        return groups
    }

    var allowed: [RecorderApp] { recorders.filter(isAllowed) }
    var muted: [RecorderApp] { recorders.filter { !isAllowed($0) } }

    func isAllowed(_ recorder: RecorderApp) -> Bool {
        if suggestedIDs.contains(recorder.id) { return true }
        switch mode {
        case .custom: return !mutedIDs.contains(recorder.id)
        case .allButOne: return recorder.id == onlyID
        case .all: return false
        }
    }

    func isSuggested(_ recorder: RecorderApp) -> Bool { suggestedIDs.contains(recorder.id) }
    func isRunning(_ recorder: RecorderApp) -> Bool { catalog.isRunning(recorder.id) }

    func setMuted(_ recorder: RecorderApp, _ mute: Bool) {
        // A suggested app shows as allowed; muting it just takes it out of suggestions, after
        // which the mode decides (it's muted in "All but one" and "Mute all").
        let wasSuggested = suggestedIDs.remove(recorder.id) != nil
        switch (mode, mute) {
        case (.custom, _):
            if mute { mutedIDs.insert(recorder.id) } else { mutedIDs.remove(recorder.id) }
            save()
            record("\(mute ? "Muted" : "Unmuted") \(recorder.displayName)")
        case (.allButOne, true) where !wasSuggested:
            setMode(.all)  // Muting the one allowed app leaves nothing allowed.
        case (_, true):
            save()
            record("Muted \(recorder.displayName)")
        case (_, false):
            allowOnly(recorder)  // Unmuting one app in a mute-all mode swaps which one may prompt.
        }
    }

    /// Mute every app except one.
    func allowOnly(_ recorder: RecorderApp) {
        suggestedIDs.remove(recorder.id)
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
        // Keep the current one-allowed app only if it is on the list and allowed right now;
        // otherwise pick an allowed app that isn't just a suggestion.
        if next == .allButOne, !recorders.contains(where: { $0.id == onlyID && isAllowed($0) && !isSuggested($0) }) {
            onlyID = (allowed.first { !isSuggested($0) } ?? recorders.first)?.id
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

    /// Lets the user pick any app to treat as a notetaker.
    func addManually() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        panel.message = "Choose an app whose popups you want MeetingMute to manage."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let app = catalog.register(url) else { return }
        if MeetingApp.isProtected(app.bundleID) || app.bundleID == Bundle.main.bundleIdentifier {
            record("\(app.name) is a meeting app, so MeetingMute never touches it")
            return
        }
        hiddenIDs.remove(app.bundleID)
        suggestedIDs.remove(app.bundleID)
        addExtra(app)
        record("Added \(app.name)")
    }

    /// Called with the bundle IDs of processes recording audio. An unknown app recording
    /// audio may be a notetaker, so it's suggested (but never muted until the user says so).
    func noteMicrophoneUsers(_ bundleIDs: [String]) {
        guard !bundleIDs.isEmpty, !Demo.isOn else { return }
        let listed = Set(recorders.map(\.id)).union(hiddenIDs).union(extraIDs)
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            guard let id = app.bundleIdentifier, let url = app.bundleURL,
                  !id.hasPrefix("com.apple."), id != Bundle.main.bundleIdentifier, !listed.contains(id),
                  !MeetingApp.isProtected(id), !Registry.isQuietMicrophoneApp(id),
                  // Helper bundles nested inside another app.
                  !url.deletingLastPathComponent().path.contains(".app/"),
                  bundleIDs.contains(where: { BundleID.matches($0, base: id) }),
                  let installed = catalog.register(url) else { continue }
            suggestedIDs.insert(installed.bundleID)
            addExtra(installed)
            record("Found \(installed.name) using the microphone")
        }
    }

    /// Takes an app off the list; it won't be suggested again until added by hand.
    func remove(_ recorder: RecorderApp) {
        extraIDs.removeAll { $0 == recorder.id }
        mutedIDs.remove(recorder.id)
        suggestedIDs.remove(recorder.id)
        if onlyID == recorder.id {
            // "All but one" with nobody left allowed is "Mute all"; say so.
            onlyID = nil
            if mode == .allButOne { mode = .all }
        }
        hiddenIDs.insert(recorder.id)
        var paths = defaults.stringArray(forKey: "extraPaths") ?? []
        paths.removeAll { $0 == recorder.app.url.path }
        defaults.set(paths, forKey: "extraPaths")
        save()
        record("Removed \(recorder.displayName)")
    }

    /// Apps the user took off the list that are still installed.
    var removedApps: [InstalledApp] {
        hiddenIDs.compactMap { catalog.installed[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Puts a removed app back on the list.
    func restore(_ app: InstalledApp) {
        hiddenIDs.remove(app.bundleID)
        if Registry.match(bundleID: app.bundleID, names: [app.name, app.fileName]) == nil { addExtra(app) }
        save()
        record("Added \(app.name)")
    }

    /// Where an app on the list came from.
    func source(of recorder: RecorderApp) -> String {
        if recorder.known != nil { return "Built-in" }
        return suggestedIDs.contains(recorder.id) ? "Found" : "Added"
    }

    private func addExtra(_ app: InstalledApp) {
        guard !extraIDs.contains(app.bundleID) else { return }
        extraIDs.append(app.bundleID)
        var paths = defaults.stringArray(forKey: "extraPaths") ?? []
        if !paths.contains(app.url.path) { paths.append(app.url.path) }
        defaults.set(paths, forKey: "extraPaths")
        save()
    }

    func open(_ recorder: RecorderApp) {
        NSWorkspace.shared.openApplication(at: recorder.app.url, configuration: .init())
    }

    func rescan() { catalog.rescan() }

    // MARK: Activity

    func record(_ message: String) {
        log = ActivityLog.appending(message, at: .now, to: log)
        if let data = try? JSONEncoder().encode(log) { defaults.set(data, forKey: "log") }
    }

    func countSilenced() {
        silencedTotal += 1
        defaults.set(silencedTotal, forKey: "silencedTotal")
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
        defaults.set(Array(suggestedIDs), forKey: "suggested")
        defaults.set(Array(hiddenIDs), forKey: "hidden")
    }
}
