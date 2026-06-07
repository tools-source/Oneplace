// Downscales the 1024 master into every AppIcon size as fully-opaque PNGs (no alpha).
// Run: swift scripts/resize_icons.swift <masterPNG> <appiconsetDir>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let masterPath = args.count > 1 ? args[1] : "/tmp/iconout/appicon.svg.png"
let outDir = args.count > 2 ? args[2] :
    "/Users/majdinagi/Documents/Oneplace/OnePlace/Resources/Assets.xcassets/AppIcon.appiconset"

let targets: [(String, Int)] = [
    ("Icon-40.png", 40), ("Icon-60.png", 60), ("Icon-58.png", 58), ("Icon-87.png", 87),
    ("Icon-80.png", 80), ("Icon-120 1.png", 120), ("Icon-120.png", 120),
    ("Icon-180.png", 180), ("Icon-1024.png", 1024)
]

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: masterPath) as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("Failed to load master: \(masterPath)\n".data(using: .utf8)!)
    exit(1)
}

let cs = CGColorSpaceCreateDeviceRGB()
for (name, size) in targets {
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: size * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let out = ctx.makeImage() else { continue }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, out, nil)
    if CGImageDestinationFinalize(dest) { print("✓ \(name) (\(size)x\(size))") }
}
print("Done.")
