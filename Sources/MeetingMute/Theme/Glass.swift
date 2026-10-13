import SwiftUI

/// Liquid Glass on macOS 26+, `.ultraThinMaterial` + hairline + soft shadow before that.
extension View {
    func brandGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(BrandGlass(shape: shape, tint: tint, interactive: interactive))
    }

    /// Ties a glass element to a morph identity on macOS 26 (no-op before).
    @ViewBuilder
    func brandGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26, *) {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
}

private struct BrandGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint { shape.fill(tint.opacity(0.75)) }
                    }
                }
                .overlay { shape.strokeBorder(Brand.border, lineWidth: 1) }
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
    }

    @available(macOS 26, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

/// Groups glass so neighbouring elements blend and morph (macOS 26); plain stack before.
struct BrandGlassContainer<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Button style: glass capsule, ember-tinted when prominent.
struct BrandGlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            // Ink on ember: white on #FD6316 is only 3.0:1; #111 is 6.3:1.
            .foregroundStyle(prominent ? Brand.ink : Brand.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background {
                if prominent {
                    Capsule().fill(Brand.button)
                }
            }
            .brandGlass(in: Capsule(), tint: prominent ? Brand.ember.opacity(0.6) : nil, interactive: true)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule())
    }
}
