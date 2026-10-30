import SwiftUI
import UIKit

enum CampusPose: Int, CaseIterable {
    case reading, walking, stretching
}

private struct CampusSuppressMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var campusSuppressMotion: Bool {
        get { self[CampusSuppressMotionKey.self] }
        set { self[CampusSuppressMotionKey.self] = newValue }
    }
}

@MainActor
enum CampusArtAssets {
    // Each crop has its own empty margin, so adjacent stool/figure pixels never enter the girl's artwork.
    static let figures: [CampusPose: UIImage] = {
        guard let sheet = UIImage(named: "CampusStudents")?.cgImage else { return [:] }
        let ranges: [(CampusPose, CGFloat, CGFloat)] = [(.reading, 0, 0.36), (.walking, 0.36, 0.69), (.stretching, 0.69, 1)]
        return Dictionary(uniqueKeysWithValues: ranges.compactMap { pose, left, right in
            let rect = CGRect(x: CGFloat(sheet.width) * left, y: 0,
                              width: CGFloat(sheet.width) * (right - left), height: CGFloat(sheet.height)).integral
            guard let image = sheet.cropping(to: rect) else { return nil }
            return (pose, UIImage(cgImage: image))
        })
    }()

    static var available: Bool {
        figures.count == CampusPose.allCases.count && UIFont(name: "MaShanZheng-Regular", size: 20) != nil
    }
}

struct CampusFigure: View {
    let pose: CampusPose
    var animates = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if animates && !reduceMotion && !suppressMotion && phase == .active {
                artwork.phaseAnimator([false, true]) { content, raised in
                    content.offset(y: raised ? -2 : 0)
                        .rotationEffect(.degrees(raised ? (pose == .walking ? 1 : -0.6) : 0), anchor: .bottom)
                } animation: { _ in .easeInOut(duration: pose == .walking ? 1.4 : 2.8) }
            } else {
                artwork
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var artwork: some View {
        if let image = CampusArtAssets.figures[pose] {
            if colorScheme == .dark {
                Image(uiImage: image).resizable().scaledToFit().colorInvert()
            } else {
                Image(uiImage: image).resizable().scaledToFit()
            }
        }
    }
}

struct CampusUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 1, y: rect.height * 0.55))
        path.addCurve(to: CGPoint(x: rect.width - 1, y: rect.height * 0.3),
                      control1: CGPoint(x: rect.width * 0.38, y: 0),
                      control2: CGPoint(x: rect.width * 0.6, y: rect.height * 0.9))
        return path
    }
}

struct CampusHeading: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(DesignSystem.hand(28)).foregroundStyle(.primary)
            CampusUnderline().stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 112, height: 5).accessibilityHidden(true)
        }
    }
}

struct CampusNotebook: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.1, y: h * 0.16))
        p.addLines([CGPoint(x: w * 0.48, y: h * 0.24), CGPoint(x: w * 0.91, y: h * 0.12),
                    CGPoint(x: w * 0.9, y: h * 0.83), CGPoint(x: w * 0.49, y: h * 0.94),
                    CGPoint(x: w * 0.09, y: h * 0.84), CGPoint(x: w * 0.1, y: h * 0.16)])
        p.move(to: CGPoint(x: w * 0.49, y: h * 0.25)); p.addLine(to: CGPoint(x: w * 0.49, y: h * 0.93))
        for y in [0.38, 0.56] {
            p.move(to: CGPoint(x: w * 0.2, y: h * y)); p.addLine(to: CGPoint(x: w * 0.36, y: h * (y + 0.03)))
            p.move(to: CGPoint(x: w * 0.62, y: h * y)); p.addLine(to: CGPoint(x: w * 0.79, y: h * (y - 0.04)))
        }
        return p
    }
}
