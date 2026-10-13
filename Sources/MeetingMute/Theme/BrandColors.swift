import SwiftUI
import AppKit

// Brand palette extracted from https://meetstream.ai (Framer site; all styles are
// inlined in the HTML). Counts are occurrences in the homepage HTML on 2026-10-11.
// Colors and gradients only — no logo, imagery, or wordmark.

extension Color {
    /// A color that resolves differently in light and dark appearance.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Brand {
    // MARK: Raw palette

    /// `rgba(0,0,0,1)` ×398 — page background.
    static let black = Color(hex: 0x000000)
    /// `rgb(17,17,17)` / `#111` ×163 — section background.
    static let ink = Color(hex: 0x111111)
    /// `#141414` / `rgb(20,20,20)` ×20 — card surface, ember band ends.
    static let surface = Color(hex: 0x141414)
    /// `#1D1D1D → #0D0D0D` card gradient (150°) — raised surface.
    static let surfaceRaised = Color(hex: 0x1D1D1D)

    /// `rgb(253,99,22)` / `#FD6316` ×77 — primary accent (buttons, glows).
    static let ember = Color(hex: 0xFD6316)
    /// `#FF8036` — top of the primary button gradient.
    static let emberLight = Color(hex: 0xFF8036)
    /// `#EB790E` — outer ring of the radial "sun" gradient.
    static let emberGlow = Color(hex: 0xEB790E)
    /// `#973700` — inner ring of the radial "sun" gradient.
    static let emberDeep = Color(hex: 0x973700)
    /// `#25120A` — centre of the 90° ember band (`#141414 → #25120A → #141414`).
    static let emberSmoke = Color(hex: 0x25120A)

    /// `rgb(67,114,249)` ×41 — secondary accent (links, badges).
    static let blue = Color(hex: 0x4372F9)
    /// `rgb(0,153,255)` ×27 — secondary accent.
    static let sky = Color(hex: 0x0099FF)
    /// `rgb(45,177,63)` ×42 — success / live indicator.
    static let green = Color(hex: 0x2DB13F)
    /// `rgb(147,255,46)` ×37 — bright success highlight.
    static let lime = Color(hex: 0x93FF2E)

    /// `rgb(255,255,255)` ×758 — primary text on dark.
    static let white = Color(hex: 0xFFFFFF)
    /// `rgb(171,171,171)` ×261 — secondary text; bottom of the headline gradient.
    static let grey = Color(hex: 0xABABAB)
    /// `#8E9598` ×42 — captions.
    static let slate = Color(hex: 0x8E9598)
    /// `#E7E7EA` — bottom of the light button gradient.
    static let mist = Color(hex: 0xE7E7EA)

    // MARK: Semantic roles (light / dark)

    static let textPrimary = Color.adaptive(light: Color(hex: 0x111111), dark: white)
    /// Secondary — dark: #D0D0D0 (≥4.5:1 even where the flow passes #973700); light: #4A4A4A.
    static let textSecondary = Color.adaptive(light: Color(hex: 0x4A4A4A), dark: Color(hex: 0xD0D0D0))

    /// `rgba(255,255,255,.10)` ×14 hairline stroke; dark ink equivalent in light mode.
    static let border = Color.adaptive(light: Color(hex: 0x000000, opacity: 0.08),
                                       dark: Color(hex: 0xFFFFFF, opacity: 0.15))

    // Accent text colors are darkened in light mode so they pass WCAG AA (≥4.5:1)
    // against light glass. Raw #FD6316 on white is only 3.0:1.
    /// Ember text — dark: #FF8036 (7.4:1 on #141414); light: #9A3A08 (≥4.5:1 on the peach flow).
    static let accentText = Color.adaptive(light: Color(hex: 0x9A3A08), dark: emberLight)
    /// Allowed — dark: lime #93FF2E (14:1); light: #186624 (≥4.5:1 on the peach flow).
    static let allowedText = Color.adaptive(light: Color(hex: 0x186624), dark: lime)
    /// Missing — dark: #FF7A6E (7.2:1); light: #A8241A (≥4.5:1 on the peach flow).
    static let missingText = Color.adaptive(light: Color(hex: 0xA8241A), dark: Color(hex: 0xFF7A6E))
    /// Unknown — neutral secondary text.
    static let unknownText = textSecondary

    /// Glass tints for status chips (kept translucent so the flow shows through).
    static let allowedTint = green.opacity(0.45)
    /// Missing uses a solid red with white text (6.6:1) — a translucent red over the ember flow was illegible.
    static let missingTint = Color(hex: 0xB42318).opacity(0.92)

    // MARK: Gradients

    /// `linear-gradient(180deg, #FFF 0%, #ABABAB 100%)` ×261 — headline text.
    static let headline = LinearGradient(colors: [white, grey], startPoint: .top, endPoint: .bottom)
    /// Light-mode equivalent of the headline gradient.
    static let headlineLight = LinearGradient(colors: [Color(hex: 0x111111), Color(hex: 0x5F5F5F)],
                                              startPoint: .top, endPoint: .bottom)

    /// `linear-gradient(180deg, #FF8036, #FD6316)` — primary button.
    static let button = LinearGradient(colors: [emberLight, ember], startPoint: .top, endPoint: .bottom)

    /// `linear-gradient(139deg, #000 0–62%, rgba(253,99,22,.25) 150%)` — hero ember wash.
    static let heroEmber = LinearGradient(
        stops: [.init(color: black, location: 0), .init(color: black, location: 0.62),
                .init(color: ember.opacity(0.25), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// `linear-gradient(90deg, #141414, #25120A 50%, #141414)` — ember band.
    static let emberBand = LinearGradient(colors: [surface, emberSmoke, surface],
                                          startPoint: .leading, endPoint: .trailing)

    /// `radial-gradient(ellipse at center, rgba(253,99,22,.34), transparent 70%)` — centre glow.
    static let glow = RadialGradient(colors: [ember.opacity(0.34), .clear],
                                     center: .center, startRadius: 0, endRadius: 320)

    /// Colors the animated window background ("color flow") cycles through.
    /// Dark flow is near-black with a low ember smolder (#3A1604 peak) so the window reads as
    /// black, like meetstream's #000 page, with the color only glowing faintly through the glass.
    static let flowDark: [Color] = [black, black, emberSmoke, Color(hex: 0x0A0A0A),
                                    Color(hex: 0x3A1604), Color(hex: 0x1C0B03), black, blue.opacity(0.12)]
    static let flowLight: [Color] = [Color(hex: 0xFAFAFA), mist, Color(hex: 0xFFD9C2),
                                     Color(hex: 0xFFF1E8), Color(hex: 0xFFC9A8), Color(hex: 0xFFC9A3),
                                     Color(hex: 0xF4F4F4), Color(hex: 0xD6E0FE)]
}
