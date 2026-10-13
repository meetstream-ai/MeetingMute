import SwiftUI

/// Slow, looping brand-gradient background. MeshGradient on macOS 15+, LinearGradient on 14.
/// Freezes on a still frame when Reduce Motion is on.
struct FlowBackground: View {
    /// Seconds for one full loop.
    var period: Double = 24

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.15 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: period) / period
            gradient(phase: phase * 2 * .pi)
        }
        .ignoresSafeArea()
    }

    private var colors: [Color] {
        colorScheme == .dark ? Brand.flowDark : Brand.flowLight
    }

    @ViewBuilder
    private func gradient(phase t: Double) -> some View {
        let c = colors
        if #available(macOS 15, *) {
            // 3×3 mesh: corners pinned, edge and centre points drift on slow orbits.
            let s = Float(sin(t)), k = Float(cos(t))
            let s2 = Float(sin(t * 2 + 1)), k2 = Float(cos(t + 2))
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + 0.15 * s, 0], [1, 0],
                    [0, 0.5 + 0.12 * k], [0.5 + 0.18 * k2, 0.5 + 0.16 * s2], [1, 0.5 - 0.12 * s],
                    [0, 1], [0.5 - 0.15 * k, 1], [1, 1],
                ],
                colors: [
                    c[0], c[1], c[2],
                    c[7], c[4], c[3],
                    c[6], c[5], c[1],
                ]
            )
        } else {
            let a = UnitPoint(x: 0.5 + 0.5 * cos(t), y: 0.5 + 0.5 * sin(t))
            let b = UnitPoint(x: 1 - a.x, y: 1 - a.y)
            LinearGradient(colors: [c[0], c[2], c[4], c[3], c[6]], startPoint: a, endPoint: b)
        }
    }
}
