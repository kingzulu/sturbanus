// Erzeugt das App-Icon: swift tools/make_icon.swift StUrbanus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 1024×1024, Vollbild: dunkelgrüner Verlauf, schlanke weiße Fahnenstange mit rotem Wimpel,
// hellgrünes Grün-Oval mit Loch am Fuß. iOS rundet die Ecken selbst ab.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
// CoreGraphics zählt y von unten; Helfer, um mit y von oben zu zeichnen.
func y(_ v: CGFloat) -> CGFloat { CGFloat(size) - v }

// Hintergrund: Verlauf von oben nach unten.
let bg = CGGradient(colorsSpace: space, colors: [color(0x2E8B57), color(0x1B5E3A)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: y(0)), end: CGPoint(x: 0, y: y(1024)), options: [])

// Grün-Oval am Fuß der Fahne.
ctx.setFillColor(color(0x7CC77C))
ctx.fillEllipse(in: CGRect(x: 150, y: y(900), width: 724, height: 196))

// Loch.
let poleX: CGFloat = 430
let poleWidth: CGFloat = 18
ctx.setFillColor(color(0x1B4D30))
ctx.fillEllipse(in: CGRect(x: poleX - 42 + poleWidth / 2, y: y(820), width: 84, height: 28))

// Schlanke Fahnenstange mit kleiner Kugel oben.
let poleTop: CGFloat = 130
ctx.setFillColor(color(0xFFFFFF))
ctx.fill(CGRect(x: poleX, y: y(806), width: poleWidth, height: 806 - poleTop))
ctx.fillEllipse(in: CGRect(x: poleX - 7, y: y(poleTop + 16), width: 32, height: 32))

// Roter dreieckiger Wimpel.
ctx.setFillColor(color(0xE4572E))
ctx.beginPath()
ctx.move(to: CGPoint(x: poleX + poleWidth, y: y(150)))
ctx.addLine(to: CGPoint(x: 860, y: y(300)))
ctx.addLine(to: CGPoint(x: poleX + poleWidth, y: y(450)))
ctx.closePath()
ctx.fillPath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
