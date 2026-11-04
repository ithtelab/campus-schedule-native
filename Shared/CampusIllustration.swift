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

    static func widgetFrame(_ index: Int) -> UIImage? {
        if index == 0 { return reading }
        let name = index == 15 ? "CampusGirlStretchCorrection" : "CampusGirlActions"
        guard let sheet = UIImage(named: name)?.cgImage else { return reading }
        return frame(sheet: sheet, index: index, girl: true, padded: false)
    }
}

struct CampusWidgetFigure: View {
    var frame: Int = 0
    var stickerPersona: CampusPersona? = nil

    var body: some View {
        if let stickerPersona {
            CampusStickerStudent(frame: frame, wearsCap: stickerPersona != .boy)
        } else if let image = CampusSpriteImage.widgetFrame(frame) {
            Image(uiImage: image).renderingMode(.original).resizable().scaledToFit().accessibilityHidden(true)
        }
    }
}

/// The existing animation frames drive a different, die-cut illustration for the blue theme.
struct CampusStickerStudent: View {
    let frame: Int
    var wearsCap = true

    private let ink = CampusStickerMark.ink
    private let cream = CampusStickerMark.cream
    private let blue = CampusStickerMark.blue
    private let skin = Color(red: 1, green: 0.78, blue: 0.65)
    private let pink = Color(red: 0.97, green: 0.49, blue: 0.60)
    private let yellow = Color(red: 1, green: 0.81, blue: 0.35)

    var body: some View {
        Canvas { context, size in
            var context = context
            context.scaleBy(x: size.width / 82, y: size.height / 148)
            context.translateBy(x: -15, y: -1)
            draw(in: context)
        }
        .aspectRatio(82.0 / 148, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func draw(in context: GraphicsContext) {
        let seated = frame < 4 || frame == 14
        let reading = [0, 1, 2, 7, 8, 9].contains(frame)
        let stretching = frame == 15
        let stride: CGFloat = switch frame {
        case 10: 10
        case 11: 4
        case 12: -9
        case 13: -4
        default: 0
        }
        let drop: CGFloat = switch frame {
        case 0...3, 14: 18
        case 4: 12
        case 5: 6
        case 11, 13: -2
        default: 0
        }

        if seated || frame == 4 || frame == 5 {
            limb(context, [.init(x: 37, y: 114), .init(x: 33, y: 141)], fill: yellow, width: 4)
            limb(context, [.init(x: 64, y: 114), .init(x: 66, y: 141)], fill: yellow, width: 4)
            sticker(context, rounded(27, 110, 44, 8, radius: 4), fill: yellow)
        }

        let leftFoot = CGPoint(x: (seated ? 57 : 40) + stride, y: stride < 0 ? 139 : 142)
        let rightFoot = CGPoint(x: (seated ? 81 : 65) - stride, y: stride > 0 ? 138 : 142)
        for (hip, knee, foot) in [(49.0, seated ? 65.0 : 47.0, leftFoot), (65.0, seated ? 82.0 : 64.0, rightFoot)] {
            limb(context, [.init(x: hip, y: 91 + drop), .init(x: knee, y: seated ? 118 : 117), foot],
                 fill: cream, width: 13)
            sticker(context, rounded(foot.x - 7, foot.y - 7, 20, 9, radius: 4), fill: pink)
        }

        sticker(context, rounded(24, 64 + drop, 24, 37, radius: 9), fill: yellow)
        sticker(context, rounded(36, 59 + drop, 40, 39, radius: 12), fill: blue)
        line(context, [.init(x: 56, y: 69 + drop), .init(x: 56, y: 94 + drop)], color: cream.opacity(0.8), width: 1.5)
        sticker(context, rounded(59, 74 + drop, 10, 6, radius: 2), fill: cream, edge: 0)

        let hands: (CGPoint, CGPoint)
        if stretching {
            hands = (.init(x: 76, y: 34), .init(x: 73, y: 12))
            limb(context, [.init(x: 41, y: 68), .init(x: 48, y: 79), .init(x: 76, y: 34)], fill: blue, width: 9)
            limb(context, [.init(x: 72, y: 67), .init(x: 80, y: 36), hands.1], fill: blue, width: 9)
        } else {
            let handHeight = reading ? (seated ? 85 : 81) : 93
            hands = (.init(x: (reading ? 48 : 38) + stride / 2, y: CGFloat(handHeight) + drop),
                     .init(x: (reading ? 78 : 77) - stride / 2, y: CGFloat(handHeight) + drop - 1))
            limb(context, [.init(x: 41, y: 68 + drop), .init(x: 32, y: 81 + drop), hands.0], fill: blue, width: 9)
            limb(context, [.init(x: 71, y: 68 + drop), .init(x: 81, y: 80 + drop), hands.1], fill: blue, width: 9)
        }
        if reading {
            let y = hands.0.y - (frame == 1 || frame == 8 ? 5 : 8)
            let book = polygon([.init(x: 45, y: y), .init(x: 62, y: y + 6), .init(x: 79, y: y - 2),
                                .init(x: 76, y: y + 12), .init(x: 62, y: y + 18), .init(x: 47, y: y + 12)])
            sticker(context, book, fill: yellow)
            line(context, [.init(x: 62, y: y + 7), .init(x: 62, y: y + 17)], color: ink, width: 1.2)
        }
        for hand in [hands.0, hands.1] {
            sticker(context, ellipse(hand.x - 4, hand.y - 4, 8, 8), fill: skin, edge: 0)
        }

        sticker(context, rounded(37, 20 + drop, 42, wearsCap ? 43 : 34, radius: 17), fill: ink)
        sticker(context, rounded(46, 30 + drop, 32, 31, radius: 13), fill: skin, edge: 0)
        context.fill(ellipse(56, 42 + drop, 3.2, 4), with: .color(ink))
        context.fill(ellipse(69, 41 + drop, 3.2, 4), with: .color(ink))
        context.fill(ellipse(51, 48 + drop, 7, 3), with: .color(pink.opacity(0.75)))
        line(context, [.init(x: 61, y: 50 + drop), .init(x: 65, y: 52 + drop), .init(x: 69, y: 49 + drop)],
             color: ink, width: 1.4)
        if wearsCap {
            sticker(context, rounded(33, 16 + drop, 48, 20, radius: 10), fill: blue)
            sticker(context, rounded(59, 29 + drop, 29, 6, radius: 3), fill: cream, edge: 0)
            context.fill(ellipse(53, 21 + drop, 6, 6), with: .color(yellow))
        } else {
            let band = Path { path in
                path.move(to: .init(x: 37, y: 39 + drop))
                path.addQuadCurve(to: .init(x: 79, y: 38 + drop), control: .init(x: 57, y: 7 + drop))
            }
            context.stroke(band, with: .color(yellow), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            sticker(context, rounded(34, 35 + drop, 10, 17, radius: 5), fill: yellow)
            sticker(context, rounded(75, 33 + drop, 8, 15, radius: 4), fill: yellow)
        }
    }

    private func sticker(_ context: GraphicsContext, _ path: Path, fill: Color, edge: CGFloat = 5) {
        let round = StrokeStyle(lineWidth: edge, lineCap: .round, lineJoin: .round)
        if edge > 0 { context.stroke(path, with: .color(cream), style: round) }
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
    }

    private func limb(_ context: GraphicsContext, _ points: [CGPoint], fill: Color, width: CGFloat) {
        line(context, points, color: cream, width: width + 6)
        line(context, points, color: ink, width: width + 2)
        line(context, points, color: fill, width: width)
    }

    private func line(_ context: GraphicsContext, _ points: [CGPoint], color: Color, width: CGFloat) {
        context.stroke(Path { $0.addLines(points) }, with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { path in path.addLines(points); path.closeSubpath() }
    }

    private func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius)
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
    }
}

struct CampusStickerMark: View {
    static let blue = Color(red: 0.76, green: 0.87, blue: 0.97)
    static let cream = Color(red: 1, green: 0.98, blue: 0.92)
    static let ink = Color(red: 0.12, green: 0.24, blue: 0.38)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.66, green: 0.80, blue: 0.95, alpha: 1)
            : UIColor(red: 0.25, green: 0.40, blue: 0.56, alpha: 1)
    })

    var symbol = "paperplane.fill"
    var size: CGFloat = 22
    var fullColor = true
    var decorative = true

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(fullColor ? Self.ink : .primary)
            .background {
                if fullColor {
                    Image(systemName: symbol)
                        .font(.system(size: size * 1.32, weight: .black))
                        .foregroundStyle(Self.cream)
                        .shadow(color: Self.ink.opacity(0.28), radius: 1, y: 1)
                }
            }
            .rotationEffect(.degrees(7))
            .accessibilityHidden(decorative)
    }
}

struct CampusProp: View {
    enum Kind { case notebook, pencil, libraryTicket, headphones, milk, cassette }

    let kind: Kind
    var colorful = false

    var body: some View {
        Canvas { original, size in
            var context = original
            let scale = min(size.width, size.height) / 32
            context.translateBy(x: (size.width - 32 * scale) / 2, y: (size.height - 32 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let ink = colorful ? CampusStickerMark.ink : Color.primary
            let pink = Color(red: 1, green: 0.65, blue: 0.78)
            let blue = Color(red: 0.68, green: 0.78, blue: 1)
            let honey = Color(red: 1, green: 0.83, blue: 0.41)
            func line(_ path: Path, width: CGFloat = 1.8) {
                context.stroke(path, with: .color(ink),
                               style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            func shape(_ path: Path, fill: Color) {
                if colorful {
                    context.stroke(path, with: .color(CampusStickerMark.cream),
                                   style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    context.fill(path, with: .color(fill))
                }
                line(path)
            }
            func polygon(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
                Path { path in
                    path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
                    if closed { path.closeSubpath() }
                }
            }
            func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius)
            }
            switch kind {
            case .notebook:
                shape(polygon([(7, 5), (25, 4), (26, 26), (7, 28)], closed: true), fill: blue)
                for y in [9.0, 15.0, 21.0] {
                    line(polygon([(4, y), (9, y - 0.5)]))
                }
                line(polygon([(13, 11), (21, 10), (21, 15), (13, 16)], closed: true), width: 1.3)
            case .pencil:
                shape(polygon([(5, 23), (21, 5), (27, 10), (11, 28), (4, 29)], closed: true), fill: honey)
                line(polygon([(18, 8), (24, 13)]))
                line(polygon([(5, 23), (11, 28), (4, 29)], closed: true), width: 1.2)
            case .libraryTicket:
                shape(polygon([(4, 8), (10, 8), (12, 6), (15, 8), (28, 8), (28, 14), (25, 16),
                               (28, 18), (28, 24), (4, 24), (4, 18), (7, 16), (4, 14)], closed: true), fill: pink)
                line(polygon([(10, 13), (19, 13), (19, 19), (10, 19)], closed: true), width: 1.3)
                line(polygon([(22, 11), (22, 13), (22, 19), (22, 21)]), width: 1)
            case .headphones:
                let arch = Path { path in
                    path.move(to: .init(x: 6, y: 19))
                    path.addCurve(to: .init(x: 26, y: 19), control1: .init(x: 4, y: 1), control2: .init(x: 28, y: 1))
                }
                if colorful {
                    context.stroke(arch, with: .color(CampusStickerMark.cream),
                                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
                }
                line(arch, width: 2.4)
                shape(rect(4, 17, 7, 10, radius: 3), fill: pink)
                shape(rect(21, 17, 7, 10, radius: 3), fill: pink)
            case .milk:
                shape(polygon([(9, 5), (22, 5), (26, 12), (25, 28), (7, 28), (7, 12)], closed: true), fill: blue)
                line(polygon([(8, 12), (25, 12), (21, 5)]), width: 1.3)
                line(polygon([(12, 20), (15, 22), (19, 20)]), width: 1.3)
                context.fill(Path(ellipseIn: CGRect(x: 10.5, y: 17, width: 2, height: 2)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: 19, y: 17, width: 2, height: 2)), with: .color(ink))
            case .cassette:
                shape(rect(3, 8, 26, 17, radius: 3), fill: honey)
                line(rect(8, 12, 16, 6, radius: 3), width: 1.3)
                for x in [10.0, 19.0] {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: 14, width: 2.5, height: 2.5)), with: .color(ink))
                }
                line(polygon([(11, 23), (13, 21), (20, 21), (22, 23)]), width: 1.2)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Quiet monochrome stationery, used beside titles and in the tighter system surfaces.
struct CampusDeskDoodles: View {
    var density: DecorationDensity
    var compact = false

    var body: some View {
        if density.showsCharacter {
            HStack(spacing: compact ? 3 : 7) {
                Image(systemName: "paperclip")
                    .font(.system(size: compact ? 9 : 15, weight: .medium))
                    .rotationEffect(.degrees(-20))
                CampusProp(kind: .notebook)
                    .frame(width: compact ? 12 : 24, height: compact ? 14 : 25)
                    .rotationEffect(.degrees(8))
                if density.showsExtras {
                    CampusProp(kind: .pencil)
                        .frame(width: compact ? 11 : 23, height: compact ? 14 : 25)
                        .rotationEffect(.degrees(-12))
                    if !compact {
                        CampusProp(kind: .libraryTicket)
                            .frame(width: 23, height: 25)
                            .rotationEffect(.degrees(11))
                            .offset(y: -4)
                    }
                }
            }
            .foregroundStyle(Color.primary.opacity(compact ? 0.8 : 0.67))
            .padding(.horizontal, compact ? 0 : 7)
            .frame(height: compact ? 20 : 44)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
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
