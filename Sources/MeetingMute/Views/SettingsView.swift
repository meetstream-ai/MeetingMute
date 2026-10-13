import MeetingMuteCore
import SwiftUI

/// Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppsSettings()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 520)
        .tint(Brand.ember)
    }
}

private struct GeneralSettings: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @AppStorage("onboarded", store: Demo.defaults) private var onboarded = false
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var showInDock = DockIcon.isShown
    @State private var copied = false

    var body: some View {
        @Bindable var prompts = prompts
        Form {
            Section {
                Toggle("Mute apps during meetings", isOn: $prompts.isEnabled)
                Picker("Mode", selection: Binding(get: { prompts.mode }, set: { prompts.setMode($0) })) {
                    Text("Custom").tag(MuteMode.custom)
                    Text("All but one").tag(MuteMode.allButOne)
                    Text("Mute all").tag(MuteMode.all)
                }
            }

            Section {
                Picker("Close notifications", selection: $prompts.bannerScope) {
                    Text("During meetings").tag(BannerScope.meetings)
                    Text("Always").tag(BannerScope.always)
                }
                Toggle("Any browser microphone use is a meeting", isOn: $prompts.anyBrowserMicCounts)
            } header: {
                Text("Detection")
            } footer: {
                Text("Closing a notification also removes it from Notification Center. A browser counts as "
                     + "a meeting when a tab looks like a call (Google Meet, Teams, Whereby…), unless the "
                     + "switch above is on.")
                    .foregroundStyle(.secondary)
            }

            Section("App") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        loginError = LoginItem.set(on)
                        launchAtLogin = LoginItem.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { _, shown in DockIcon.apply(shown) }
                LabeledContent("Accessibility") {
                    if suppressor.hasAccessibility {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow…") { suppressor.requestAccessibility() }
                    }
                }
                LabeledContent("Welcome guide") {
                    Button("Show Again") {
                        onboarded = false
                        openWindow(id: "main")
                        NSApp.activate()
                    }
                }
                LabeledContent("Diagnostics") {
                    Button(copied ? "Copied" : "Copy for a Bug Report") {
                        Diagnostics.copy(prompts: prompts, suppressor: suppressor)
                        copied = true
                    }
                    .help("Copies versions, settings and recent activity. No window contents or meeting data.")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppsSettings: View {
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        Form {
            Section {
                if prompts.recorders.isEmpty {
                    Text("No apps yet").foregroundStyle(.secondary)
                }
                ForEach(prompts.recorders) { recorder in
                    HStack(spacing: 10) {
                        Image(nsImage: recorder.app.icon).resizable().frame(width: 22, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recorder.displayName)
                            Text(recorder.id)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(prompts.source(of: recorder))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            prompts.remove(recorder)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(recorder.displayName)")
                        .accessibilityLabel("Remove \(recorder.displayName)")
                    }
                }
            } header: {
                Text("Apps on the list")
            } footer: {
                HStack {
                    Button("Supported Apps (\(Registry.apps.count))") { NSWorkspace.shared.open(AppInfo.supportedApps) }
                        .buttonStyle(.link)
                    Spacer()
                    Button("Scan Again") { prompts.rescan() }
                    Button("Add App…") { prompts.addManually() }
                }
            }

            if !prompts.removedApps.isEmpty {
                Section("Removed") {
                    ForEach(prompts.removedApps) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                            Text(app.name).foregroundStyle(.secondary)
                            Spacer()
                            Button("Add Back") { prompts.restore(app) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("MeetingMute").font(.title.bold())
                Text("Version \(AppInfo.version)").foregroundStyle(.secondary)
            }
            Text("Silence AI notetaker popups when a call starts.")
                .font(.callout)
            VStack(spacing: 2) {
                Text("Built by **Rohan Ganesh** and **Sidhdharth Sivasubramanian**")
                Text("at MeetStream · Free and open source (MIT)")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("GitHub") { NSWorkspace.shared.open(AppInfo.repo) }
                Button("Report an Issue") { NSWorkspace.shared.open(AppInfo.issues) }
                Button("meetstream.ai") { NSWorkspace.shared.open(AppInfo.meetstream) }
            }
            Text("Runs entirely on your Mac. No network access, no analytics, nothing recorded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
