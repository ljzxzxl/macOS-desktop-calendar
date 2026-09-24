// 生成应用图标（深色月历网格），输出到 Resources/Assets.xcassets/AppIcon.appiconset。
// 在项目根目录执行：xcrun swiftc -parse-as-library scripts/render-app-icon.swift -o build/render-app-icon && build/render-app-icon
import AppKit
import SwiftUI

private let red = Color(red: 0.95, green: 0.30, blue: 0.26)
private let selectionBlue = Color(red: 0.55, green: 0.67, blue: 1)
private let iconRadius: CGFloat = 185

private struct AppIconView: View {
    enum Kind { case normal, holiday, work, selected }

    let rows: [[Kind]] = [
        [.normal, .normal, .normal, .normal, .normal],
        [.normal, .selected, .holiday, .holiday, .holiday],
        [.holiday, .holiday, .holiday, .holiday, .normal],
        [.normal, .work, .normal, .normal, .normal]
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.19, green: 0.22, blue: 0.29), Color(red: 0.09, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 22) {
                HStack {
                    RoundedRectangle(cornerRadius: 22).fill(red.opacity(0.9)).frame(width: 150, height: 74)
                        .overlay(Text("假期").font(.custom("PingFangSC-Semibold", size: 44)).foregroundStyle(.white))
                    Spacer()
                    RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.14)).frame(width: 250, height: 74)
                    Spacer()
                    RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.14)).frame(width: 150, height: 74)
                }
                .frame(width: 664)
                .padding(.bottom, 14)
                ForEach(0..<rows.count, id: \.self) { row in
                    HStack(spacing: 22) {
                        ForEach(0..<5, id: \.self) { column in cell(rows[row][column]) }
                    }
                }
            }
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: iconRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: iconRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.30), radius: 20, y: 14)
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder
    private func cell(_ kind: Kind) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        switch kind {
        case .normal:
            shape.fill(Color.white.opacity(0.10)).frame(width: 115, height: 115)
        case .holiday:
            shape.fill(red.opacity(0.88)).frame(width: 115, height: 115)
                .overlay(Text("休").font(.custom("PingFangSC-Semibold", size: 60)).foregroundStyle(.white))
        case .work:
            shape.fill(Color.white.opacity(0.26)).frame(width: 115, height: 115)
                .overlay(Text("班").font(.custom("PingFangSC-Semibold", size: 60)).foregroundStyle(.white.opacity(0.9)))
        case .selected:
            shape.fill(selectionBlue.opacity(0.25)).frame(width: 115, height: 115)
                .overlay(shape.strokeBorder(selectionBlue, lineWidth: 9))
        }
    }
}

@MainActor
private func renderIcons() throws {
    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = points * scale
            let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
            let renderer = ImageRenderer(content: AppIconView())
            renderer.scale = CGFloat(pixels) / 1024
            guard let cgImage = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try png.write(to: output.appendingPathComponent(filename))
            images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
        }
    }

    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: output.appendingPathComponent("Contents.json"))
    print("wrote \(images.count) icons to \(output.path)")
}

@main
private enum RenderAppIcon {
    @MainActor
    static func main() throws {
        try renderIcons()
    }
}
