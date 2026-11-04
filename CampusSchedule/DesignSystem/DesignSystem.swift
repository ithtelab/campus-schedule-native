import SwiftUI

enum DesignSystem {
    static let accent = Color.primary
    // Keep the native white switch thumb visible in both appearances.
    static let switchTint = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.58 : 0.12, alpha: 1)
    })
    static let toolbarTint = Color.primary
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let paper = Color(uiColor: .systemBackground)
    static let inverse = Color(uiColor: .systemBackground)
    static let rule = Color.primary.opacity(0.16)
    static let muted = Color.secondary
    static let spacing: CGFloat = 20
    static let cornerRadius: CGFloat = 18
    static func hand(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("MaShanZheng-Regular", size: size, relativeTo: style)
    }
}

/// The same surface is shown in the selector and on the two illustrated campus cards.
struct CampusThemeSurface: View {
    @Environment(\.colorScheme) private var scheme
    let theme: CampusTheme
    var density: DecorationDensity = .light
    var isSwatch = false

    private var base: Color {
        guard isSwatch else { return DesignSystem.paper }
        if theme == .chalkboard { return Color(white: scheme == .dark ? 0.13 : 0.28) }
        return Color(white: scheme == .dark ? 0.32 : 0.92)
    }

    private var lineColor: Color {
        if isSwatch && theme == .chalkboard { return .white.opacity(0.72) }
        if isSwatch { return Color.primary.opacity(0.42) }
        return Color.primary.opacity(theme == .chalkboard ? 0.28 : 0.16)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            base
            Canvas { context, size in
                var lines = Path()
                switch theme {
                case .paper:
                    break
                case .notebook:
                    for y in stride(from: isSwatch ? 9.0 : 21.0, to: size.height, by: isSwatch ? 8 : 18) {
                        lines.move(to: CGPoint(x: 0, y: y))
                        lines.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    lines.move(to: CGPoint(x: 10, y: 0))
                    lines.addLine(to: CGPoint(x: 10, y: size.height))
                case .chalkboard:
                    lines.addRoundedRect(in: CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5),
                                         cornerSize: CGSize(width: 8, height: 8))
                    lines.move(to: CGPoint(x: 12, y: size.height - 9))
                    lines.addLine(to: CGPoint(x: size.width - 12, y: size.height - 9))
                }
                context.stroke(lines, with: .color(lineColor), lineWidth: 1)
            }
            .background(theme == .chalkboard && !isSwatch ? Color.primary.opacity(0.075) : .clear)

            if density == .rich {
                Image(systemName: theme == .chalkboard ? "sparkles" : "paperclip")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(-12))
                    .padding(10)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 课程配色。
///
/// 课表整体是黑白手绘风格，因此颜色只作为**识别辅助**而不是主色：
/// 卡片用很低的透明度着色，左侧一条窄色条承担区分，正文始终用主文字色。
/// 这样深浅色模式下对比度都够，也不会把界面变成色块拼贴。
enum CourseColor: String, CaseIterable, Codable {
    case blue, purple, orange, green, pink, indigo, brown, teal

    var name: String {
        switch self {
        case .blue: "海蓝"
        case .purple: "鸢紫"
        case .orange: "暖橙"
        case .green: "青绿"
        case .pink: "玫粉"
        case .indigo: "靛蓝"
        case .brown: "赭石"
        case .teal: "湖蓝"
        }
    }

    /// 左侧色条与进行中状态使用的高饱和色。
    var accentColor: Color {
        switch self {
        case .blue: Color(red: 0.29, green: 0.56, blue: 0.89)
        case .purple: Color(red: 0.58, green: 0.44, blue: 0.86)
        case .orange: Color(red: 0.91, green: 0.58, blue: 0.24)
        case .green: Color(red: 0.35, green: 0.71, blue: 0.46)
        case .pink: Color(red: 0.89, green: 0.48, blue: 0.60)
        case .indigo: Color(red: 0.42, green: 0.47, blue: 0.85)
        case .brown: Color(red: 0.69, green: 0.54, blue: 0.42)
        case .teal: Color(red: 0.28, green: 0.68, blue: 0.70)
        }
    }

    /// 卡片底色。透明度按外观调整：浅色下需要更淡，深色下需要更亮才看得出。
    func fill(for scheme: ColorScheme) -> Color {
        accentColor.opacity(scheme == .dark ? 0.26 : 0.14)
    }

    /// 卡片描边，跟随底色但稍强一点。
    func border(for scheme: ColorScheme) -> Color {
        accentColor.opacity(scheme == .dark ? 0.42 : 0.30)
    }

    /// 已结束课程的底色：进一步压暗，弱化但不消失。
    func endedFill(for scheme: ColorScheme) -> Color {
        accentColor.opacity(scheme == .dark ? 0.12 : 0.06)
    }

    /// 兼容旧调用点。
    var tint: Color { accentColor }
}

struct CourseCard: View {
    let course: DemoCourse

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.startTime).font(.headline.monospacedDigit())
                Text(course.endTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(minWidth: 48, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.primary)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 9) {
                Text(course.title).font(.headline).foregroundStyle(.primary)
                Label(course.room, systemImage: "mappin.and.ellipse")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("第 \(course.startPeriod)–\(course.endPeriod) 节 · \(course.teacher)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(18)
        .fixedSize(horizontal: false, vertical: true)
        .background(DesignSystem.surface, in: RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
        .contentShape(Rectangle())
    }
}
