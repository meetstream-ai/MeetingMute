import SwiftUI

/// Popover from the menu bar icon: status and quick mute toggles.
struct MenuBarView: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MeetingMute")
                    .font(.headline)
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                MeetingStatusChip(state: suppressor.state, enabled: prompts.isEnabled)
            }

            if !suppressor.hasAccessibility { AccessibilityBanner() }

            if prompts.recorders.isEmpty {
                Text("No notetakers found")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(prompts.recorders) { recorder in
                        HStack(spacing: 10) {
                            AppIcon(recorder: recorder, size: 22)
                            Text(recorder.displayName)
                                .foregroundStyle(Brand.textPrimary)
                            Spacer()
                            MuteButton(recorder: recorder, compact: true)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                SettingsLink {
                    Image(systemName: "gearshape").frame(height: 16)
                }
                .buttonStyle(BrandGlassButtonStyle())
                .accessibilityLabel("Settings")
                Button("Open") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(BrandGlassButtonStyle(prominent: true))
            }
        }
        .padding(14)
        .frame(width: 300)
        .background { FlowBackground() }
    }
}
