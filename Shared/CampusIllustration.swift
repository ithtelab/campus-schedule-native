import SwiftUI
import UIKit

@MainActor enum CampusSpriteImage {
    static func frame(sheet: CGImage, index: Int, girl: Bool, padded: Bool = true) -> UIImage? {
        guard let rect = CampusSpriteLayout.rect(index: index, girl: girl, width: sheet.width, height: sheet.height),
              let cropped = sheet.cropping(to: rect), let cleaned = cleanEdges(cropped) else { return nil }
        let image = UIImage(cgImage: cleaned)
        guard padded else { return image }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 480), format: format).image { _ in
            let scale = min(1, 244 / image.size.width, 466 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (256 - size.width) / 2, y: 472 - size.height, width: size.width, height: size.height))
        }
    }

    private static func cleanEdges(_ source: CGImage) -> CGImage? {
        let w = source.width, h = source.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
            let data = raw.bindMemory(to: UInt8.self)
            for p in 0..<(w * h) where data[p * 4 + 3] <= 24 {
                for channel in 0..<4 { data[p * 4 + channel] = 0 }
            }
            var seen = [Bool](repeating: false, count: w * h)
            var components: [([Int], Bool)] = []
            for pixel in 0..<(w * h) where !seen[pixel] && data[pixel * 4 + 3] > 24 {
                var queue = [pixel], head = 0, edge = false
                seen[pixel] = true
                while head < queue.count {
                    let p = queue[head]; head += 1
                    let x = p % w, y = p / w
                    edge = edge || x == 0 || x == w - 1 || y == 0 || y == h - 1
                    for (nx, ny) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where nx >= 0 && nx < w && ny >= 0 && ny < h {
                        let n = ny * w + nx
                        if !seen[n] && data[n * 4 + 3] > 24 { seen[n] = true; queue.append(n) }
                    }
                }
                components.append((queue, edge))
            }
            let largest = components.map { $0.0.count }.max() ?? 0
            // Remove isolated speckles and thin fragments from adjacent columns, not the main figure.
            for (component, edge) in components where component.count < largest / 80 || (edge && component.count < largest / 7) {
                for p in component { for channel in 0..<4 { data[p * 4 + channel] = 0 } }
            }
            return context.makeImage()
        }
    }
    static let reading: UIImage? = {
        guard let sheet = UIImage(named: "CampusGirlActions")?.cgImage else { return nil }
        return frame(sheet: sheet, index: 0, girl: true, padded: false)
    }()
}

struct CampusWidgetFigure: View {
    var body: some View {
        if let image = CampusSpriteImage.reading {
            Image(uiImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

struct CampusBookMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.1))
        p.addLines([CGPoint(x: rect.midX, y: rect.height * 0.18), CGPoint(x: rect.maxX * 0.92, y: rect.minY), CGPoint(x: rect.maxX * 0.92, y: rect.maxY * 0.84), CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.width * 0.08, y: rect.maxY * 0.9)])
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.midX, y: rect.height * 0.18)); p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
