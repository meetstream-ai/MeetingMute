import AppKit
import Observation

/// An app bundle found on disk, identified by the bundle ID in its Info.plist.
struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL

    var id: String { bundleID }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }

    init?(url: URL) {
        guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              let id = info["CFBundleIdentifier"] as? String else { return nil }
        bundleID = id
        name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        self.url = url
    }
}

/// Installed and running apps.
@MainActor
@Observable
final class AppCatalog {
    private(set) var installed: [String: InstalledApp] = [:]
    private(set) var running: Set<String> = []

    static let searchFolders: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/Applications/Setapp"),
        URL(fileURLWithPath: "/System/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        rescan()
        refreshRunning()
        let center = NSWorkspace.shared.notificationCenter
        // Every launch also registers the app, so ones installed after start-up (or outside
        // the scanned folders) show up without a restart.
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                            object: nil, queue: .main) { [weak self] note in
            let url = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleURL
            Task { @MainActor in
                if let url { self?.register(url) }
                self?.refreshRunning()
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshRunning() }
        })
    }

    func rescan() {
        var found: [String: InstalledApp] = [:]
        let fm = FileManager.default
        for folder in Self.searchFolders {
            let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in items where url.pathExtension == "app" {
                if let app = InstalledApp(url: url), found[app.bundleID] == nil { found[app.bundleID] = app }
            }
        }
        installed = found
    }

    /// Adds an app picked by hand from anywhere on disk.
    @discardableResult
    func register(_ url: URL) -> InstalledApp? {
        guard let app = InstalledApp(url: url) else { return nil }
        installed[app.bundleID] = installed[app.bundleID] ?? app
        return installed[app.bundleID]
    }

    func isRunning(_ bundleID: String) -> Bool { running.contains(bundleID) }

    func refreshRunning() {
        let next = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if next != running { running = next }
    }
}
