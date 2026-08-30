// Draws the CatAttack app icon (a cat paw pressing a keyboard key) and
// writes an .iconset of PNGs. Usage: swift scripts/generate-icon.swift <outdir>
import AppKit

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

/// Draws in a 1024x1024 space, origin bottom-left.
func drawIcon() {
    // macOS-style rounded-square canvas with the standard margin.
    let squircle = rounded(100, 100, 824, 824, 184)
    NSGradient(colors: [color(0x23273A), color(0x3A4160)])!.draw(in: squircle, angle: 90)

    NSGraphicsContext.current?.saveGraphicsState()
    squircle.addClip()

    // Soft shadow under the keycap.
    NSColor.black.withAlphaComponent(0.28).setFill()
    ellipse(512, 228, 270, 42).fill()

    // Keycap: darker front edge peeking out below a light top face.
    color(0x8E97A8).setFill()
    rounded(302, 230, 420, 380, 64).fill()
    color(0xF2F5F9).setFill()
    rounded(302, 262, 420, 380, 64).fill()

    // Paw pressing down from the top edge, overlapping the keycap.
    color(0xF5A75F).setFill()
    rounded(352, 560, 320, 560, 160).fill()

    // Pads: four toe beans near the tip, big metacarpal pad above them.
    let bean = color(0xEF8FA6)
    bean.setFill()
    ellipse(417, 658, 34, 40).fill()
    ellipse(480, 622, 34, 40).fill()
    ellipse(544, 622, 34, 40).fill()
    ellipse(607, 658, 34, 40).fill()
    ellipse(512, 748, 88, 68).fill()

    NSGraphicsContext.current?.restoreGraphicsState()
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (px, name) in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = ctx
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(px) / 1024)
    transform.concat()
    drawIcon()
    ctx?.flushGraphics()
    NSGraphicsContext.current = nil
    try rep.representation(using: .png, properties: [:])!
        .write(to: outDir.appendingPathComponent("\(name).png"))
}
print("Wrote iconset to \(outDir.path)")
