import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: process_status_icon.swift input.png output.png\n".utf8))
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fatalError("Could not decode \(inputURL.path)")
}

// Image generation currently renders its transparency preview into the pixels.
// Crop tightly around the single circular element, then retain the physical orb.
// The generated preview bakes checkerboard pixels into the outer glow, so the
// reproducible export intentionally uses a clean, antialiased circular edge.
let cropSide = min(image.width, image.height) * 56 / 100
let cropRect = CGRect(
    x: (image.width - cropSide) / 2,
    y: (image.height - cropSide) / 2,
    width: cropSide,
    height: cropSide
)

guard let cropped = image.cropping(to: cropRect) else {
    fatalError("Could not crop \(inputURL.path)")
}

let width = cropped.width
let height = cropped.height
let bytesPerRow = width * 4
var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    // BGRA byte layout in memory keeps alpha at offset +3 below.
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
) else {
    fatalError("Could not create bitmap context")
}

context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

let centerX = Double(width - 1) / 2
let centerY = Double(height - 1) / 2
let radius = Double(width) * 0.397

for y in 0 ..< height {
    for x in 0 ..< width {
        let offset = y * bytesPerRow + x * 4
        let distance = hypot(Double(x) - centerX, Double(y) - centerY)
        let alpha = max(0, min(1, radius + 0.5 - distance))

        let byteAlpha = UInt8(max(0, min(255, Int(alpha * 255))))
        pixels[offset] = UInt8(Double(pixels[offset]) * alpha)
        pixels[offset + 1] = UInt8(Double(pixels[offset + 1]) * alpha)
        pixels[offset + 2] = UInt8(Double(pixels[offset + 2]) * alpha)
        pixels[offset + 3] = byteAlpha
    }
}

guard
    let outputImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fatalError("Could not create output at \(outputURL.path)")
}

CGImageDestinationAddImage(destination, outputImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(outputURL.path)")
}
