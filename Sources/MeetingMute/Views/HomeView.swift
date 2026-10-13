import SwiftUI

enum AppsLayout: String {
    case rows, tiles
}

/// Main window: status, the notetaker list, and recent activity.
struct HomeView: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @AppStorage("layout") private var layout: AppsLayout = .tiles
    @Namespace private var itemSpace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !suppressor.hasAccessibility { AccessibilityBanner() }
                appsSection
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        @Bindable var prompts = prompts
        return HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("MeetingMute")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Brand.textPrimary)
                MeetingStatusChip(state: suppressor.state, enabled: prompts.isEnabled)
            }
            Spacer()
            ActivityButton()
            SettingsLink {
                Image(systemName: "gearshape").frame(height: 16)
            }
            .buttonStyle(BrandGlassButtonStyle())
            .help("Settings")
            .accessibilityLabel("Settings")
            Toggle("Mute during meetings", isOn: $prompts.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Brand.ember)
                .help(prompts.isEnabled ? "Turn off MeetingMute" : "Turn on MeetingMute")
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SectionTitle("Notetakers")
                if !prompts.muted.isEmpty {
                    Text("\(prompts.muted.count) muted")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Brand.accentText)
                        .contentTransition(.numericText())
                }
                Spacer()
                GlassSegmented(selection: $layout, options: [
                    .init(value: .rows, symbol: "list.bullet", label: "Rows"),
                    .init(value: .tiles, symbol: "square.grid.2x2", label: "Tiles"),
                ])
                Button { prompts.addManually() } label: {
                    Image(systemName: "plus").frame(height: 16)
                }
                .buttonStyle(BrandGlassButtonStyle())
                .help("Add an app")
                .accessibilityLabel("Add an app")
            }

            GlassSegmented(selection: Binding(get: { prompts.mode }, set: { prompts.setMode($0) }), options: [
                .init(value: .custom, symbol: "slider.horizontal.3", label: "Custom", showsLabel: true),
                .init(value: .allButOne, symbol: "person.fill.checkmark", label: "All but one", showsLabel: true),
                .init(value: .all, symbol: "bell.slash.fill", label: "Mute all", showsLabel: true),
            ])
            .help("Custom: pick each app · All but one: only one app can prompt · Mute all: every app is muted")

            if prompts.recorders.isEmpty {
                GlassCard {
                    Label("No notetakers yet. They'll appear here when they launch.", systemImage: "sparkle.magnifyingglass")
                        .font(.callout)
                        .foregroundStyle(Brand.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if layout == .rows {
                VStack(spacing: 10) {
                    ForEach(prompts.recorders) { recorder in
                        RecorderRow(recorder: recorder)
                            .matchedGeometryEffect(id: recorder.id, in: itemSpace)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 12)], spacing: 12) {
                    ForEach(prompts.recorders) { recorder in
                        RecorderTile(recorder: recorder)
                            .matchedGeometryEffect(id: recorder.id, in: itemSpace)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: layout)
        .animation(.spring(duration: 0.4), value: prompts.recorders.map(\.id))
        .animation(.spring(duration: 0.4), value: prompts.muted.map(\.id))
    }
}

// MARK: - Rows and tiles

struct RecorderRow: View {
    let recorder: RecorderApp
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        let muted = !prompts.isAllowed(recorder)
        GlassCard(highlight: muted ? Brand.ember : nil) {
            HStack(spacing: 12) {
                AppIcon(recorder: recorder, size: 32)
                Text(recorder.displayName)
                    .font(.headline)
                    .foregroundStyle(Brand.textPrimary)
                if prompts.isRunning(recorder) { RunningDot() }
                Spacer()
                MuteButton(recorder: recorder)
            }
        }
        .contextMenu { RecorderMenu(recorder: recorder) }
    }
}

struct RecorderTile: View {
    let recorder: RecorderApp
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        let muted = !prompts.isAllowed(recorder)
        GlassCard(highlight: muted ? Brand.ember : nil) {
            VStack(spacing: 10) {
                AppIcon(recorder: recorder, size: 48)
                    .overlay(alignment: .topTrailing) {
                        if prompts.isRunning(recorder) { RunningDot().offset(x: 3, y: -3) }
                    }
                Text(recorder.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .lineLimit(1)
                MuteButton(recorder: recorder)
            }
            .frame(maxWidth: .infinity)
        }
        .contextMenu { RecorderMenu(recorder: recorder) }
    }
}

struct AppIcon: View {
    let recorder: RecorderApp
    let size: CGFloat
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        Image(nsImage: recorder.app.icon)
            .resizable()
            .frame(width: size, height: size)
            .saturation(prompts.isAllowed(recorder) ? 1 : 0.2)
            .opacity(prompts.isAllowed(recorder) ? 1 : 0.7)
            .accessibilityHidden(true)
    }
}

/// Bell pill: tap to mute or unmute.
struct MuteButton: View {
    let recorder: RecorderApp
    var compact = false
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        let muted = !prompts.isAllowed(recorder)
        Button {
            withAnimation(.spring(duration: 0.35)) { prompts.setMuted(recorder, !muted) }
        } label: {
            Label(muted ? "Muted" : "On", systemImage: muted ? "bell.slash.fill" : "bell.fill")
                .font((compact ? Font.caption : .callout).weight(.semibold))
                .foregroundStyle(muted ? Brand.ink : Brand.textPrimary)
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, compact ? 8 : 12)
                .padding(.vertical, compact ? 4 : 6)
                .frame(minWidth: compact ? 70 : 90)
                .background { if muted { Capsule().fill(Brand.button) } }
                .brandGlass(in: Capsule(), interactive: true)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(muted ? "Let \(recorder.displayName) prompt in meetings" : "Mute \(recorder.displayName) in meetings")
        .accessibilityLabel(muted ? "Unmute \(recorder.displayName)" : "Mute \(recorder.displayName)")
    }
}

struct RecorderMenu: View {
    let recorder: RecorderApp
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        Button("Open \(recorder.app.name)") { prompts.open(recorder) }
        Button("Notification Settings…") { NSWorkspace.shared.open(recorder.notificationSettingsURL) }
        Divider()
        Button("Only Allow \(recorder.displayName)") { prompts.allowOnly(recorder) }
        Button("Mute All") { prompts.setMode(.all) }
        Button("Unmute All") { prompts.unmuteAll() }
        Divider()
        Button("Remove from List", role: .destructive) { prompts.remove(recorder) }
    }
}

struct RunningDot: View {
    var body: some View {
        Circle()
            .fill(Brand.green)
            .frame(width: 8, height: 8)
            .shadow(color: Brand.green.opacity(0.6), radius: 4)
            .help("Running")
            .accessibilityLabel("Running")
    }
}

// MARK: - Status

/// "Watching" / "In meeting" / "Off".
struct MeetingStatusChip: View {
    let state: PromptSuppressor.State
    let enabled: Bool

    var body: some View {
        switch (enabled, state) {
        case (false, _):
            GlassChip(label: "Off", symbol: "pause.circle", compact: true)
        case (true, .inMeeting):
            GlassChip(label: "In meeting", symbol: "bell.slash.fill", foreground: Brand.textPrimary,
                      tint: Brand.ember.opacity(0.45), compact: true)
        case (true, .idle):
            GlassChip(label: "Watching", symbol: "eye", compact: true)
        }
    }
}

struct AccessibilityBanner: View {
    @Environment(PromptSuppressor.self) private var suppressor

    var body: some View {
        GlassCard(highlight: Brand.ember) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Brand.accentText)
                Text("Needs Accessibility to close popups")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Brand.textPrimary)
                Spacer()
                Button("Allow") { suppressor.requestAccessibility() }
                    .buttonStyle(BrandGlassButtonStyle(prominent: true))
            }
        }
    }
}

/// Clock button that shows recent activity in a popover.
struct ActivityButton: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "clock.arrow.circlepath").frame(height: 16)
        }
        .buttonStyle(BrandGlassButtonStyle())
        .help("Activity")
        .accessibilityLabel("Activity")
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Activity").font(.headline)
                    Spacer()
                    if !prompts.log.isEmpty {
                        Button("Clear") { prompts.clearLog() }.buttonStyle(.link)
                    }
                }
                if prompts.log.isEmpty {
                    Text("Nothing yet").foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(prompts.log.prefix(30)) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(entry.date, format: .dateTime.hour().minute())
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 58, alignment: .leading)
                                    Text(entry.message).font(.callout)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
            .padding(14)
            .frame(width: 300)
        }
    }
}
