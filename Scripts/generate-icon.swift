import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
let output = root.appendingPathComponent("Resources/AppIcon.icns")
let source = root.appendingPathComponent("Resources/AppIconSource.png")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

func writePNG(_ image: NSImage, named name: String) throws {
    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:])
    else { return }
    try png.write(to: iconset.appendingPathComponent(name))
}

if let sourceImage = NSImage(contentsOf: source) {
    for (name, size) in sizes {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: NSRect(origin: .zero, size: sourceImage.size),
            operation: .copy,
            fraction: 1
        )
        image.unlockFocus()
        try writePNG(image, named: name)
    }
} else {
    for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: radius, yRadius: radius)
    NSGradient(
        colors: [
            NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.78, alpha: 1),
            NSColor(calibratedRed: 0.02, green: 0.48, blue: 0.42, alpha: 1)
        ]
    )?.draw(in: path, angle: 315)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    let ring = NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.23, dy: size * 0.23))
    ring.lineWidth = size * 0.065
    ring.stroke()

    NSColor.white.setStroke()
    let glass = NSBezierPath(ovalIn: NSRect(x: size * 0.24, y: size * 0.34, width: size * 0.34, height: size * 0.34))
    glass.lineWidth = size * 0.07
    glass.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: size * 0.55, y: size * 0.34))
    handle.line(to: NSPoint(x: size * 0.74, y: size * 0.18))
    handle.lineWidth = size * 0.08
    handle.lineCapStyle = .round
    handle.stroke()

    NSColor.white.withAlphaComponent(0.95).setFill()
    for point in [
        NSPoint(x: size * 0.68, y: size * 0.70),
        NSPoint(x: size * 0.78, y: size * 0.58),
        NSPoint(x: size * 0.58, y: size * 0.78)
    ] {
        let sparkle = NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: size * 0.045, height: size * 0.045))
        sparkle.fill()
    }

    image.unlockFocus()

        try writePNG(image, named: name)
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    exit(process.terminationStatus)
}
try? FileManager.default.removeItem(at: iconset)
