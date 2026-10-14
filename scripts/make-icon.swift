// Draws the MeetingMute app icon and writes Resources/AppIcon.icns and docs/icon.png.
//
//   swift scripts/make-icon.swift            build the icon
//   swift scripts/make-icon.swift <out.png>  only write a 1024 px preview
//
// The design: a "Meeting detected" notification card on a dark MeetStream tile, cut by an
// ember mute slash, with two dismissed cards fading out behind it. Drawn with Core Graphics
// only, so it needs nothing beyond the Command Line Tools.
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
               colors: stops.map { color($0.0, $0.1) } as CFArray,
               locations: stops.map(\.2))!
}

/// A rounded rectangle with continuous-looking corners.
func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(in ctx: CGContext) {
    // Core Graphics has y going up; flip so the numbers below read top-down.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    // Tile on the macOS icon grid: 824 px centred on 1024.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = roundedRect(tile, 186)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 36, color: color(0x000000, 0.45))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0x111111))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    // Near-black base, MeetStream ink.
    ctx.drawLinearGradient(gradient([(0x26262A, 1, 0), (0x0C0C0D, 1, 1)]),
                           start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    // Ember sun rising from the bottom.
    ctx.drawRadialGradient(gradient([(0xFF8036, 0.95, 0), (0xFD6316, 0.65, 0.35), (0x973700, 0.35, 0.7), (0x25120A, 0, 1)]),
                           startCenter: CGPoint(x: 512, y: 1010), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 1010), endRadius: 640, options: [])
    // Soft light from the top.
    ctx.drawRadialGradient(gradient([(0xFFFFFF, 0.10, 0), (0xFFFFFF, 0, 1)]),
                           startCenter: CGPoint(x: 512, y: 60), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 60), endRadius: 560, options: [])

    // The mute slash cuts through every card, so the tile shows in the gap.
    let a = CGPoint(x: 290, y: 724), b = CGPoint(x: 744, y: 270)
    let slash = CGMutablePath()
    slash.move(to: a)
    slash.addLine(to: b)
    let gap = slash.copy(strokingWithWidth: 112, lineCap: .round, lineJoin: .round, miterLimit: 10)
    ctx.saveGState()
    ctx.addRect(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    ctx.addPath(gap)
    ctx.clip(using: .evenOdd)

    // Two dismissed cards drifting away behind the front one.
    func card(_ rect: CGRect, angle: CGFloat, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: angle * .pi / 180)
        let r = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
        ctx.addPath(roundedRect(r, 52))
        ctx.setFillColor(color(0xFFFFFF, alpha))
        ctx.fillPath()
        ctx.restoreGState()
    }
    card(CGRect(x: 250, y: 228, width: 500, height: 170), angle: -9, alpha: 0.10)
    card(CGRect(x: 236, y: 300, width: 540, height: 184), angle: -4.5, alpha: 0.20)

    // Front card: a "Meeting detected" notification.
    let front = CGRect(x: 196, y: 384, width: 632, height: 236)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 40, color: color(0x000000, 0.5))
    ctx.addPath(roundedRect(front, 62))
    ctx.setFillColor(color(0xF6F6F7))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(roundedRect(front, 62))
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFFFFF, 1, 0), (0xE9E9EC, 1, 1)]),
                           start: CGPoint(x: 0, y: front.minY), end: CGPoint(x: 0, y: front.maxY), options: [])
    ctx.restoreGState()

    // App badge on the card.
    let badge = CGRect(x: front.minX + 44, y: front.midY - 66, width: 132, height: 132)
    ctx.saveGState()
    ctx.addPath(roundedRect(badge, 34))
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFF8036, 1, 0), (0xFD6316, 1, 0.55), (0xC2470A, 1, 1)]),
                           start: CGPoint(x: badge.midX, y: badge.minY), end: CGPoint(x: badge.midX, y: badge.maxY), options: [])
    ctx.restoreGState()
    // A small waveform on the badge: the notetaker that wants to record.
    ctx.setFillColor(color(0xFFFFFF, 0.95))
    let bars: [CGFloat] = [34, 62, 86, 54, 30]
    for (i, h) in bars.enumerated() {
        let x = badge.minX + 26 + CGFloat(i) * 18
        ctx.addPath(roundedRect(CGRect(x: x, y: badge.midY - h / 2, width: 10, height: h), 5))
    }
    ctx.fillPath()

    // Text lines.
    ctx.setFillColor(color(0x1B1B1F, 0.92))
    ctx.addPath(roundedRect(CGRect(x: badge.maxX + 40, y: front.midY - 48, width: 300, height: 36), 18))
    ctx.fillPath()
    ctx.setFillColor(color(0x1B1B1F, 0.32))
    ctx.addPath(roundedRect(CGRect(x: badge.maxX + 40, y: front.midY + 14, width: 214, height: 30), 15))
    ctx.fillPath()

    ctx.restoreGState()  // end of the gap clip

    // A faint dark channel keeps the slash crisp over the ember glow.
    ctx.addPath(gap)
    ctx.setFillColor(color(0x0E0806, 0.45))
    ctx.fillPath()

    // The ember slash itself.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: color(0x000000, 0.45))
    ctx.addPath(slash.copy(strokingWithWidth: 64, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.setFillColor(color(0xFD6316))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(slash.copy(strokingWithWidth: 64, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFC08F, 1, 0), (0xFF8036, 1, 0.3), (0xFD6316, 1, 0.65), (0xD9480A, 1, 1)]),
                           start: b, end: a, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // Glass edge on the tile.
    ctx.addPath(roundedRect(tile.insetBy(dx: 2, dy: 2), 184))
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(4)
    ctx.strokePath()
    ctx.restoreGState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    ctx.interpolationQuality = .high
    drawIcon(in: ctx)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let args = CommandLine.arguments.dropFirst()
if let preview = args.first {
    try render(size: 1024).write(to: URL(fileURLWithPath: preview))
    print("Wrote \(preview)")
    exit(0)
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
try render(size: 512).write(to: root.appendingPathComponent("docs/icon.png"))
print("Wrote \(icns.path) and docs/icon.png")
