// Erzeugt das App-Icon: swift tools/make_icon.swift StUrbanus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// „C“ für Caddy im Stil des ZG-Logos (Gold, Rot, Blau auf Marineblau), darin eine Fahne auf dem Grün.
// Gezeichnet im 160er-Raster des Entwurfs und auf 1024 px skaliert; iOS rundet die Ecken selbst ab.
let size = 1024
let scale = CGFloat(size) / 160
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let navy = color(0x1B2233), white = color(0xFFFFFF), gold = color(0xFFC20A), blue = color(0x1555A5), red = color(0xDB202C)

// Koordinaten wie im Entwurf: Ursprung oben links, y nach unten.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: scale, y: -scale)

ctx.setFillColor(navy)
ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 160))

/// Bogenstück des C von `from` nach `to` (Grad, 0 = rechts, positiv im Uhrzeigersinn).
func arc(from: CGFloat, to: CGFloat, _ stroke: CGColor) {
    let center = CGPoint(x: 76, y: 82), radius: CGFloat = 46, steps = 96
    ctx.beginPath()
    for i in 0...steps {
        let angle = (from + (to - from) * CGFloat(i) / CGFloat(steps)) * .pi / 180
        let p = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        i == 0 ? ctx.move(to: p) : ctx.addLine(to: p)
    }
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(18)
    ctx.setLineCap(.butt)
    ctx.strokePath()
}
arc(from: -42, to: -165, gold)
arc(from: 195, to: 70, red)
arc(from: 70, to: 42, blue)

// Grün, Fahnenstange, Wimpel.
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: 72 - 17, y: 106 - 4.5, width: 34, height: 9))
ctx.fill(CGRect(x: 68, y: 54, width: 5, height: 52))
ctx.setFillColor(gold)
ctx.beginPath()
ctx.move(to: CGPoint(x: 73, y: 54))
ctx.addLine(to: CGPoint(x: 100, y: 63))
ctx.addLine(to: CGPoint(x: 73, y: 72))
ctx.closePath()
ctx.fillPath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
