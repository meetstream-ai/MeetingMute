import MeetingMuteCore
import SwiftUI

enum AppsLayout: String {
    case rows, tiles
}

/// Main window: status, the app list, and recent activity.
struct HomeView: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @AppStorage("layout", store: Demo.defaults) private var layout: AppsLayout = .tiles
    @State private var query = ""
    @Namespace private var itemSpace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if !suppressor.hasAccessibility { AccessibilityBanner() }
                if suppressor.state == .inMeeting { MeetingCard() }
                appsSection
            }
            .padding(24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        @Bindable var prompts = prompts
        return HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("MeetingMute")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Brand.textPrimary)
                HStack(spacing: 8) {
                    MeetingStatusChip()
                    if prompts.silencedTotal > 0 {
                        Text("\(prompts.silencedTotal) silenced")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Brand.textSecondary)
                            .contentTransition(.numericText())
                            .help("Popups and notifications MeetingMute has closed")
                    }
                }
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

    private var filteredGroups: [MeetingPromptsStore.Group] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return prompts.groups }
        return prompts.groups.compactMap { group in
            let apps = group.apps.filter { $0.displayName.localizedCaseInsensitiveContains(q) }
            return apps.isEmpty ? nil : MeetingPromptsStore.Group(title: group.title, symbol: group.symbol, apps: apps)
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SectionTitle("Your apps")
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
                .accessibilityLabel("Layout")
                Button { prompts.addManually() } label: {
                    Image(systemName: "plus").frame(height: 16)
                }
                .buttonStyle(BrandGlassButtonStyle())
                .help("Add any app")
                .accessibilityLabel("Add an app")
            }

            HStack(spacing: 10) {
                GlassSegmented(selection: Binding(get: { prompts.mode }, set: { prompts.setMode($0) }), options: [
                    .init(value: .custom, symbol: "slider.horizontal.3", label: "Custom", showsLabel: true),
                    .init(value: .allButOne, symbol: "person.fill.checkmark", label: "All but one", showsLabel: true),
                    .init(value: .all, symbol: "bell.slash.fill", label: "Mute all", showsLabel: true),
                ])
                .accessibilityLabel("Mute mode")
                .help("Custom: pick each app · All but one: only one app can prompt · Mute all: every app is muted")
                Spacer(minLength: 0)
                if prompts.recorders.count > 8 { SearchField(text: $query) }
            }

            if prompts.recorders.isEmpty {
                EmptyAppsCard()
            } else if filteredGroups.isEmpty {
                Text("No app matches “\(query)”")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredGroups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        if prompts.groups.count > 1 {
                            Label("\(group.title) · \(group.apps.count)", systemImage: group.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Brand.textSecondary)
                                .accessibilityAddTraits(.isHeader)
                        }
                        if layout == .rows {
                            VStack(spacing: 10) {
                                ForEach(group.apps) { recorder in
                                    RecorderRow(recorder: recorder)
                                        .matchedGeometryEffect(id: recorder.id, in: itemSpace)
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                                ForEach(group.apps) { recorder in
                                    RecorderTile(recorder: recorder)
                                        .matchedGeometryEffect(id: recorder.id, in: itemSpace)
                                }
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.2), value: layout)
        .animation(.spring(duration: 0.4), value: prompts.recorders.map(\.id))
        .animation(.spring(duration: 0.4), value: prompts.muted.map(\.id))
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(Brand.textSecondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(width: 110)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Brand.textSecondary)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .brandGlass(in: Capsule())
    }
}

private struct EmptyAppsCard: View {
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("No notetakers on this Mac yet", systemImage: "sparkle.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(Brand.textPrimary)
                Text("MeetingMute knows \(Registry.apps.count) notetakers, dictation apps and meeting reminders. "
                     + "They show up here as soon as one is installed, and apps that start using the "
                     + "microphone are suggested.")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Add an App…") { prompts.addManually() }
                        .buttonStyle(BrandGlassButtonStyle(prominent: true))
                    Button("See Supported Apps") { NSWorkspace.shared.open(AppInfo.supportedApps) }
                        .buttonStyle(BrandGlassButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Meeting

/// Shown during a call: where it was detected, what was silenced, and a pause switch.
private struct MeetingCard: View {
    @Environment(PromptSuppressor.self) private var suppressor

    var body: some View {
        GlassCard(highlight: Brand.ember) {
            HStack(spacing: 14) {
                Image(systemName: suppressor.pausedForMeeting ? "pause.circle.fill" : "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Brand.accentText)
                    .frame(width: 36, height: 36)
                    .brandGlass(in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(suppressor.pausedForMeeting ? "Paused for this meeting" : "In a meeting")
                        .font(.headline)
                        .foregroundStyle(Brand.textPrimary)
                    HStack(spacing: 6) {
                        if let source = suppressor.meetingSource { Text(source) }
                        if let start = suppressor.meetingStart {
                            Text("·")
                            Text(start, style: .timer).monospacedDigit()
                        }
                        Text("·")
                        Text("\(suppressor.silencedThisMeeting) silenced").monospacedDigit()
                    }
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
                }
                Spacer()
                Button(suppressor.pausedForMeeting ? "Resume" : "Pause") {
                    withAnimation { suppressor.pausedForMeeting.toggle() }
                }
                .buttonStyle(BrandGlassButtonStyle(prominent: suppressor.pausedForMeeting))
                .help(suppressor.pausedForMeeting ? "Mute again" : "Let every app prompt until this meeting ends")
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
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
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(recorder.displayName)
                            .font(.headline)
                            .foregroundStyle(Brand.textPrimary)
                        if prompts.isRunning(recorder) { RunningDot() }
                        if prompts.isSuggested(recorder) { NewBadge() }
                    }
                    if let off = recorder.offSwitchPath {
                        Label(off, systemImage: "switch.2")
                            .font(.caption)
                            .foregroundStyle(Brand.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help("To stop the prompt at the source, turn it off in \(recorder.displayName): \(off)")
                    }
                }
                Spacer()
                MuteButton(recorder: recorder)
            }
        }
        .help(recorder.id)
        .contextMenu { RecorderMenu(recorder: recorder) }
        .accessibilityElement(children: .contain)
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
        .overlay(alignment: .topLeading) {
            if prompts.isSuggested(recorder) { NewBadge().padding(10) }
        }
        .help(tooltip)
        .contextMenu { RecorderMenu(recorder: recorder) }
        .accessibilityElement(children: .contain)
    }

    private var tooltip: String {
        var lines = [recorder.id]
        if let off = recorder.known?.offSwitch { lines.append("Turn it off in the app: \(off)") }
        return lines.joined(separator: "\n")
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Brand.lime))
            .help("Found using the microphone. Tap the bell to mute it.")
            .accessibilityLabel("New, found using the microphone")
    }
}

struct AppIcon: View {
    let recorder: RecorderApp
    let size: CGFloat
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        // Always the app's own icon, unaltered; the pill and outline show the muted state.
        Image(nsImage: recorder.app.icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
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
        .accessibilityLabel(recorder.displayName)
        .accessibilityValue(muted ? "Muted" : "Allowed")
        .accessibilityHint(muted ? "Lets it prompt in meetings" : "Mutes it in meetings")
        .accessibilityAddTraits(.isToggle)
    }
}

struct RecorderMenu: View {
    let recorder: RecorderApp
    @Environment(MeetingPromptsStore.self) private var prompts

    var body: some View {
        Button("Open \(recorder.app.name)") { prompts.open(recorder) }
        if let off = recorder.known?.offSwitch {
            Section("Turn it off in the app") {
                Text(off)
            }
        }
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
            .accessibilityElement()
            .accessibilityLabel("Running")
    }
}

// MARK: - Status

/// Off / Needs permission / Nothing muted / Watching / In meeting / Paused.
struct MeetingStatusChip: View {
    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor

    var body: some View {
        if !prompts.isEnabled {
            GlassChip(label: "Off", symbol: "pause.circle", compact: true)
        } else if !suppressor.hasAccessibility {
            GlassChip(label: "Needs permission", symbol: "hand.raised.fill", foreground: Brand.accentText, compact: true)
        } else if suppressor.state == .inMeeting {
            if suppressor.pausedForMeeting {
                GlassChip(label: "Paused", symbol: "pause.fill", compact: true)
            } else {
                GlassChip(label: "In meeting", symbol: "bell.slash.fill", foreground: Brand.textPrimary,
                          tint: Brand.ember.opacity(0.55), compact: true)
            }
        } else if prompts.muted.isEmpty {
            GlassChip(label: "Nothing muted", symbol: "bell", compact: true)
        } else {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Needs Accessibility to close popups")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Brand.textPrimary)
                    Text("It's the only permission MeetingMute uses.")
                        .font(.caption)
                        .foregroundStyle(Brand.textSecondary)
                }
                Spacer()
                Button("Allow") { suppressor.requestAccessibility() }
                    .buttonStyle(BrandGlassButtonStyle(prominent: true))
            }
        }
    }
}

/// Clock button that shows recent activity in a popover, grouped by day.
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
            ActivityList()
                .environment(prompts)
        }
    }
}

struct ActivityList: View {
    @Environment(MeetingPromptsStore.self) private var prompts

    private var days: [(day: Date, entries: [ActivityEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: prompts.log.prefix(60)) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity").font(.headline)
                Spacer()
                if !prompts.log.isEmpty {
                    Button("Clear") { prompts.clearLog() }.buttonStyle(.link)
                }
            }
            if prompts.log.isEmpty {
                Text("Nothing yet. Join a call and MeetingMute logs what it silences here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(days, id: \.day) { day in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(Self.title(for: day.day))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityAddTraits(.isHeader)
                                ForEach(day.entries) { entry in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(entry.date, format: .dateTime.hour().minute())
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 58, alignment: .leading)
                                        Text(entry.text).font(.callout)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "TODAY" }
        if calendar.isDateInYesterday(day) { return "YESTERDAY" }
        return day.formatted(.dateTime.weekday(.wide).month().day()).uppercased()
    }
}
