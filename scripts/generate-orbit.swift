/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
// Original geometric artwork; concept images are references, never edited by this generator.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(filePath: FileManager.default.currentDirectoryPath)
let catalog = root.appending(path: "LocalPackage/Sources/UserInterface/Resources/Media.xcassets/Runners/Orbit")
let black = CGColor(gray: 0, alpha: 1)
let teal = CGColor(red: 0.17, green: 0.47, blue: 0.50, alpha: 1)
let cream = CGColor(red: 0.94, green: 0.91, blue: 0.85, alpha: 1)
let ink = CGColor(red: 0.10, green: 0.16, blue: 0.19, alpha: 1)
let frameCount = 32

enum Flight: String, CaseIterable {
    case idle, cruise, boost
    var prefix: String {
        switch self { case .idle: "orbit-idle-frame"; case .cruise: "orbit-frame"; case .boost: "orbit-boost-frame" }
    }
}

func ribbon(_ context: CGContext, start: Double, end: Double, y: Double, phase: Double, amplitude: Double) {
    let shape = CGMutablePath()
    for side in [1.0, -1.0] {
        let steps = side == 1 ? Array(0...32) : Array((0...32).reversed())
        for (offset, step) in steps.enumerated() {
            let progress = Double(step) / 32
            let x = start + (end - start) * progress
            let center = y + sin(phase - progress * 5) * amplitude * progress
            let width = 0.15 + (1 - progress) * 0.55
            let point = CGPoint(x: x, y: center + side * width)
            if side == 1 && offset == 0 { shape.move(to: point) } else { shape.addLine(to: point) }
        }
    }
    shape.closeSubpath()
    context.addPath(shape)
    context.fillPath()
}

func drawProbe(_ context: CGContext, phase: Double, colored: Bool, flight: Flight) {
    let quiet = flight == .idle
    let boost = flight == .boost
    let center = quiet ? 14.0 : boost ? 9.1 : 10.6
    let bob = sin(phase) * (quiet ? 0.55 : 0.25)
    context.saveGState()
    context.translateBy(x: 0, y: bob)
    context.setFillColor(colored ? teal : black)
    let upper = CGMutablePath()
    if quiet {
        upper.move(to: CGPoint(x: 9.2, y: 7.4))
        upper.addCurve(to: CGPoint(x: 16.9, y: 16.1), control1: CGPoint(x: 6.8, y: 13.6), control2: CGPoint(x: 16.2, y: 17.9))
        upper.addCurve(to: CGPoint(x: 10.0, y: 8.0), control1: CGPoint(x: 18.7, y: 15.2), control2: CGPoint(x: 11.3, y: 10.0))
    } else {
        upper.move(to: CGPoint(x: center - 4, y: 11.0))
        upper.addCurve(to: CGPoint(x: boost ? 26.4 : 23.7, y: 15.9 + sin(phase + 0.8) * 0.5),
                       control1: CGPoint(x: 12.7, y: 16.1), control2: CGPoint(x: 24.8, y: 18.0))
        upper.addCurve(to: CGPoint(x: center - 2.0, y: 10.5),
                       control1: CGPoint(x: boost ? 23.2 : 21.7, y: 13.8), control2: CGPoint(x: 14.0, y: 11.4))
    }
    upper.closeSubpath()
    context.addPath(upper)
    context.fillPath()
    let lower = CGMutablePath()
    lower.move(to: CGPoint(x: center - 1.0, y: 4.4))
    if quiet {
        lower.addCurve(to: CGPoint(x: 17.9, y: 2.5), control1: CGPoint(x: 15.1, y: 1.6), control2: CGPoint(x: 20.3, y: 2.6))
        lower.addCurve(to: CGPoint(x: center + 1.8, y: 5.2), control1: CGPoint(x: 17.0, y: 4.5), control2: CGPoint(x: 17.0, y: 4.8))
    } else {
        lower.addCurve(to: CGPoint(x: boost ? 20.0 : 18.5, y: 1.8 - sin(phase) * 0.4),
                       control1: CGPoint(x: 12.0, y: 1.7), control2: CGPoint(x: 18.5, y: 0.6))
        lower.addCurve(to: CGPoint(x: center + 2.5, y: 5.5), control1: CGPoint(x: 18.9, y: 4.0), control2: CGPoint(x: 14.2, y: 5.4))
    }
    lower.closeSubpath()
    context.addPath(lower)
    context.fillPath()
    if !quiet {
        ribbon(context, start: center + 2, end: boost ? 27.2 : 24.0, y: 8.5, phase: phase, amplitude: boost ? 1.3 : 0.8)
        if boost { ribbon(context, start: center + 3, end: 26.1, y: 6.4, phase: phase + 1.2, amplitude: 1.5) }
    }
    context.setBlendMode(.clear)
    context.fillEllipse(in: CGRect(x: center - 5.6, y: 2.1, width: 11.2, height: 12.1))
    context.setBlendMode(.normal)
    context.setFillColor(colored ? cream : black)
    context.fillEllipse(in: CGRect(x: center - 4.9, y: 2.8, width: 9.8, height: 10.7))
    // The crescent aperture is the identity, visible even in a monochrome 28x18pt template.
    context.setLineCap(.butt)
    context.setLineWidth(1.8)
    context.setStrokeColor(ink)
    context.setBlendMode(colored ? .normal : .clear)
    context.addArc(center: CGPoint(x: center - 0.6, y: 8.2), radius: 2.65,
                   startAngle: .pi * 0.3, endAngle: .pi * 1.7, clockwise: false)
    context.strokePath()
    context.setBlendMode(.clear)
    context.fill(CGRect(x: center + 3.7, y: 8.5, width: 1.7, height: 0.8))
    context.setBlendMode(.normal)
    context.restoreGState()
}

func image(width: Int, height: Int, logicalWidth: Double, logicalHeight: Double,
           phase: Double, colored: Bool, flight: Flight) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: Double(width) / logicalWidth, y: Double(height) / logicalHeight)
    if logicalHeight == 28 { context.translateBy(x: 0, y: 5) }
    drawProbe(context, phase: phase, colored: colored, flight: flight)
    return context.makeImage()!
}

func save(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
func saveJSON(_ value: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
try saveJSON(["info": ["author": "Cosee", "version": 1]], to: catalog.appending(path: "Contents.json"))
for flight in Flight.allCases {
    for frame in 0..<frameCount {
        let name = "\(flight.prefix)-\(frame)"
        let folder = catalog.appending(path: "\(name).imageset")
        try save(image(width: 56, height: 36, logicalWidth: 28, logicalHeight: 18,
                       phase: Double(frame) * 2 * .pi / Double(frameCount), colored: false, flight: flight),
                 to: folder.appending(path: "\(name).png"))
        try saveJSON(["images": [["filename": "\(name).png", "idiom": "mac"]],
                      "info": ["author": "Cosee", "version": 1],
                      "properties": ["template-rendering-intent": "template"]],
                     to: folder.appending(path: "Contents.json"))
    }
    let motionURL = root.appending(path: "docs/design/core-\(flight.rawValue).gif")
    try FileManager.default.createDirectory(at: motionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let motion = CGImageDestinationCreateWithURL(motionURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil)!
    CGImageDestinationSetProperties(motion, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in 0..<frameCount {
        let preview = image(width: 224, height: 144, logicalWidth: 28, logicalHeight: 18,
                            phase: Double(frame) * 2 * .pi / Double(frameCount), colored: true, flight: flight)
        let interval = flight == .idle ? 0.083 : flight == .cruise ? 0.055 : 0.026
        CGImageDestinationAddImage(motion, preview, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: interval]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(motion) else { throw CocoaError(.fileWriteUnknown) }
}
try save(image(width: 1024, height: 1024, logicalWidth: 28, logicalHeight: 28, phase: 1.2, colored: true, flight: .cruise),
         to: root.appending(path: "Cosee/AppIcon.icon/Assets/core-probe.png"))
print("Generated 96 Core probe frames, three flight previews, and app icon.")
