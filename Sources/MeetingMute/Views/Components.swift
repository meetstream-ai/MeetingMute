import SwiftUI

/// Small all-caps section heading.
struct SectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(Brand.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Segmented switch on a glass capsule with an ember thumb that slides between options.
/// Options show an icon, a label, or both.
struct GlassSegmented<Value: Hashable>: View {
    struct Option {
        let value: Value
        var symbol: String? = nil
        let label: String
        /// Show the label text, not just the icon.
        var showsLabel = false
    }

    @Binding var selection: Value
    let options: [Option]
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option($0) }
        }
        .padding(3)
        .brandGlass(in: Capsule())
    }

    private func option(_ option: Option) -> some View {
        let selected = selection == option.value
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { selection = option.value }
        } label: {
            HStack(spacing: 6) {
                if let symbol = option.symbol {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                }
                if option.showsLabel {
                    Text(option.label).font(.callout.weight(.semibold))
                }
            }
            .foregroundStyle(selected ? Brand.ink : Brand.textSecondary)
            .padding(.horizontal, option.showsLabel ? 14 : 0)
            .frame(minWidth: 34, minHeight: 24)
            .padding(.vertical, option.showsLabel ? 3 : 0)
            .background {
                if selected {
                    Capsule().fill(Brand.button)
                        .matchedGeometryEffect(id: "thumb", in: thumb)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Glass card for a single row, with an optional colored outline to highlight it.
struct GlassCard<Content: View>: View {
    var highlight: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .brandGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if let highlight {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(highlight.opacity(0.45), lineWidth: 1)
                }
            }
    }
}

/// Generic icon + label pill on optionally tinted glass. Never color alone.
struct GlassChip: View {
    let label: String
    let symbol: String
    var foreground: Color = Brand.unknownText
    var tint: Color? = nil
    var glow: Color? = nil
    var compact = false

    var body: some View {
        Label(label, systemImage: symbol)
            .font((compact ? Font.caption : .callout).weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 8 : 11)
            .padding(.vertical, compact ? 4 : 6)
            .brandGlass(in: Capsule(), tint: tint)
            .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : 10)
    }
}
