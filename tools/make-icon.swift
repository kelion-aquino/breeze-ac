// Usage: swift tools/make-icon.swift Breeze/Assets.xcassets/AppIcon.appiconset
import AppKit
import SwiftUI

struct IconView: View {
    var body: some View {
        ZStack {
            // Standard macOS icon grid: 824 pt squircle on a 1024 pt canvas
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.36, green: 0.78, blue: 1.0), Color(red: 0.05, green: 0.33, blue: 0.82)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.3), radius: 18, y: 12)

            VStack(spacing: 26) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 560, height: 170)
                        .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
                    Capsule()
                        .fill(Color(red: 0.08, green: 0.16, blue: 0.3).opacity(0.8))
                        .frame(width: 470, height: 18)
                        .padding(.bottom, 26)
                    Circle()
                        .fill(Color(red: 0.3, green: 0.85, blue: 1.0))
                        .frame(width: 22, height: 22)
                        .shadow(color: .cyan, radius: 8)
                        .offset(x: 220, y: -110)
                }

                Canvas { context, size in
                    for index in 0..<7 {
                        let x = size.width * (0.12 + 0.76 * Double(index) / 6)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        for y in stride(from: 0.0, through: size.height, by: 4) {
                            let sway = sin(y * 0.045 + Double(index)) * 14 * (y / size.height)
                            path.addLine(to: CGPoint(x: x + sway + (x - size.width / 2) * y / size.height * 0.35, y: y))
                        }
                        context.stroke(
                            path,
                            with: .linearGradient(Gradient(colors: [.white.opacity(0.95), .white.opacity(0)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                    }
                }
                .frame(width: 520, height: 250)
            }
            .offset(y: 30)
        }
        .frame(width: 1024, height: 1024)
    }
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let master: CGImage = MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("render failed") }
    return image
}

func writePNG(_ image: CGImage, pixels: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try writePNG(master, pixels: points * scale, to: outputDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: outputDir.appendingPathComponent("Contents.json"))
print("Wrote \(outputDir.path)")
