import SwiftUI

/// Panel from the menu bar icon: status, a pause switch during calls, and quick mute toggles.
struct MenuBarView: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var prompts = prompts
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("MeetingMute")
                    .font(.headline)
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                MeetingStatusChip()
                Toggle("On", isOn: $prompts.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(Brand.ember)
                    .help(prompts.isEnabled ? "Turn off MeetingMute" : "Turn on MeetingMute")
            }

            if !suppressor.hasAccessibility { AccessibilityBanner() }

            if suppressor.state == .inMeeting {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill").foregroundStyle(Brand.accentText)
                    Text("\(suppressor.meetingSource ?? "Meeting") · \(suppressor.silencedThisMeeting) silenced")
                        .font(.callout)
                        .foregroundStyle(Brand.textPrimary)
                    Spacer()
                    Button(suppressor.pausedForMeeting ? "Resume" : "Pause") {
                        suppressor.pausedForMeeting.toggle()
                    }
                    .buttonStyle(BrandGlassButtonStyle(prominent: suppressor.pausedForMeeting))
                    .help("Let every app prompt until this meeting ends")
                }
            }

            if prompts.recorders.isEmpty {
                Text("No notetakers on this Mac yet")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(prompts.recorders) { recorder in
                            HStack(spacing: 10) {
                                AppIcon(recorder: recorder, size: 22)
                                Text(recorder.displayName)
                                    .foregroundStyle(Brand.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                MuteButton(recorder: recorder, compact: true)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: min(CGFloat(prompts.recorders.count) * 34, 320))
            }

            HStack(spacing: 8) {
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(BrandGlassButtonStyle())
                    .keyboardShortcut("q")
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape").frame(height: 16)
                }
                .buttonStyle(BrandGlassButtonStyle())
                .accessibilityLabel("Settings")
                Button("Open MeetingMute") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
                .buttonStyle(BrandGlassButtonStyle(prominent: true))
            }
        }
        .padding(14)
        .frame(width: 320)
        .background { FlowBackground() }
    }
}
