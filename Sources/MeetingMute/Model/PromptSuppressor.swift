import AppKit
import ApplicationServices
import CoreAudio
import Observation

/// Mutes notetakers using the Accessibility API:
/// - their macOS notification banners are closed whenever MeetingMute is on;
/// - during a meeting, their popup windows are dismissed (via the popup's own dismiss or
///   close button) or, failing that, parked off-screen until the meeting ends.
///
/// Safety rules: only apps the user muted are touched; allowed apps, meeting apps
/// (Zoom, Teams, browsers…) and MeetingMute itself never are. Nothing is written to disk.
@MainActor
@Observable
final class PromptSuppressor {
    enum State: Equatable {
        case idle
        case inMeeting
    }

    private(set) var state: State = .idle
    /// Polled, since the user grants it in System Settings.
    private(set) var hasAccessibility = AXIsProcessTrusted()

    private let prompts: MeetingPromptsStore
    private let catalog: AppCatalog
    @ObservationIgnored private var timer: Timer?
    /// Popups already dismissed this meeting, so each is logged once.
    @ObservationIgnored private var handled: [AXUIElement] = []
    @ObservationIgnored private var quietTicks = 0
    @ObservationIgnored private var detectTicks = 0
    /// Banners already closed (by AX identifier), so one still animating out isn't logged twice.
    @ObservationIgnored private var closedBanners: [String] = []
    /// Popups with no button to dismiss them, moved off-screen, with where they were. Apps
    /// re-show their popups, so they're kept there all meeting and put back afterwards.
    @ObservationIgnored private var parked: [(pid: pid_t, window: AXUIElement, origin: CGPoint)] = []
    /// Apps whose web content (Electron) has been exposed to Accessibility.
    @ObservationIgnored private var webAccessible: Set<pid_t> = []

    init(prompts: MeetingPromptsStore, catalog: AppCatalog) {
        self.prompts = prompts
        self.catalog = catalog
        // Already in a meeting at launch: don't treat existing windows as new prompts.
        if Self.meetingSignal().active { state = .inMeeting }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.unpark { _ in true } }
        }
    }

    // MARK: Meeting detection

    /// A meeting is happening when Zoom's meeting helper runs, or a meeting app (Zoom, Teams,
    /// Webex, FaceTime, Slack, Discord, a browser for Meet) is capturing the microphone.
    /// Notetakers listening on their own don't count.
    nonisolated static func meetingSignal() -> (active: Bool, source: String) {
        if NSWorkspace.shared.runningApplications.contains(where: {
            $0.executableURL?.lastPathComponent == "CptHost"
        }) {
            return (true, "Zoom meeting")
        }
        if let app = meetingAppUsingMicrophone() { return (true, "\(app) using the microphone") }
        return (false, "")
    }

    /// Bundle-ID prefixes of meeting apps; helper processes (e.g. `com.google.Chrome.helper`) match too.
    nonisolated private static let meetingPrefixes: [(prefix: String, name: String)] = MeetingApp.known
        .flatMap { app in app.bundleIDs.map { ($0, app.name) } }
        + [("com.apple.WebKit", "Safari"), ("com.apple.TelephonyUtilities", "FaceTime"),
           ("com.apple.avconferenced", "FaceTime")]

    /// The meeting app currently capturing audio input, if any.
    nonisolated private static func meetingAppUsingMicrophone() -> String? {
        for bundleID in inputProcessBundleIDs() {
            if let match = meetingPrefixes.first(where: { bundleID.hasPrefix($0.prefix) }) { return match.name }
        }
        return nil
    }

    /// Bundle IDs of every process with audio input running.
    nonisolated private static func inputProcessBundleIDs() -> [String] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }

        return processes.compactMap { process in
            var running: UInt32 = 0
            var length = UInt32(MemoryLayout<UInt32>.size)
            address.mSelector = kAudioProcessPropertyIsRunningInput
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &length, &running) == noErr,
                  running != 0 else { return nil }
            var bundleID: Unmanaged<CFString>?
            length = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            address.mSelector = kAudioProcessPropertyBundleID
            guard AudioObjectGetPropertyData(process, &address, 0, nil, &length, &bundleID) == noErr else { return nil }
            return bundleID?.takeRetainedValue() as String?
        }
    }

    // MARK: Accessibility

    /// Shows the system prompt, which offers to open System Settings.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        if !AXIsProcessTrustedWithOptions([key: true] as CFDictionary) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    private var mutedNames: String {
        prompts.muted.map(\.displayName).formatted(.list(type: .and))
    }

    // MARK: Loop

    private func tick() {
        let trusted = AXIsProcessTrusted()
        if trusted != hasAccessibility { hasAccessibility = trusted }
        detectTicks += 1
        if detectTicks % 10 == 0 { prompts.noteMicrophoneUsers(Self.inputProcessBundleIDs()) }

        let signal = Self.meetingSignal()
        switch state {
        case .idle:
            if signal.active { meetingStarted() }
        case .inMeeting:
            // Require ~5s of silence so a brief mic gap doesn't count as a new meeting.
            quietTicks = signal.active ? 0 : quietTicks + 1
            if quietTicks >= 10 {
                state = .idle
                prompts.record("Meeting ended")
                unpark { _ in true }
            }
        }

        if prompts.isEnabled, hasAccessibility {
            if state == .inMeeting { dismissPopups() }
            // Banners are closed any time: notetakers also notify before a call starts
            // (calendar reminders) and after it ends.
            closeNotificationBanners()
        }
        // Unmuted (or muting switched off): put its popups back right away.
        if !parked.isEmpty {
            let muted = Set(targets().map(\.processIdentifier))
            unpark { !prompts.isEnabled || !muted.contains($0) }
        }
    }

    private func meetingStarted() {
        handled = []
        quietTicks = 0
        state = .inMeeting
        let message: String
        if !prompts.isEnabled || prompts.muted.isEmpty {
            message = "nothing muted"
        } else if !hasAccessibility {
            message = "can't mute without Accessibility"
        } else {
            message = "muting \(mutedNames)"
        }
        prompts.record("Meeting started · \(message)")
    }

    // MARK: Dismissing

    /// Running apps the user muted, excluding meeting apps and anything allowed.
    private func targets() -> [NSRunningApplication] {
        let protected = Set(MeetingApp.known.flatMap(\.bundleIDs))
            .union(prompts.allowed.map(\.id))
            .union([Bundle.main.bundleIdentifier ?? ""])
        let ids = Set(mutableRecorders.map(\.id)).subtracting(protected)
        return NSWorkspace.shared.runningApplications.filter { app in
            guard let id = app.bundleIdentifier else { return false }
            return ids.contains(id)
        }
    }

    /// Muted apps that are safe to act on (never a meeting app like Zoom).
    private var mutableRecorders: [RecorderApp] {
        let meetingIDs = Set(MeetingApp.known.flatMap(\.bundleIDs))
        return prompts.muted.filter { !meetingIDs.contains($0.id) }
    }

    /// Dismisses popup-style windows from muted apps. Runs every tick of a meeting, since
    /// apps re-show popups (and pre-create them hidden).
    private func dismissPopups() {
        let names = Dictionary(mutableRecorders.map { ($0.id, $0.displayName) }, uniquingKeysWith: { a, _ in a })
        for app in targets() {
            let pid = app.processIdentifier
            if webAccessible.insert(pid).inserted { Self.exposeWebContent(pid) }
            let name = app.bundleIdentifier.flatMap { names[$0] } ?? app.localizedName ?? "app"
            for window in Self.windows(of: pid) where Self.isPopupLike(window) {
                let isParked = parked.contains { CFEqual($0.window, window) }
                if !isParked, Self.pressDismissButton(in: window) || Self.close(window) {
                    log(window, "Closed \(name) popup")
                } else if let origin = Self.position(of: window), origin.x > Self.offscreen.x / 2 {
                    // No button to press: move it away, and again whenever the app moves it back.
                    if !isParked { parked.append((pid, window, origin)) }
                    Self.setPosition(of: window, to: Self.offscreen)
                    log(window, "Moved \(name) popup out of sight")
                }
            }
        }
    }

    private func log(_ window: AXUIElement, _ message: String) {
        guard !handled.contains(where: { CFEqual($0, window) }) else { return }
        handled.append(window)
        prompts.record(message)
    }

    /// Puts parked popups back where they were, for apps matching `shouldRestore`.
    private func unpark(where shouldRestore: (pid_t) -> Bool) {
        parked.removeAll { entry in
            guard shouldRestore(entry.pid) else { return false }
            Self.setPosition(of: entry.window, to: entry.origin)
            return true
        }
    }

    nonisolated private static let offscreen = CGPoint(x: -30_000, y: -30_000)

    nonisolated private static func position(of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        var point = CGPoint.zero
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    nonisolated private static func setPosition(of window: AXUIElement, to point: CGPoint) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    /// Electron apps (Granola, Circleback…) only expose their web content to Accessibility
    /// when asked, which is where a popup's dismiss button lives.
    nonisolated private static func exposeWebContent(_ pid: pid_t) {
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    nonisolated private static let dismissLabels: Set<String> = [
        "dismiss", "close", "not now", "ignore", "no thanks", "no, thanks", "skip", "later",
        "maybe later", "cancel", "x", "×", "✕", "✖",
    ]

    /// Presses a button labelled like "Dismiss" / "Not now" / "×" inside the popup.
    nonisolated private static func pressDismissButton(in window: AXUIElement) -> Bool {
        var target: AXUIElement?
        walk(window, depth: 0, maxDepth: 25) { element in
            guard target == nil else { return true }
            guard string(element, kAXRoleAttribute) == (kAXButtonRole as String) else { return false }
            let labels = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
                .compactMap { string(element, $0)?.trimmingCharacters(in: .whitespaces).lowercased() }
            if labels.contains(where: { dismissLabels.contains($0) || $0.hasPrefix("dismiss") }) { target = element }
            return true
        }
        guard let target else { return false }
        return AXUIElementPerformAction(target, kAXPressAction as CFString) == .success
    }

    nonisolated private static func windows(of pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    /// Small or non-standard windows (floating panels, "meeting detected" toasts, indicators).
    nonisolated private static func isPopupLike(_ window: AXUIElement) -> Bool {
        if let subrole = string(window, kAXSubroleAttribute), subrole != (kAXStandardWindowSubrole as String) {
            return true
        }
        var value: CFTypeRef?
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue(value as! AXValue, .cgSize, &size) else { return false }
        return size.width * size.height < 500 * 400
    }

    /// Presses the window's close button. Returns false if it has none.
    nonisolated private static func close(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &value) == .success,
              let button = value, CFGetTypeID(button) == AXUIElementGetTypeID() else { return false }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    /// Closes macOS notification banners posted by muted apps. Banners belong to Notification
    /// Center's process; their description starts with the posting app's name, e.g.
    /// "Granola, Meeting detected, Chrome".
    private func closeNotificationBanners() {
        let recorders = mutableRecorders
        guard !recorders.isEmpty,
              let center = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        let prefixes = recorders.flatMap { recorder in
            Set([recorder.displayName, recorder.app.name]).map { ("\($0.lowercased()), ", recorder) }
        }
        for window in Self.windows(of: center.processIdentifier) {
            Self.walk(window, depth: 0) { element in
                guard let subrole = Self.string(element, kAXSubroleAttribute),
                      subrole.hasPrefix("AXNotificationCenter"),
                      let text = Self.string(element, kAXDescriptionAttribute) else { return false }
                let lower = text.lowercased()
                guard let (_, recorder) = prefixes.first(where: { lower.hasPrefix($0.0) }) else {
                    return false  // Not a muted app (or a stack): look inside.
                }
                let bannerID = Self.string(element, kAXIdentifierAttribute) ?? text
                if Self.performClose(element), !closedBanners.contains(bannerID) {
                    closedBanners = Array((closedBanners + [bannerID]).suffix(20))
                    prompts.record("Closed \(recorder.displayName) notification")
                }
                return true
            }
        }
    }

    /// Depth-first walk; `visit` returns true to stop descending into that element.
    nonisolated private static func walk(_ element: AXUIElement, depth: Int, maxDepth: Int = 8,
                                         visit: (AXUIElement) -> Bool) {
        guard depth < maxDepth, !visit(element) else { return }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return }
        for child in children { walk(child, depth: depth + 1, maxDepth: maxDepth, visit: visit) }
    }

    nonisolated private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    /// Runs the banner's "Close" action (a named custom action on Notification Center banners).
    nonisolated private static func performClose(_ element: AXUIElement) -> Bool {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let actions = names as? [String],
              let close = actions.first(where: { $0.localizedCaseInsensitiveContains("close") }) else { return false }
        return AXUIElementPerformAction(element, close as CFString) == .success
    }
}
