import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sizes = [16, 32, 128, 256, 512]

func drawIcon(size: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setFillColor(CGColor.white)
    context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024), cornerWidth: 220, cornerHeight: 220, transform: nil))
    context.fillPath()

    context.setFillColor(CGColor(red: 0.10, green: 0.13, blue: 0.17, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 170, y: 250, width: 620, height: 500), cornerWidth: 86, cornerHeight: 86, transform: nil))
    context.fillPath()
    context.addPath(CGPath(roundedRect: CGRect(x: 790, y: 400, width: 74, height: 200), cornerWidth: 30, cornerHeight: 30, transform: nil))
    context.fillPath()

    context.setFillColor(CGColor.white)
    context.addPath(CGPath(roundedRect: CGRect(x: 218, y: 298, width: 524, height: 404), cornerWidth: 52, cornerHeight: 52, transform: nil))
    context.fillPath()

    context.setFillColor(CGColor(red: 0.16, green: 0.78, blue: 0.48, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: 252, y: 332, width: 456, height: 336), cornerWidth: 34, cornerHeight: 34, transform: nil))
    context.fillPath()

    context.setFillColor(CGColor(red: 0.12, green: 0.35, blue: 0.92, alpha: 1))
    context.move(to: CGPoint(x: 495, y: 360))
    context.addLine(to: CGPoint(x: 380, y: 532))
    context.addLine(to: CGPoint(x: 477, y: 532))
    context.addLine(to: CGPoint(x: 445, y: 665))
    context.addLine(to: CGPoint(x: 624, y: 454))
    context.addLine(to: CGPoint(x: 520, y: 454))
    context.addLine(to: CGPoint(x: 557, y: 360))
    context.closePath()
    context.fillPath()
    return context.makeImage()
}

for size in sizes {
    for scale in [1, 2] {
        let pixelSize = size * scale
        guard let image = drawIcon(size: pixelSize) else { continue }
        let suffix = scale == 1 ? "" : "@2x"
        let filename = "icon_\(size)x\(size)\(suffix).png"
        let url = outputDirectory.appendingPathComponent(filename)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}