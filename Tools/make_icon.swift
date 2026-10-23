// Draws the app icon: an Erlenmeyer flask on a rounded square, rendered to PNG.
// Usage: swift Tools/make_icon.swift <output.png> [size]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1024 : 1024

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Work in a 1024 grid with y pointing down, then let the context scale it.
let scale = CGFloat(size) / 1024
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: scale, y: -scale)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

/// Polygon with per-corner rounding, starting from the middle of the first edge.
func roundedPolygon(_ points: [CGPoint], radii: [CGFloat]) -> CGPath {
    let path = CGMutablePath()
    let count = points.count
    let start = CGPoint(
        x: (points[0].x + points[1].x) / 2,
        y: (points[0].y + points[1].y) / 2
    )
    path.move(to: start)
    for offset in 1...count {
        let corner = points[offset % count]
        let next = points[(offset + 1) % count]
        path.addArc(tangent1End: corner, tangent2End: next, radius: radii[offset % count])
    }
    path.closeSubpath()
    return path
}

// Rounded-square plate with a cool gradient.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let platePath = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
context.saveGState()
context.addPath(platePath)
context.clip()
context.drawLinearGradient(
    gradient([rgb(0x1C2A4A), rgb(0x1E5F73), rgb(0x2A8C87)], [0, 0.55, 1]),
    start: CGPoint(x: 160, y: 120),
    end: CGPoint(x: 880, y: 900),
    options: []
)
context.restoreGState()

// Flask body: neck, shoulders, flat base.
let flask = roundedPolygon(
    [
        CGPoint(x: 424, y: 268),
        CGPoint(x: 424, y: 452),
        CGPoint(x: 268, y: 744),
        CGPoint(x: 756, y: 744),
        CGPoint(x: 600, y: 452),
        CGPoint(x: 600, y: 268),
    ],
    radii: [10, 26, 40, 40, 26, 10]
)

// Liquid, clipped to the flask.
context.saveGState()
context.addPath(flask)
context.clip()
context.addRect(CGRect(x: 240, y: 556, width: 544, height: 220))
context.clip()
context.drawLinearGradient(
    gradient([rgb(0xFF8A4C), rgb(0xFFC93C)], [0, 1]),
    start: CGPoint(x: 300, y: 560),
    end: CGPoint(x: 720, y: 770),
    options: []
)
for bubble in [(x: 420.0, y: 660.0, r: 26.0, a: 0.55), (x: 530.0, y: 620.0, r: 17.0, a: 0.45),
               (x: 596.0, y: 690.0, r: 12.0, a: 0.4)] {
    context.setFillColor(rgb(0xFFFFFF, bubble.a))
    context.fillEllipse(in: CGRect(
        x: bubble.x - bubble.r, y: bubble.y - bubble.r,
        width: bubble.r * 2, height: bubble.r * 2
    ))
}
context.restoreGState()

// Glass highlight along the left wall, below the shoulder so the neck stays clean.
context.saveGState()
context.addPath(flask)
context.clip()
context.setFillColor(rgb(0xFFFFFF, 0.18))
let highlight = CGMutablePath()
highlight.move(to: CGPoint(x: 424, y: 488))
highlight.addLine(to: CGPoint(x: 330, y: 706))
highlight.addLine(to: CGPoint(x: 386, y: 706))
highlight.addLine(to: CGPoint(x: 472, y: 488))
highlight.closeSubpath()
context.addPath(highlight)
context.fillPath()
context.restoreGState()

// Outline and the lip on top of it.
context.setStrokeColor(rgb(0xFFFFFF))
context.setLineWidth(30)
context.setLineJoin(.round)
context.setLineCap(.round)
context.addPath(flask)
context.strokePath()

let lip = CGPath(
    roundedRect: CGRect(x: 396, y: 222, width: 232, height: 62),
    cornerWidth: 31, cornerHeight: 31,
    transform: nil
)
context.setFillColor(rgb(0xFFFFFF))
context.addPath(lip)
context.fillPath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil
      )
else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(output) at \(size)px")
