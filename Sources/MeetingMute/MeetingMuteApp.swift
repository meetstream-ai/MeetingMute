import SwiftUI

@main
struct MeetingMuteApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var catalog: AppCatalog
    @State private var prompts: MeetingPromptsStore
    @State private var suppressor: PromptSuppressor
    @AppStorage("onboarded", store: Demo.defaults) private var onboarded = false

    init() {
        let catalog = AppCatalog()
        let prompts = MeetingPromptsStore(catalog: catalog)
        _catalog = State(initialValue: catalog)
        _prompts = State(initialValue: prompts)
        _suppressor = State(initialValue: PromptSuppressor(prompts: prompts))
    }

    var body: some Scene {
        Window("MeetingMute", id: "main") {
            RootView()
                .environment(prompts)
                .environment(suppressor)
                .modifier(Demo.ActiveState())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: Demo.isOn ? Demo.windowHeight : 680)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Show Welcome Guide") { onboarded = false }
                Button("Supported Apps") { NSWorkspace.shared.open(AppInfo.supportedApps) }
                Button("Report an Issue…") { NSWorkspace.shared.open(AppInfo.issues) }
                Divider()
                Button("MeetingMute on GitHub") { NSWorkspace.shared.open(AppInfo.repo) }
            }
        }

        Settings {
            SettingsView()
                .environment(prompts)
                .environment(suppressor)
                .modifier(Demo.ActiveState())
        }

        MenuBarExtra {
            MenuBarView()
                .environment(prompts)
                .environment(suppressor)
        } label: {
            Image(systemName: MenuBarSymbol.name(enabled: prompts.isEnabled, trusted: suppressor.hasAccessibility,
                                                 state: suppressor.state, paused: suppressor.pausedForMeeting))
                .accessibilityLabel("MeetingMute")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !DockIcon.isShown, !Demo.isOn { NSApp.setActivationPolicy(.accessory) }
        Demo.applyAppearance()
        Demo.showWindow()
    }

    /// With the Dock icon hidden, closing the window must not quit the menu bar app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// The menu bar icon reflects what MeetingMute is doing.
enum MenuBarSymbol {
    static func name(enabled: Bool, trusted: Bool, state: PromptSuppressor.State, paused: Bool) -> String {
        if !enabled { return "bell" }
        if !trusted { return "bell.badge" }
        if state == .inMeeting { return paused ? "bell" : "bell.slash.fill" }
        return "bell.slash"
    }
}

/// Shows the welcome guide until it's finished once, then the main screen.
struct RootView: View {
    @AppStorage("onboarded", store: Demo.defaults) private var onboarded = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            FlowBackground()
            if onboarded {
                HomeView().transition(.opacity)
            } else {
                OnboardingView { onboarded = true }.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboarded)
        .frame(minWidth: 520, minHeight: 560)
        .onAppear { if Demo.showsSettings { openSettings() } }
    }
}
