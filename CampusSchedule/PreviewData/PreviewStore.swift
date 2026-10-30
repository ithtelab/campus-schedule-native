import Foundation
import Observation

struct DemoCourse: Identifiable {
    let id: String
    let title: String
    let room: String
    let teacher: String
    let weekday: Int
    let startPeriod: Int
    let endPeriod: Int
    let startTime: String
    let endTime: String
    let color: CourseColor
    var weeks: Set<Int> = Set(1...20)

    var shortRoom: String {
        room.replacingOccurrences(of: "教学楼 ", with: "")
            .replacingOccurrences(of: "实验楼 · ", with: "实验 ")
            .replacingOccurrences(of: "艺术楼 · ", with: "艺术 ")
            .replacingOccurrences(of: " · ", with: " ")
    }
}

struct DemoPeriod: Identifiable {
    let id: Int
    var start: String
    var end: String
}

/// 仅驱动 UI 演示；不代表持久化模型或学校数据协议。
@Observable
final class PreviewStore {
    var selectedWeek = 8
    var reminderPreview = true
    var reminderMinutes = 10
    var semesterName = "2026 秋季学期"
    var semesterStart = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 7))!
    var totalWeeks = 20
    var showsWeekend = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_WEEKEND"] == "1"
    var periods: [DemoPeriod] = [
        .init(id: 1, start: "08:00", end: "08:45"), .init(id: 2, start: "08:50", end: "09:35"),
        .init(id: 3, start: "10:00", end: "10:45"), .init(id: 4, start: "10:50", end: "11:35"),
        .init(id: 5, start: "14:00", end: "14:45"), .init(id: 6, start: "14:50", end: "15:35"),
        .init(id: 7, start: "16:00", end: "16:45"), .init(id: 8, start: "16:50", end: "17:35"),
        .init(id: 9, start: "19:00", end: "19:45"), .init(id: 10, start: "19:50", end: "20:35")
    ]

    var courses: [DemoCourse] = [
        .init(id: "math-mon", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 0, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "english-mon", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 0, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-mon", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 0, startPeriod: 7, endPeriod: 8, startTime: "16:00", endTime: "17:35", color: .orange),
        .init(id: "code-tue", title: "程序设计", room: "实验楼 · 502", teacher: "王老师", weekday: 1, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green),
        .init(id: "math-wed", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 2, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "sport-wed", title: "大学体育", room: "东区体育馆", teacher: "刘老师", weekday: 2, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .green),
        .init(id: "english-thu", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 3, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-fri", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 4, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .orange)
    ]

    var todayCourses: [DemoCourse] {
        courses(in: 8).filter { $0.weekday == 0 }.sorted { $0.startPeriod < $1.startPeriod }
    }

    func courses(in week: Int) -> [DemoCourse] {
        courses.filter { $0.weeks.contains(week) }
    }

    func date(week: Int, day: Int = 0) -> Date {
        Calendar.current.date(byAdding: .day, value: (week - 1) * 7 + day, to: semesterStart) ?? semesterStart
    }

    func refreshCourseTimes() {
        courses = courses.map { course in
            DemoCourse(id: course.id, title: course.title, room: course.room, teacher: course.teacher,
                       weekday: course.weekday, startPeriod: course.startPeriod, endPeriod: course.endPeriod,
                       startTime: periods[course.startPeriod - 1].start, endTime: periods[course.endPeriod - 1].end,
                       color: course.color, weeks: course.weeks)
        }
    }
}
