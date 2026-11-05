#if targetEnvironment(simulator)
import SwiftUI
import WidgetKit

/// 仅供云端截图；直接复用扩展的内容视图，不模拟桌面或锁屏系统宿主。
struct WidgetGalleryView: View {
    private var isLockScreen: Bool { ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] == "lock" }
    private var isExam: Bool { ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] == "exam" }
    private var isSmartAgenda: Bool { ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] == "smart-agenda" }
    private let appearance = AppearancePreferences.simulatorPreview
    private var entry: ScheduleEntry {
        let day = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let now = ScheduleRules.date(day: day, time: "09:41")!
        let courses = [
            CourseOccurrence(id: "english", courseID: "english", title: "大学英语", room: "B 楼 205", start: ScheduleRules.date(day: day, time: "10:00")!, end: ScheduleRules.date(day: day, time: "11:35")!),
            CourseOccurrence(id: "math", courseID: "math", title: "线性代数", room: "A 楼 302", start: ScheduleRules.date(day: day, time: "14:00")!, end: ScheduleRules.date(day: day, time: "15:35")!),
            CourseOccurrence(id: "design", courseID: "design", title: "设计基础", room: "艺术楼 401", start: ScheduleRules.date(day: day, time: "16:00")!, end: ScheduleRules.date(day: day, time: "17:35")!)
        ]
        return ScheduleEntry(date: now, courses: courses, appearance: appearance)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("原生内容布局预览 · 演示数据")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if isSmartAgenda {
                        smartAgendaExamples
                    } else if isExam {
                        section("小号", subtitle: "桌面考试组件") { examContent(.systemSmall, width: 164, height: 164) }
                        section("中号", subtitle: "桌面考试组件") { examContent(.systemMedium, width: 344, height: 164) }
                        section("矩形", subtitle: "锁屏考试组件") { examContent(.accessoryRectangular, width: 160, height: 76) }
                    } else if isLockScreen {
                        section("矩形组件", subtitle: "课程、教室和上课时间") {
                            content(.accessoryRectangular, width: 160, height: 76)
                        }
                        section("行内组件", subtitle: "适合放在锁屏日期上方") {
                            content(.accessoryInline, width: 330, height: 30)
                        }
                        section("没有后续课程", subtitle: "空状态") {
                            content(.accessoryRectangular, width: 160, height: 76, empty: true)
                        }
                    } else {
                        section("小号", subtitle: "快速查看下一节课") {
                            content(.systemSmall, width: 164, height: 164)
                        }
                        section("中号", subtitle: "下一节课与后续安排") {
                            content(.systemMedium, width: 344, height: 164)
                        }
                    }
                    Text("此页复用 WidgetKit 扩展的 SwiftUI 内容。外框仅用于示意尺寸，并非实际桌面或锁屏截图；系统的边距、着色和透明效果仍需宿主验收。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(DesignSystem.background)
            .navigationTitle(isSmartAgenda ? "智能课间预览" : isExam ? "考试组件预览" : isLockScreen ? "锁屏组件预览" : "桌面组件预览")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
    }
    private func section<Content: View>(_ title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
    private func content(_ family: WidgetFamily, width: CGFloat, height: CGFloat, empty: Bool = false) -> some View {
        ScheduleWidgetContent(family: family, entry: empty ? ScheduleEntry(date: entry.date, courses: [], appearance: appearance) : entry)
            .environment(\.widgetRenderingMode, isLockScreen ? .vibrant : .fullColor)
            .padding(family == .systemSmall || family == .systemMedium ? 16 : 8)
            .frame(width: width, height: height, alignment: .leading)
            .background(DesignSystem.surface, in: RoundedRectangle(cornerRadius: family == .systemSmall || family == .systemMedium ? 22 : 10))
    }
    private func examContent(_ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        let date = entry.date.addingTimeInterval(86_400)
        let exam = Exam(courseTitle: "高等数学", date: date, startTime: "09:00", endTime: "11:00", room: "教学楼 A · 302", seatNumber: "17")
        return ExamWidgetContent(family: family, session: ExamSession(exam: exam, termID: "preview-term"),
                                 date: entry.date, appearance: appearance)
            .environment(\.widgetRenderingMode, family == .accessoryRectangular ? .vibrant : .fullColor)
            .padding(family == .accessoryRectangular ? 8 : 16)
            .frame(width: width, height: height, alignment: .leading)
            .background(DesignSystem.surface, in: .rect(cornerRadius: 16))
    }

    private var smartAgendaExamples: some View {
        let calendar = ScheduleRules.calendar
        let now = ScheduleRules.date(day: entry.date, time: "09:55") ?? entry.date
        let due = ScheduleRules.date(day: now, time: "11:30") ?? now
        let task = AgendaTask(id: "report", courseID: "physics", courseTitle: "物理实验", title: "交实验报告", due: due)
        let exam = Exam(courseTitle: "高等数学", date: now, startTime: "10:30", endTime: "12:30", room: "教学楼 A · 302", seatNumber: "17")
        let session = ExamSession(exam: exam, termID: "preview-term")
        let start = calendar.date(byAdding: .day, value: -365, to: now) ?? now
        let milestone = Milestone(title: "我们的恋爱日", date: start, direction: .countUp, category: .relationship, pinned: true)
        let medium = SmartAgenda.select(courses: entry.courses, exams: [], tasks: [task], milestones: [],
                                        now: now, leadMinutes: 10, options: .init(allowTasks: true))
        let examination = SmartAgenda.select(courses: entry.courses, exams: session.map { [$0] } ?? [], tasks: [], milestones: [],
                                             now: now, leadMinutes: 10, options: .init())
        let relationship = SmartAgenda.select(courses: [], exams: [], tasks: [], milestones: [milestone],
                                              now: now, leadMinutes: 10, options: .init(allowMilestones: true))
        return VStack(alignment: .leading, spacing: 12) {
            smartCard(.systemMedium, medium, width: 344, height: 144)
            smartCard(.systemSmall, examination, width: 158, height: 144)
            HStack(alignment: .top, spacing: 14) {
                smartCard(.accessoryRectangular, examination, width: 160, height: 66)
                smartCard(.accessoryCircular, relationship, width: 64, height: 64)
            }
        }
    }

    private func smartCard(_ family: WidgetFamily, _ selection: SmartAgendaSelection, width: CGFloat, height: CGFloat) -> some View {
        let isHome = family == .systemMedium || family == .systemSmall
        return SmartAgendaWidgetContent(family: family, selection: selection, appearance: appearance)
            .environment(\.widgetRenderingMode, isHome ? .fullColor : .vibrant)
            .padding(isHome ? 14 : 6)
            .frame(width: width, height: height, alignment: .leading)
            .background(DesignSystem.surface, in: .rect(cornerRadius: family == .accessoryCircular ? width / 2 : isHome ? 22 : 12))
    }
}
#endif
