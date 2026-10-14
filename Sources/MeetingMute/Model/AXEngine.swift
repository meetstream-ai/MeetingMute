import AppKit
import ApplicationServices
import MeetingMuteCore

/// A running app the user muted.
struct MuteTarget: Sendable {
    let pid: pid_t
    let bundleID: String
    let displayName: String
    /// Lower-case names a Notification Center banner from this app can start with.
    let bannerNames: Set<String>
    let known: KnownApp?
    let launchedAt: Date?
}

struct EngineRequest: Sendable {
    /// Muted apps that are running. Sent even while paused, so the engine keeps track of
    /// which windows were already open.
    let targets: [MuteTarget]
    let inMeeting: Bool
    /// False while MeetingMute is off or paused for this meeting: track, but don't act.
    let suppress: Bool
    let closeBanners: Bool
    let notificationCenterPID: pid_t?
}

enum EngineEvent: Sendable {
    case closedPopup(app: String)
    case hidPopup(app: String)
    case closedBanner(app: String)
    /// For diagnostics only.
    case note(String)
}

/// Does the Accessibility work on its own serial queue, so a slow or hung app never blocks
/// the UI. All state below is confined to `queue`.
///
/// Popups: during a meeting, a muted app's window is a candidate only when it is new (it
/// appeared shortly before the call or after), prompt-sized, not the window the user is in,
/// and its text is about a meeting. MeetingMute then presses that app's decline button once
/// (never a button that records, joins or changes settings). Only for known apps whose own
/// prompt wording matched does it fall back to the window's close button, or to moving the
/// window off-screen until the call ends.
///
/// Banners: Notification Center banners from muted apps are closed with their own localized
/// "Close" action. On macOS 26 all banners share one host window, which is never hidden.
final class AXEngine: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ai.meetstream.MeetingMute.accessibility", qos: .userInitiated)

    private struct WindowInfo {
        let id: CGWindowID
        let pid: pid_t
        let layer: Int
        let bounds: CGRect
        let alpha: Double
    }

    private struct Record {
        var size: CGSize = .zero
        var looks = 0
        var actedAt: Date?
        var done = false
    }

    private struct Parked {
        let pid: pid_t
        let window: AXUIElement
        let origin: CGPoint
        var moves = 1
        var attempts = 0
    }

    static let offscreen = CGPoint(x: -30_000, y: -30_000)
    /// A window that appeared this long before the call started still counts as new.
    private static let lead: TimeInterval = 8
    /// One scan never runs longer than this, however slow the other apps are.
    private static let budget: TimeInterval = 2

    private var meetingActive = false
    private var suppressing = false
    private var firstSeen: [CGWindowID: Date] = [:]
    /// Windows that were open before the call (or before a resume, or before the app was
    /// muted), with their size then. One that changes size, like a floating bar that expands
    /// into a "Meeting detected" card, is looked at again.
    private var baseline: [CGWindowID: CGSize] = [:]
    private var trackedPIDs: Set<pid_t> = []
    private var records: [CGWindowID: Record] = [:]
    private var parked: [Parked] = []
    private var exposed: Set<pid_t> = []
    private var closedBanners: [String: Date] = [:]
    private var reported: Set<String> = []
    private lazy var closeNames = Self.notificationCenterNames(for: "Close")
    private lazy var clearAllNames = Self.notificationCenterNames(for: "Clear All")

    func run(_ request: EngineRequest, completion: @escaping @Sendable ([EngineEvent]) -> Void) {
        queue.async { completion(self.scan(request)) }
    }

    /// Puts every hidden window back and undoes the Electron accessibility switch. Blocks;
    /// used when MeetingMute quits.
    func restoreAllSync() {
        queue.sync {
            restore { _ in true }
            unexpose()
        }
    }

    /// Windows left off-screen by an earlier run that didn't quit cleanly.
    func recoverStranded(pids: [pid_t]) {
        queue.async {
            for pid in pids {
                for window in AX.windows(of: pid) {
                    guard let p = AX.position(window), p.x < -10_000 || p.y < -10_000 else { continue }
                    AX.setPosition(window, CGPoint(x: 120, y: 120))
                }
            }
        }
    }

    // MARK: Scan

    private func scan(_ request: EngineRequest) -> [EngineEvent] {
        if request.targets.isEmpty, !meetingActive, parked.isEmpty, !request.closeBanners { return [] }
        let deadline = Date().addingTimeInterval(Self.budget)
        let windows = Self.onScreenWindows()
        let now = Date()
        let targets = Dictionary(request.targets.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })

        // Remember when each muted app's window first appeared, and forget windows that closed.
        var onScreen: Set<CGWindowID> = []
        for w in windows where targets[w.pid] != nil {
            onScreen.insert(w.id)
            if firstSeen[w.id] == nil { firstSeen[w.id] = now }
        }
        firstSeen = firstSeen.filter { onScreen.contains($0.key) }
        records = records.filter { onScreen.contains($0.key) }

        let acting = request.inMeeting && request.suppress
        if request.inMeeting, !meetingActive {
            // The call started: windows open well before it are the user's, not prompts.
            meetingActive = true
            records = [:]
            baseline = sizes(of: windows) { now.timeIntervalSince(self.firstSeen[$0.id] ?? now) > Self.lead }
        } else if !request.inMeeting, meetingActive {
            meetingActive = false
            baseline = [:]
            records = [:]
            unexpose()
        }
        if acting, !suppressing, meetingActive {
            // Resumed (or switched on) mid-call: whatever is on screen now stays.
            baseline.merge(sizes(of: windows) { targets[$0.pid] != nil }) { old, _ in old }
        }
        if meetingActive {
            // An app muted mid-call: its windows that were already open stay.
            for (pid, target) in targets where !trackedPIDs.contains(pid) {
                let fresh = target.launchedAt.map { now.timeIntervalSince($0) < Self.lead } ?? false
                if !fresh { baseline.merge(sizes(of: windows) { $0.pid == pid }) { old, _ in old } }
            }
        }
        trackedPIDs = Set(targets.keys)
        suppressing = acting

        // Outside an active, unpaused meeting every hidden window goes back (and is retried
        // until it does); during one, only windows of apps that were unmuted or quit.
        if !acting {
            if !parked.isEmpty { restore { _ in true } }
        } else if !parked.isEmpty {
            restore { targets[$0] == nil }
        }

        var events: [EngineEvent] = []
        if acting {
            for target in request.targets where Date() < deadline {
                events += dismissPopups(of: target, windows: windows.filter { $0.pid == target.pid },
                                        now: now, deadline: deadline)
            }
            keepParked()
        }
        if request.closeBanners, request.suppress, let nc = request.notificationCenterPID,
           windows.contains(where: { $0.pid == nc }), Date() < deadline {
            events += closeBanners(request.targets, notificationCenter: nc, now: now, deadline: deadline)
        }
        return events
    }

    private func sizes(of windows: [WindowInfo], where include: (WindowInfo) -> Bool) -> [CGWindowID: CGSize] {
        Dictionary(windows.filter(include).map { ($0.id, $0.bounds.size) }, uniquingKeysWith: { a, _ in a })
    }

    private func unexpose() {
        for pid in exposed { AX.setManualAccessibility(pid, false) }
        exposed = []
    }

    // MARK: Popups

    private func dismissPopups(of target: MuteTarget, windows: [WindowInfo], now: Date,
                               deadline: Date) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var axWindows: [CGWindowID: AXUIElement]?
        let fullScreen = target.known?.fullScreen ?? false

        for w in windows where w.alpha > 0.01 && Date() < deadline {
            if let before = baseline[w.id], !Self.resized(before, w.bounds.size) { continue }
            var record = records[w.id, default: Record(size: w.bounds.size)]
            // Same window, new content: a bar that grew into a prompt, or a prompt shown again.
            if Self.resized(record.size, w.bounds.size) { record = Record(size: w.bounds.size) }
            defer { records[w.id] = record }
            guard !record.done else { continue }

            if let acted = record.actedAt {
                // Pressed, but still on screen a moment later: move it out of sight, if this app
                // is one MeetingMute may hide.
                if now.timeIntervalSince(acted) > 1.5 {
                    record.done = true
                    if axWindows == nil { axWindows = Self.axWindows(of: target.pid, matching: windows) }
                    if let ax = axWindows?[w.id], Self.mayForce(target, texts: Self.read(ax).texts),
                       park(ax, pid: target.pid) {
                        events.append(.hidPopup(app: target.displayName))
                    }
                }
                continue
            }

            guard w.bounds.width >= 40, w.bounds.height >= 24,
                  DismissPolicy.isPromptSized(width: w.bounds.width, height: w.bounds.height, fullScreenAllowed: fullScreen)
            else { record.done = true; continue }

            if axWindows == nil { axWindows = Self.axWindows(of: target.pid, matching: windows) }
            guard let ax = axWindows?[w.id] else {
                record.looks += 1
                if record.looks > 8 { record.done = true }
                continue
            }
            // The window the user is working in is never a prompt, at any window level.
            if AX.bool(ax, kAXMainAttribute) == true || AX.bool(ax, kAXFocusedAttribute) == true {
                record.done = true
                continue
            }

            let content = Self.read(ax)
            if content.texts.isEmpty, !exposed.contains(target.pid) {
                // Electron keeps web content out of Accessibility until asked. Undone after the call.
                AX.setManualAccessibility(target.pid, true)
                exposed.insert(target.pid)
                record.looks += 1
                continue
            }
            guard DismissPolicy.looksLikeMeetingPrompt(content.texts, for: target.known) else {
                // Web content can still be loading; look a few more times.
                record.looks += 1
                if record.looks >= 8 { record.done = true }
                continue
            }

            if let label = DismissPolicy.bestLabel(among: content.buttons.map(\.label), for: target.known),
               let button = content.buttons.first(where: { $0.label == label }), AX.press(button.element) {
                record.actedAt = now
                events.append(.closedPopup(app: target.displayName))
            } else if let cancel = AX.element(ax, kAXCancelButtonAttribute), Self.isSafe(cancel, for: target.known),
                      AX.press(cancel) {
                record.actedAt = now
                events.append(.closedPopup(app: target.displayName))
            } else if Self.mayForce(target, texts: content.texts) {
                if let close = AX.element(ax, kAXCloseButtonAttribute), AX.press(close) {
                    record.actedAt = now
                    events.append(.closedPopup(app: target.displayName))
                } else {
                    record.done = true
                    if park(ax, pid: target.pid) { events.append(.hidPopup(app: target.displayName)) }
                }
            } else {
                // Nothing safe to press, and not sure enough it's a prompt: leave it alone.
                record.done = true
            }
        }
        return events
    }

    /// Close or hide a window only for apps in the registry whose prompt wording matched.
    private static func mayForce(_ target: MuteTarget, texts: [String]) -> Bool {
        guard let known = target.known else { return false }
        return DismissPolicy.isConfidentPrompt(texts, for: known)
    }

    private static func resized(_ a: CGSize, _ b: CGSize) -> Bool {
        abs(a.width - b.width) > 20 || abs(a.height - b.height) > 20
    }

    private struct Content {
        var texts: [String] = []
        var buttons: [(label: String, element: AXUIElement)] = []
    }

    private static func read(_ window: AXUIElement) -> Content {
        var content = Content()
        AX.walk(window, maxNodes: 300) { element, _ in
            let role = AX.string(element, kAXRoleAttribute) ?? ""
            let texts = AX.visibleTexts(element)
            content.texts += texts
            if role == (kAXButtonRole as String) {
                let label = texts.first ?? AX.string(element, kAXHelpAttribute) ?? ""
                if !label.isEmpty { content.buttons.append((label, element)) }
                return true
            }
            return false
        }
        return content
    }

    /// The Escape button is safe when its label is empty or a known decline.
    private static func isSafe(_ button: AXUIElement, for app: KnownApp?) -> Bool {
        guard let label = AX.visibleTexts(button).first else { return true }
        return DismissPolicy.rank(of: label, for: app) != nil
    }

    // MARK: Hiding

    private func park(_ window: AXUIElement, pid: pid_t) -> Bool {
        guard let origin = AX.position(window), origin.x > -10_000 else { return false }
        guard AX.setPosition(window, Self.offscreen) == .success else { return false }
        parked.append(Parked(pid: pid, window: window, origin: origin))
        return true
    }

    /// Apps move their popups back; move them away again, but don't fight a window that the
    /// system keeps clamping on screen.
    private func keepParked() {
        for i in parked.indices {
            guard let p = AX.position(parked[i].window), p.x > -10_000, parked[i].moves < 20 else { continue }
            AX.setPosition(parked[i].window, Self.offscreen)
            parked[i].moves += 1
        }
    }

    /// Puts windows back. A window that's gone is forgotten; one whose app is busy is retried
    /// on later scans (for about a minute).
    private func restore(where shouldRestore: (pid_t) -> Bool) {
        parked = parked.compactMap { entry in
            guard shouldRestore(entry.pid) else { return entry }
            let result = AX.setPosition(entry.window, entry.origin)
            if result == .success || result == .invalidUIElement { return nil }
            var retry = entry
            retry.attempts += 1
            return retry.attempts < 120 ? retry : nil
        }
    }

    // MARK: Banners

    private func closeBanners(_ targets: [MuteTarget], notificationCenter pid: pid_t, now: Date,
                              deadline: Date) -> [EngineEvent] {
        closedBanners = closedBanners.filter { now.timeIntervalSince($0.value) < 10 }
        guard !targets.isEmpty else { return [] }
        var byName: [String: MuteTarget] = [:]
        for t in targets { for name in t.bannerNames where byName[name] == nil { byName[name] = t } }

        var events: [EngineEvent] = []
        for window in AX.windows(of: pid) where Date() < deadline {
            AX.walk(window, maxNodes: 600, maxDepth: 16) { element, _ in
                guard Date() < deadline else { return true }
                let subrole = AX.string(element, kAXSubroleAttribute) ?? ""
                let identifier = AX.string(element, kAXIdentifierAttribute) ?? ""
                // The Notification Center history panel, not a banner.
                if subrole.contains("ListItems") || identifier.contains("ListItems") { return true }
                guard BannerText.subroles.contains(subrole),
                      let description = AX.string(element, kAXDescriptionAttribute),
                      let name = BannerText.appName(fromDescription: description),
                      let target = byName[name.lowercased()] else { return false }

                // Still animating out after a close a moment ago.
                let key = identifier.isEmpty ? description : identifier
                if closedBanners[key] != nil { return true }
                let actions = AX.actionNames(element)
                var action = BannerText.closeAction(in: actions, closeNames: closeNames)
                if action == nil, subrole.hasSuffix("Stack") {
                    action = BannerText.closeAction(in: actions, closeNames: clearAllNames)
                }
                if let action, AX.perform(element, action) {
                    closedBanners[key] = now
                    events.append(.closedBanner(app: target.displayName))
                    return true
                }
                if reported.insert(target.bundleID).inserted {
                    let labels = actions.map(BannerText.actionLabel).joined(separator: ", ")
                    events.append(.note("No single Close action on a \(target.displayName) banner (\(subrole)): \(labels)"))
                }
                return false
            }
        }
        return events
    }

    /// Every translation of a Notification Center button, so banners close on any language.
    static func notificationCenterNames(for key: String) -> Set<String> {
        var names: Set<String> = [key]
        let url = URL(fileURLWithPath:
            "/System/Library/CoreServices/NotificationCenter.app/Contents/Resources/Localizable.loctable")
        if let data = try? Data(contentsOf: url),
           let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for case let strings as [String: Any] in table.values {
                if let value = strings[key] as? String { names.insert(value) }
            }
        }
        return names
    }

    // MARK: Windows

    private static func onScreenWindows() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return WindowInfo(id: id, pid: pid, layer: info[kCGWindowLayer as String] as? Int ?? 0,
                              bounds: rect, alpha: info[kCGWindowAlpha as String] as? Double ?? 1)
        }
    }

    /// An app's AX windows keyed by CGWindowID; by frame when the ID isn't available.
    private static func axWindows(of pid: pid_t, matching windows: [WindowInfo]) -> [CGWindowID: AXUIElement] {
        var result: [CGWindowID: AXUIElement] = [:]
        for ax in AX.windows(of: pid) {
            if let id = AX.windowID(ax) {
                result[id] = ax
            } else if let p = AX.position(ax), let s = AX.size(ax),
                      let match = windows.first(where: {
                          abs($0.bounds.minX - p.x) < 2 && abs($0.bounds.minY - p.y) < 2 &&
                          abs($0.bounds.width - s.width) < 2 && abs($0.bounds.height - s.height) < 2
                      }) {
                result[match.id] = ax
            }
        }
        return result
    }
}
