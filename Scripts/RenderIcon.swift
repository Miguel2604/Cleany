import AppKit
import SwiftUI

/// Renders the app icon PNGs and a raccoon mood sheet from `App/Views/Raccoon.swift`.
/// Usage: Scripts/render-icon.sh (compiles this file with Raccoon.swift and runs it).
struct AppIconArt: View {
    var body: some View {
        ZStack {
            // macOS icon grid: 824 pt artwork inside the 1024 canvas.
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.09, green: 0.26, blue: 0.28), Color(red: 0.02, green: 0.09, blue: 0.10)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
            Circle().fill(Color(red: 0.92, green: 0.95, blue: 0.93).opacity(0.9))
                .frame(width: 92, height: 92).offset(x: 250, y: -250)
            Raccoon(mood: .washing, size: 560, pawPhase: 0.25).offset(y: -20)
            // The creek: a translucent band over the raccoon's chin with one ripple highlight.
            VStack(spacing: 0) {
                Spacer()
                ZStack(alignment: .top) {
                    Rectangle().fill(LinearGradient(colors: [Color(red: 0.36, green: 0.72, blue: 0.70).opacity(0.75), Color(red: 0.05, green: 0.25, blue: 0.27).opacity(0.95)],
                                                    startPoint: .top, endPoint: .bottom))
                    Capsule().fill(Color.white.opacity(0.55)).frame(width: 300, height: 10).offset(x: -120, y: 26)
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 160, height: 8).offset(x: 190, y: 54)
                }
                .frame(height: 230)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func write(_ view: some View, scale: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let cg = renderer.cgImage else { fatalError("render failed: \(path)") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

@MainActor func Cleany_main() {
    let args = CommandLine.arguments
    let iconDir = args[1], sheet = args[2]
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = CGFloat(points * scale)
            write(AppIconArt().scaleEffect(px / 1024).frame(width: px, height: px), scale: 1,
                  to: "\(iconDir)/icon_\(points)x\(points)@\(scale)x.png")
        }
    }
    let moods = HStack(spacing: 24) {
        ForEach(RaccoonMood.allCases, id: \.self) { mood in
            VStack {
                Raccoon(mood: mood, size: 120, pawPhase: 0.25)
                Raccoon(mood: mood, size: 18, template: true).foregroundStyle(.white)
                Text(mood.rawValue).foregroundStyle(.white)
            }
        }
    }.padding(24).background(Color(red: 0.04, green: 0.13, blue: 0.15))
    write(moods, scale: 2, to: sheet)
}

@main struct RenderIcon { @MainActor static func main() { Cleany_main() } }
