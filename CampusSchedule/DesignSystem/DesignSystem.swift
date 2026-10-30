import SwiftUI

enum DesignSystem {
    static let accent = Color.primary
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

enum CourseColor: String, CaseIterable, Codable {
    case blue, purple, orange, green

    var name: String {
        switch self {
        case .blue: "海蓝"
        case .purple: "鸢紫"
        case .orange: "暖橙"
        case .green: "青绿"
        }
    }

    var tint: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .orange: .orange
        case .green: .teal
        }
    }
}

struct DemoNotice: View {
    @Environment(PreviewStore.self) private var store
    var body: some View {
        Label(store.isPreview ? "演示课表 · 尚未连接学校" : "本地课表 · 离线可查看", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .accessibilityLabel(store.isPreview ? "当前为演示课表" : "当前为个人本地课表")
    }
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
