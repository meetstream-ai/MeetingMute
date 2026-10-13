import SwiftUI

/// Settings window (⌘,): general switches and the list of apps MeetingMute manages.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AppsSettings()
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
        }
        .frame(width: 460, height: 420)
        .tint(Brand.ember)
    }
}

private struct GeneralSettings: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @AppStorage("onboarded") private var onboarded = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var prompts = prompts
        Form {
            Toggle("Mute apps during meetings", isOn: $prompts.isEnabled)
            Picker("Mode", selection: Binding(get: { prompts.mode }, set: { prompts.setMode($0) })) {
                Text("Custom").tag(MuteMode.custom)
                Text("All but one").tag(MuteMode.allButOne)
                Text("Mute all").tag(MuteMode.all)
            }
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
                    NSApp.activate(ignoringOtherApps: true)
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
                        Text(recorder.displayName)
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
                    Spacer()
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
