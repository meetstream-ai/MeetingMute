import AppKit
import MeetingMuteCore
import ServiceManagement

/// Start at login through the system's login items.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an error message when macOS refuses, nil on success.
    static func set(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

/// Shows or hides the Dock icon. The menu bar icon always stays.
enum DockIcon {
    static let key = "showInDock"

    static var isShown: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? true }

    @MainActor
    static func apply(_ shown: Bool) {
        UserDefaults.standard.set(shown, forKey: key)
        NSApp.setActivationPolicy(shown ? .regular : .accessory)
        if !shown { NSApp.activate() }
    }
}

enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    static let repo = URL(string: "https://github.com/meetstream-ai/MeetingMute")!
    static let issues = URL(string: "https://github.com/meetstream-ai/MeetingMute/issues/new/choose")!
    static let supportedApps = URL(string: "https://github.com/meetstream-ai/MeetingMute/blob/main/docs/SUPPORTED_APPS.md")!
    static let meetstream = URL(string: "https://meetstream.ai")!
}

/// Plain-text report for bug reports. Contains no window contents or meeting data.
@MainActor
enum Diagnostics {
    static func report(prompts: MeetingPromptsStore, suppressor: PromptSuppressor) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var lines = [
            "MeetingMute \(AppInfo.version), registry \(Registry.version)",
            "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion), \(ProcessInfo.processInfo.machineHardwareName)",
            "Accessibility: \(suppressor.hasAccessibility ? "allowed" : "not allowed")",
            "Core Audio process list: \(AudioInput.hasProcessList ? "available" : "missing, using input device")",
            "On: \(prompts.isEnabled), mode: \(prompts.mode.rawValue), banners: \(prompts.bannerScope.rawValue), "
                + "any browser mic: \(prompts.anyBrowserMicCounts)",
            "State: \(suppressor.state == .inMeeting ? "in meeting (\(suppressor.meetingSource ?? "?"))" : "idle")",
            "",
            "Apps on the list:",
        ]
        for r in prompts.recorders {
            let state = prompts.isAllowed(r) ? "allowed" : "muted"
            lines.append("  \(r.displayName), \(r.id), \(state)\(prompts.isRunning(r) ? ", running" : "")")
        }
        if !suppressor.notes.isEmpty {
            lines += ["", "Notes:"] + suppressor.notes.map { "  \($0)" }
        }
        lines += ["", "Recent activity:"]
        for entry in prompts.log.prefix(40) {
            lines.append("  \(entry.date.formatted(date: .numeric, time: .shortened))  \(entry.text)")
        }
        return lines.joined(separator: "\n")
    }

    static func copy(prompts: MeetingPromptsStore, suppressor: PromptSuppressor) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(prompts: prompts, suppressor: suppressor), forType: .string)
    }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}
