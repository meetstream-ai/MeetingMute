import AppKit
import ApplicationServices
import MeetingMuteCore
import Observation

/// Watches for meetings and drives `AXEngine`, which closes popups and banners from muted
/// apps. Meeting apps, browsers, allowed apps and MeetingMute itself are never touched.
@MainActor
@Observable
final class PromptSuppressor {
    enum State: Equatable {
        case idle
        case inMeeting
    }

    private(set) var state: State = .idle
    /// What started the current meeting ("Zoom", "Chrome"…).
    private(set) var meetingSource: String?
    private(set) var meetingStart: Date?
    private(set) var silencedThisMeeting = 0
    /// Polled, since the user grants it in System Settings.
    private(set) var hasAccessibility = AXIsProcessTrusted()
    /// Let everything through until this meeting ends.
    var pausedForMeeting = false {
        didSet {
            guard pausedForMeeting != oldValue, state == .inMeeting else { return }
            prompts.record(pausedForMeeting ? "Paused for this meeting" : "Resumed")
        }
    }
    /// Problems worth a bug report, shown in diagnostics.
    private(set) var notes: [String] = []

    private let prompts: MeetingPromptsStore
    @ObservationIgnored private let engine = AXEngine()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var engineBusy = false
    @ObservationIgnored private var firstSignal: Date?
    @ObservationIgnored private var lastSignal: Date?
    @ObservationIgnored private var lastInputs: [String] = []
    /// The current meeting is in a browser tab.
    @ObservationIgnored private var meetingIsBrowser = false
    @ObservationIgnored private var titleCache: [String: (titles: [String], at: Date)] = [:]
    @ObservationIgnored private var signalSources: [DispatchSourceSignal] = []
    @ObservationIgnored private var notificationCenterPID: pid_t?

    /// A call that goes quiet this long has ended. Native apps keep the microphone open while
    /// muted, but browsers drop it, so this rides out a muted stretch.
    static let meetingEndDelay: TimeInterval = 30

    init(prompts: MeetingPromptsStore) {
        self.prompts = prompts
        if Demo.isOn {
            hasAccessibility = true
            if Demo.inMeeting {
                state = .inMeeting
                meetingSource = "Zoom"
                meetingStart = Date().addingTimeInterval(-754)
                silencedThisMeeting = 4
            }
            return
        }
        AX.setGlobalTimeout(0.3)

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let engine = engine
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { _ in engine.restoreAllSync() }
        // `pkill` and `kill` send SIGTERM, which skips willTerminate: put hidden popups back first.
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                engine.restoreAllSync()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
        if hasAccessibility { engine.recoverStranded(pids: recorderPIDs()) }
    }

    // MARK: Accessibility

    /// Shows the system prompt the first time; after that, opens System Settings.
    func requestAccessibility() {
        let asked = UserDefaults.standard.bool(forKey: "askedForAccessibility")
        UserDefaults.standard.set(true, forKey: "askedForAccessibility")
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": !asked] as CFDictionary)
        if !trusted, asked { openAccessibilitySettings() }
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: Loop

    private func tick() {
        ticks += 1
        let trusted = AXIsProcessTrusted()
        if trusted != hasAccessibility {
            hasAccessibility = trusted
            if trusted { engine.recoverStranded(pids: recorderPIDs()) }
        }
        // Once a second when idle, twice a second in a meeting.
        if state == .inMeeting || ticks % 2 == 0 { detect() }
        if ticks % 10 == 0, prompts.isEnabled { prompts.noteMicrophoneUsers(lastInputs) }
        runEngine()
    }

    private func detect() {
        let inputs = AudioInput.recordingBundleIDs()
        lastInputs = inputs
        // Zoom's meeting helper only exists while Zoom runs.
        let zoomMeeting = !NSRunningApplication.runningApplications(withBundleIdentifier: "us.zoom.xos").isEmpty
            && NSWorkspace.shared.runningApplications.contains { $0.executableURL?.lastPathComponent == "CptHost" }
        // Once a call has started in a browser, it lasts while the browser holds the microphone,
        // even if the user switches to another tab.
        let continuing = state == .inMeeting && meetingIsBrowser
        let signal = MeetingDetection.evaluate(inputs: inputs, zoomMeetingRunning: zoomMeeting,
                                               anyBrowserMicCounts: prompts.anyBrowserMicCounts || continuing,
                                               browserTitles: browserTitles)
        let now = Date()
        switch state {
        case .idle:
            guard let signal else { firstSignal = nil; return }
            // About a second of signal, so a blip doesn't start a meeting.
            if let first = firstSignal, now.timeIntervalSince(first) >= 0.9 {
                meetingStarted(signal, at: now)
            } else if firstSignal == nil {
                firstSignal = now
            }
        case .inMeeting:
            if let signal {
                lastSignal = now
                if meetingSource != signal.source { meetingSource = signal.source }
                meetingIsBrowser = signal.isBrowser
            } else if let last = lastSignal, now.timeIntervalSince(last) > Self.meetingEndDelay {
                meetingEnded()
            }
        }
    }

    private func meetingStarted(_ signal: MeetingSignal, at now: Date) {
        state = .inMeeting
        meetingSource = signal.source
        meetingIsBrowser = signal.isBrowser
        meetingStart = now
        lastSignal = now
        firstSignal = nil
        silencedThisMeeting = 0
        pausedForMeeting = false
        let muted = prompts.muted
        let detail = if !prompts.isEnabled { "MeetingMute is off" }
            else if !hasAccessibility { "needs Accessibility to mute" }
            else if muted.isEmpty { "nothing muted" }
            else { "muting \(muted.map(\.displayName).formatted(.list(type: .and)))" }
        prompts.record("Meeting started in \(signal.source) · \(detail)")
    }

    private func meetingEnded() {
        let silenced = silencedThisMeeting
        state = .idle
        meetingSource = nil
        meetingStart = nil
        pausedForMeeting = false
        prompts.record(silenced > 0 ? "Meeting ended · \(silenced) silenced" : "Meeting ended")
    }

    /// Window titles of a browser using the microphone, to tell a call from voice search.
    private func browserTitles(_ browser: MeetingApp) -> [String] {
        guard hasAccessibility else { return [] }
        if let cached = titleCache[browser.name], Date().timeIntervalSince(cached.at) < 3 { return cached.titles }
        let titles = browser.bundleIDs
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .flatMap { AX.windows(of: $0.processIdentifier) }
            .compactMap { AX.string($0, kAXTitleAttribute) }
        titleCache[browser.name] = (titles, Date())
        return titles
    }

    // MARK: Engine

    private func runEngine() {
        guard !engineBusy else { return }
        // Targets go to the engine whenever it can see them, so it keeps track of which windows
        // were already open; `suppress` says whether to act.
        let suppress = prompts.isEnabled && !(state == .inMeeting && pausedForMeeting)
        let inMeeting = state == .inMeeting
        let banners = suppress && hasAccessibility && (inMeeting || prompts.bannerScope == .always)
        let request = EngineRequest(targets: hasAccessibility ? targets() : [], inMeeting: inMeeting,
                                    suppress: suppress, closeBanners: banners,
                                    notificationCenterPID: banners ? notificationCenter() : nil)
        engineBusy = true
        engine.run(request) { [weak self] events in
            Task { @MainActor in
                self?.engineBusy = false
                self?.handle(events)
            }
        }
    }

    private func handle(_ events: [EngineEvent]) {
        for event in events {
            switch event {
            case .closedPopup(let app):
                silenced("Closed \(app) popup")
            case .hidPopup(let app):
                silenced("Hid \(app) popup until the call ends")
            case .closedBanner(let app):
                silenced("Closed \(app) notification")
            case .note(let text):
                notes = Array((notes + [text]).suffix(20))
            }
        }
    }

    private func silenced(_ message: String) {
        prompts.record(message)
        prompts.countSilenced()
        if state == .inMeeting { silencedThisMeeting += 1 }
    }

    /// Running apps the user muted, minus anything protected.
    private func targets() -> [MuteTarget] {
        let muted = prompts.muted
        guard !muted.isEmpty else { return [] }
        let me = Bundle.main.bundleIdentifier ?? ""
        return NSWorkspace.shared.runningApplications.compactMap { running in
            guard let id = running.bundleIdentifier, id != me, !MeetingApp.isProtected(id),
                  let recorder = muted.first(where: { BundleID.matches(id, base: $0.id) }) else { return nil }
            // The app's own names only: a shared registry name ("ChatGPT") would also match an
            // allowed sibling app.
            var names: Set<String> = [recorder.displayName, recorder.app.name, recorder.app.fileName]
            if let name = running.localizedName { names.insert(name) }
            return MuteTarget(pid: running.processIdentifier, bundleID: id, displayName: recorder.displayName,
                              bannerNames: Set(names.map { $0.lowercased() }), known: recorder.known,
                              launchedAt: running.launchDate)
        }
    }

    private func recorderPIDs() -> [pid_t] {
        let ids = prompts.recorders.map(\.id)
        return NSWorkspace.shared.runningApplications
            .filter { app in app.bundleIdentifier.map { id in ids.contains { BundleID.matches(id, base: $0) } } ?? false }
            .map(\.processIdentifier)
    }

    private func notificationCenter() -> pid_t? {
        if let pid = notificationCenterPID, NSRunningApplication(processIdentifier: pid) != nil { return pid }
        notificationCenterPID = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first?.processIdentifier
        return notificationCenterPID
    }
}
