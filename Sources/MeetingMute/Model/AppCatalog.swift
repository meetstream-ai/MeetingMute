import AppKit
import MeetingMuteCore
import Observation

/// An app bundle found on disk, identified by the bundle ID in its Info.plist.
struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    /// The file name without `.app` (can differ from the display name).
    let fileName: String
    let url: URL

    var id: String { bundleID }

    @MainActor var icon: NSImage { IconCache.icon(for: url) }

    init?(url: URL) {
        guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              let id = info["CFBundleIdentifier"] as? String else { return nil }
        bundleID = id
        fileName = url.deletingPathExtension().lastPathComponent
        name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? fileName
        self.url = url
    }

    init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        fileName = url.deletingPathExtension().lastPathComponent
        self.url = url
    }
}

@MainActor
private enum IconCache {
    static var icons: [URL: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        if let icon = icons[url] { return icon }
        let icon = Demo.icon(for: url) ?? NSWorkspace.shared.icon(forFile: url.path)
        icons[url] = icon
        return icon
    }
}

/// Installed and running apps.
@MainActor
@Observable
final class AppCatalog {
    private(set) var installed: [String: InstalledApp] = [:] {
        didSet { generation += 1 }
    }
    private(set) var running: Set<String> = []
    /// Bumped whenever `installed` changes, so lists built from it can be cached.
    private(set) var generation = 0

    static let searchFolders: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/Applications/Setapp"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        if Demo.isOn {
            installed = Demo.installed
            running = Demo.running
            return
        }
        rescan()
        refreshRunning()
        let center = NSWorkspace.shared.notificationCenter
        // Each launch also registers the app, so ones installed after start-up (or outside
        // the scanned folders) show up without a restart.
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let url = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleURL
            MainActor.assumeIsolated {
                if let url { self?.register(url) }
                self?.refreshRunning()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshRunning() }
        })
    }

    /// Scans the usual folders, then asks LaunchServices for every app in the registry, which
    /// also finds apps in subfolders and other volumes.
    func rescan() {
        guard !Demo.isOn else { return }
        var found: [String: InstalledApp] = [:]
        let fm = FileManager.default
        for folder in Self.searchFolders {
            let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in items where url.pathExtension == "app" {
                if let app = InstalledApp(url: url), found[app.bundleID] == nil { found[app.bundleID] = app }
            }
        }
        for id in Registry.apps.flatMap(\.bundleIDs) where found[id] == nil {
            if let url = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: id).first,
               !url.path.contains("/.Trash/"), let app = InstalledApp(url: url) {
                found[app.bundleID] = app
            }
        }
        // Keep apps added by hand from elsewhere, if they still exist.
        for (id, app) in installed where found[id] == nil && fm.fileExists(atPath: app.url.path) { found[id] = app }
        if found != installed { installed = found }
    }

    /// Adds an app picked by hand from anywhere on disk.
    @discardableResult
    func register(_ url: URL) -> InstalledApp? {
        guard let app = InstalledApp(url: url) else { return nil }
        if installed[app.bundleID] == nil { installed[app.bundleID] = app }
        return installed[app.bundleID]
    }

    func isRunning(_ bundleID: String) -> Bool { running.contains(bundleID) }

    func refreshRunning() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if next != running { running = next }
    }
}
