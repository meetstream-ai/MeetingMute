import MeetingMuteCore
import SwiftUI

/// First-run guide: what the app does, the one permission it needs, and what to mute.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(MeetingPromptsStore.self) private var prompts
    @Environment(PromptSuppressor.self) private var suppressor
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: permission
                default: chooseApps
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)

            footer
        }
        .padding(32)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        StepLayout(title: "Welcome to MeetingMute",
                   subtitle: "Silence notetaker popups while you're in a meeting.") {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: 14) {
                GuidePoint(symbol: "bell.slash.fill", text: "Pick the apps to mute")
                GuidePoint(symbol: "video.fill", text: "Join a meeting as usual")
                GuidePoint(symbol: "sparkles", text: "Their popups close on their own")
                GuidePoint(symbol: "lock.fill", text: "Runs on your Mac. Nothing leaves it")
            }
        }
    }

    private var permission: some View {
        let granted = suppressor.hasAccessibility
        return StepLayout(title: "One permission",
                          subtitle: "Accessibility lets MeetingMute close popups for you.") {
            Image(systemName: granted ? "checkmark.seal.fill" : "hand.raised.fill")
                .font(.system(size: 64))
                .foregroundStyle(granted ? Brand.allowedText : Brand.accentText)
                .contentTransition(.symbolEffect(.replace))
                .frame(height: 128)
        } content: {
            VStack(spacing: 12) {
                if granted {
                    GlassChip(label: "Allowed", symbol: "checkmark", foreground: Brand.allowedText,
                              tint: Brand.allowedTint)
                } else {
                    Button("Open System Settings") { suppressor.requestAccessibility() }
                        .buttonStyle(BrandGlassButtonStyle(prominent: true))
                    Text("Turn on MeetingMute in the list, then come back.")
                        .font(.callout)
                        .foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }

    private var chooseApps: some View {
        StepLayout(title: "What should stay quiet?",
                   subtitle: "Tap the bell to mute an app. Works with \(Registry.apps.count) notetakers, dictation apps and meeting reminders.") {
            EmptyView()
        } content: {
            if prompts.recorders.isEmpty {
                Text("No notetakers on this Mac yet. Known apps show up as soon as they're installed, and apps that start using the microphone are suggested.")
                    .font(.callout)
                    .foregroundStyle(Brand.textSecondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                        ForEach(prompts.recorders) { RecorderTile(recorder: $0) }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == step ? Brand.ember : Brand.textSecondary.opacity(0.3))
                        .frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of 3")
            Spacer()
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(BrandGlassButtonStyle())
            }
            if step == 1 && !suppressor.hasAccessibility {
                Button("Later") { step += 1 }
                    .buttonStyle(BrandGlassButtonStyle())
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(step == 2 ? "Done" : "Continue") {
                    if step == 2 { onFinish() } else { step += 1 }
                }
                .buttonStyle(BrandGlassButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct StepLayout<Hero: View, Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var hero: Hero
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            hero
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Brand.textPrimary)
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(Brand.textSecondary)
            }
            .multilineTextAlignment(.center)
            content
            Spacer(minLength: 0)
        }
    }
}

private struct GuidePoint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Brand.accentText)
                .frame(width: 34, height: 34)
                .brandGlass(in: Circle())
            Text(text)
                .font(.title3.weight(.medium))
                .foregroundStyle(Brand.textPrimary)
        }
    }
}
