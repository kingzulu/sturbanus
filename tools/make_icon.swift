// Erzeugt das App-Icon: swift tools/make_icon.swift StUrbanus/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// App-Icon 1024×1024: Fahne auf dem Grün, Ball, auf dunkelgrünem Verlauf.
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
// CoreGraphics: Ursprung unten links. Helfer mit y von oben.
func y(_ v: CGFloat) -> CGFloat { CGFloat(size) - v }

// Hintergrund: Verlauf von oben (heller) nach unten (dunkler).
let bg = CGGradient(colorsSpace: space, colors: [color(0x2E8B47), color(0x0F4D26)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: y(0)), end: CGPoint(x: 0, y: y(1024)), options: [])

// Grün (Ellipse) mit leichtem Verlauf.
let greenRect = CGRect(x: 152, y: y(860), width: 720, height: 210)
ctx.saveGState()
ctx.addEllipse(in: greenRect)
ctx.clip()
let greenGrad = CGGradient(colorsSpace: space, colors: [color(0x7ACC6E), color(0x4FA94D)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(greenGrad, start: CGPoint(x: 0, y: greenRect.maxY), end: CGPoint(x: 0, y: greenRect.minY), options: [])
ctx.restoreGState()

// Loch.
ctx.setFillColor(color(0x123B1F))
ctx.fillEllipse(in: CGRect(x: 556, y: y(782), width: 92, height: 30))

// Fahnenstange.
let poleX: CGFloat = 594
ctx.setFillColor(color(0xFFFFFF))
ctx.fill(CGRect(x: poleX, y: y(772), width: 16, height: 560))
ctx.fillEllipse(in: CGRect(x: poleX - 6, y: y(224), width: 28, height: 28))

// Wimpel (goldgelb).
ctx.setFillColor(color(0xF5C542))
ctx.beginPath()
ctx.move(to: CGPoint(x: poleX + 16, y: y(232)))
ctx.addLine(to: CGPoint(x: 846, y: y(318)))
ctx.addLine(to: CGPoint(x: poleX + 16, y: y(404)))
ctx.closePath()
ctx.fillPath()

// Ball mit Schatten.
ctx.setFillColor(color(0x000000, 0.25))
ctx.fillEllipse(in: CGRect(x: 330, y: y(822), width: 110, height: 26))
let ballRect = CGRect(x: 330, y: y(808), width: 104, height: 104)
ctx.saveGState()
ctx.addEllipse(in: ballRect)
ctx.clip()
let ballGrad = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF), color(0xD9DED9)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(ballGrad, startCenter: CGPoint(x: ballRect.midX - 20, y: ballRect.midY + 20), startRadius: 4,
                       endCenter: CGPoint(x: ballRect.midX, y: ballRect.midY), endRadius: 60, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.restoreGState()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
