import SwiftUI

@main
struct MeetingMuteApp: App {
    @State private var catalog: AppCatalog
    @State private var prompts: MeetingPromptsStore
    @State private var suppressor: PromptSuppressor
    @AppStorage("onboarded") private var onboarded = false

    init() {
        let catalog = AppCatalog()
        let prompts = MeetingPromptsStore(catalog: catalog)
        _catalog = State(initialValue: catalog)
        _prompts = State(initialValue: prompts)
        _suppressor = State(initialValue: PromptSuppressor(prompts: prompts, catalog: catalog))
    }

    var body: some Scene {
        Window("MeetingMute", id: "main") {
            RootView()
                .environment(prompts)
                .environment(suppressor)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 560, height: 620)
        .commands {
            CommandGroup(after: .help) {
                Button("Show Welcome Guide") { onboarded = false }
            }
        }

        Settings {
            SettingsView()
                .environment(prompts)
                .environment(suppressor)
        }

        MenuBarExtra("MeetingMute", systemImage: "bell.slash") {
            MenuBarView()
                .environment(prompts)
                .environment(suppressor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Shows the welcome guide until it's finished once, then the main screen.
struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false

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
        .frame(minWidth: 480, minHeight: 540)
    }
}
