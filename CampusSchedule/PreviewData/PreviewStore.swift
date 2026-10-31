import Foundation
import Observation
import WidgetKit

struct DemoCourse: Identifiable, Codable {
    let id: String
    var sourceID: String? = nil
    var remindersEnabled = true
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

struct DemoPeriod: Identifiable, Codable {
    let id: Int
    var start: String
    var end: String
}

/// 本版展示独立演示课表；个人 SwiftData 文件保持隔离。云端验证可显式选择个人路径。
@MainActor @Observable
final class PreviewStore {
    var selectedWeek = 8
    var reminderPreview = true { didSet { save() } }
    var reminderMinutes = 10 { didSet { save() } }
    var semesterName = "2026 秋季学期" { didSet { save() } }
    var semesterStart = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 7))! { didSet { save() } }
    var totalWeeks = 20 { didSet { save() } }
    var showsWeekend = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_WEEKEND"] == "1"
    var periods: [DemoPeriod] = [
        .init(id: 1, start: "08:00", end: "08:45"), .init(id: 2, start: "08:50", end: "09:35"),
        .init(id: 3, start: "10:00", end: "10:45"), .init(id: 4, start: "10:50", end: "11:35"),
        .init(id: 5, start: "14:00", end: "14:45"), .init(id: 6, start: "14:50", end: "15:35"),
        .init(id: 7, start: "16:00", end: "16:45"), .init(id: 8, start: "16:50", end: "17:35"),
        .init(id: 9, start: "19:00", end: "19:45"), .init(id: 10, start: "19:50", end: "20:35")
    ] { didSet { save() } }

    var courses: [DemoCourse] = [
        .init(id: "math-mon", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 0, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "english-mon", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 0, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-mon", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 0, startPeriod: 7, endPeriod: 8, startTime: "16:00", endTime: "17:35", color: .orange),
        .init(id: "code-tue", title: "程序设计", room: "实验楼 · 502", teacher: "王老师", weekday: 1, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green),
        .init(id: "math-wed", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 2, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "sport-wed", title: "大学体育", room: "东区体育馆", teacher: "刘老师", weekday: 2, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .green),
        .init(id: "english-thu", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 3, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-fri", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 4, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .orange)
    ] { didSet { save() } }

    var isPreview: Bool { ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] != nil }
    var isDemoEdition: Bool {
        !isPreview && ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] == nil
            && ProcessInfo.processInfo.environment["CAMPUS_PERSONAL_DATA"] != "1"
            && Bundle.main.object(forInfoDictionaryKey: "CampusDemoEdition") as? Bool == true
    }
    var clockDate = Date()
    var timeText: String { time(now) }
    func time(_ date: Date) -> String { let f = DateFormatter(); f.timeZone = ScheduleRules.calendar.timeZone; f.dateFormat = "HH:mm"; return f.string(from: date) }
    var now: Date {
        if isPreview {
            let time = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TIME"] ?? "09:41"
            return ScheduleRules.date(day: date(week: 8), time: time) ?? ScheduleRules.date(day: date(week: 8), time: "09:41")!
        }
        return clockDate
    }
    var currentWeek: Int { ScheduleRules.week(on: now, semesterStart: semesterStart) }
    var todayCourses: [DemoCourse] {
        occurrences.filter { ScheduleRules.calendar.isDate($0.start, inSameDayAs: now) }.compactMap { occurrence in
            guard let base = courses.first(where: { $0.id == occurrence.courseID }) else { return nil }
            var copy = DemoCourse(id: occurrence.id, title: base.title, room: occurrence.room, teacher: base.teacher, weekday: base.weekday,
                startPeriod: base.startPeriod, endPeriod: base.endPeriod,
                startTime: time(occurrence.start), endTime: time(occurrence.end), color: base.color, weeks: base.weeks)
            copy.sourceID = base.id
            return copy
        }
    }
    var errorMessage: String?
    var liveEnabled = false { didSet { save() } }
    var endReminder = false { didSet { save() } }
    var endLead = 0 { didSet { save() } }
    var exceptions: [CourseException] = [] { didSet { save() } }
    @ObservationIgnored private var persistence: LocalPersistence?
    @ObservationIgnored private var ready = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    private struct Saved: Codable {
        var courses: [DemoCourse]; var periods: [DemoPeriod]; var semesterName: String; var semesterStart: Date
        var totalWeeks: Int; var reminders: Bool; var lead: Int; var endReminder: Bool; var endLead: Int
        var liveEnabled: Bool; var exceptions: [CourseException]
    }
    init() {
        if isDemoEdition {
            // Keep the sample term current without loading or replacing personal courses.
            let calendar = ScheduleRules.calendar
            let today = calendar.startOfDay(for: clockDate)
            let weekday = (calendar.component(.weekday, from: today) + 5) % 7
            semesterStart = calendar.date(byAdding: .day, value: -weekday - 49, to: today)!
            reminderPreview = false
            for day in [5, 6] {
                for source in Array(courses.prefix(3)) {
                    courses.append(.init(id: "sample-\(day)-\(source.id)", title: source.title, room: source.room,
                        teacher: source.teacher, weekday: day, startPeriod: source.startPeriod, endPeriod: source.endPeriod,
                        startTime: source.startTime, endTime: source.endTime, color: source.color))
                }
            }
        }
        if isPreview && ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_LAYOUT"] == "long" {
            courses[3] = .init(id: "layout-long", title: "大学英语视听说与学术交流", room: "第二教学楼北区 · 1205", teacher: "王老师", weekday: 1,
                startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green)
            courses.append(.init(id: "layout-single", title: "学术写作", room: "图书馆 · 201", teacher: "李老师", weekday: 6,
                startPeriod: 9, endPeriod: 9, startTime: "19:00", endTime: "19:45", color: .blue))
        }
        if isPreview {
            switch ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_LAYOUT"] {
            case "dense":
                courses.append(.init(id: "layout-afternoon", title: "线性代数", room: "教学楼 A · 206", teacher: "李老师", weekday: 0,
                    startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .blue))
                courses.append(.init(id: "layout-evening", title: "学术写作", room: "图书馆 · 201", teacher: "张老师", weekday: 0,
                    startPeriod: 9, endPeriod: 10, startTime: "19:00", endTime: "20:35", color: .blue))
            case "focus-long":
                courses[1] = .init(id: "layout-focus", title: "大学英语视听说与学术交流", room: "第二教学楼北区 · 1205", teacher: "林老师", weekday: 0,
                    startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple)
            case "empty": courses = []
            default: break
            }
        }
        if !isPreview && !isDemoEdition {
            courses = []; reminderPreview = false
            do {
                let storage = try LocalPersistence()
                if let data = try storage.load() {
                    let saved = try JSONDecoder().decode(Saved.self, from: data)
                    guard (1...53).contains(saved.totalWeeks), saved.periods.count == 10,
                          saved.courses.allSatisfy({ (0...6).contains($0.weekday) && (1...10).contains($0.startPeriod) && ($0.startPeriod...10).contains($0.endPeriod) }),
                          saved.periods.allSatisfy({ ScheduleRules.date(day: Date(), time: $0.start) != nil && ScheduleRules.date(day: Date(), time: $0.end) != nil }) else {
                        throw CocoaError(.coderReadCorrupt)
                    }
                    courses = saved.courses; periods = saved.periods; semesterName = saved.semesterName
                    semesterStart = saved.semesterStart; totalWeeks = saved.totalWeeks
                    reminderPreview = saved.reminders; reminderMinutes = saved.lead
                    endReminder = saved.endReminder; endLead = saved.endLead; liveEnabled = saved.liveEnabled; exceptions = saved.exceptions
                }
                persistence = storage
            } catch { errorMessage = "本地数据无法读取，未覆盖原有文件：\(error.localizedDescription)" }
        }
        selectedWeek = min(totalWeeks, max(1, currentWeek))
        ready = true
    }
    var occurrences: [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        for course in courses {
            for week in course.weeks where (1...totalWeeks).contains(week) {
                let day = date(week: week, day: course.weekday)
                let change = exceptions.last { $0.courseID == course.id && ScheduleRules.calendar.isDate($0.day, inSameDayAs: day) }
                if change?.cancelled == true { continue }
                guard let start = change?.start ?? ScheduleRules.date(day: day, time: course.startTime),
                      let end = change?.end ?? ScheduleRules.date(day: day, time: course.endTime), end > start else { continue }
                result.append(CourseOccurrence(id: course.id + ":" + String(Int(day.timeIntervalSince1970)), courseID: course.id,
                    title: course.title, room: change?.room ?? course.room, start: start, end: end))
                result[result.count - 1].remindersEnabled = course.remindersEnabled
            }
        }
        result = ScheduleRules.mergeContinuous(result)
        for index in result.indices where index + 1 < result.count {
            let next = result[index + 1]
            if ScheduleRules.calendar.isDate(result[index].start, inSameDayAs: next.start) {
                result[index].nextTitle = next.title; result[index].nextRoom = next.room
            }
        }
        return result
    }
    func save() {
        if ready && isDemoEdition { synchronize(); return }
        guard ready, !isPreview, let persistence else { return }
        do {
            let data = Saved(courses: courses, periods: periods, semesterName: semesterName, semesterStart: semesterStart,
                totalWeeks: totalWeeks, reminders: reminderPreview, lead: reminderMinutes, endReminder: endReminder,
                endLead: endLead, liveEnabled: liveEnabled, exceptions: exceptions)
            try persistence.save(JSONEncoder().encode(data))
            synchronize()
        } catch { errorMessage = "保存失败：\(error.localizedDescription)" }
    }
    func synchronize() {
        guard !isPreview else { return }
        syncTask?.cancel()
        let items = occurrences
        syncTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                try SystemSnapshot.write(items)
                WidgetCenter.shared.reloadAllTimelines()
                try await CourseNotifications.shared.replace(courses: items, enabled: reminderPreview, lead: reminderMinutes, endEnabled: endReminder, endLead: endLead)
                await CourseLiveActivities.shared.reconcile(items: items, enabled: liveEnabled, lead: reminderMinutes)
            } catch is CancellationError {} catch { errorMessage = error.localizedDescription }
        }
    }

    func courses(in week: Int) -> [DemoCourse] {
        occurrences.filter { ScheduleRules.week(on: $0.start, semesterStart: semesterStart) == week }.compactMap { item in
            guard let base = courses.first(where: { $0.id == item.courseID }) else { return nil }
            var copy = DemoCourse(id: item.id, title: base.title, room: item.room, teacher: base.teacher,
                weekday: (ScheduleRules.calendar.component(.weekday, from: item.start) + 5) % 7,
                startPeriod: base.startPeriod, endPeriod: base.endPeriod, startTime: time(item.start), endTime: time(item.end), color: base.color, weeks: base.weeks)
            copy.sourceID = base.id
            return copy
        }
    }

    func date(week: Int, day: Int = 0) -> Date {
        ScheduleRules.calendar.date(byAdding: .day, value: (week - 1) * 7 + day, to: semesterStart) ?? semesterStart
    }

    func refreshCourseTimes() {
        // 节次编号可能不连续，按编号查找而不是用下标。
        let byIndex = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
        courses = courses.map { course in
            guard let start = byIndex[course.startPeriod], let end = byIndex[course.endPeriod] else { return course }
            var updated = DemoCourse(id: course.id, title: course.title, room: course.room, teacher: course.teacher,
                       weekday: course.weekday, startPeriod: course.startPeriod, endPeriod: course.endPeriod,
                       startTime: start.start, endTime: end.end,
                       color: course.color, weeks: course.weeks)
            updated.remindersEnabled = course.remindersEnabled
            return updated
        }
    }

    // MARK: - 导出与恢复

    /// 当前学期标识。内部模型还不支持多学期，先用固定值，格式层面已经预留数组。
    static let currentSemesterID = "term-current"

    /// 把当前全部个人数据导出为可存档的格式。演示版与截图模式不产出真实数据。
    func makeArchive(exportedAt: Date = Date()) throws -> ScheduleArchive {
        guard !isDemoEdition, !isPreview else { throw ArchiveError.emptySemesterList }
        let semesters = [ArchivedSemester(
            id: Self.currentSemesterID,
            name: semesterName,
            startDate: semesterStart,
            totalWeeks: totalWeeks,
            periods: periods.map { ArchivedPeriod(index: $0.id, start: $0.start, end: $0.end) },
            courses: courses.map { course in
                ArchivedCourse(id: course.id, sourceID: course.sourceID, title: course.title, room: course.room,
                               teacher: course.teacher, weekday: course.weekday, startPeriod: course.startPeriod,
                               endPeriod: course.endPeriod, color: course.color.rawValue,
                               weeks: course.weeks.sorted(), remindersEnabled: course.remindersEnabled)
            },
            exceptions: exceptions.map { change in
                ArchivedException(id: change.id.uuidString, courseID: change.courseID, day: change.day,
                                  cancelled: change.cancelled, start: change.start, end: change.end, room: change.room)
            }
        )]
        return try ScheduleArchive(exportedAt: exportedAt, appVersion: Self.appVersion, semesters: semesters).validated()
    }

    static var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// 导入前的预检：只解析和校验，不写入任何状态，便于先向用户确认。
    nonisolated static func inspectArchive(_ data: Data) throws -> ScheduleArchive {
        try ScheduleArchive.decoded(from: data)
    }

    /// 用备份替换当前学期。调用方必须已经让用户确认；成功后立即保存并同步系统状态。
    func restore(from archive: ScheduleArchive, now: Date = Date()) throws {
        let validated = try archive.validated()
        guard let term = validated.semesters.first else { throw ArchiveError.emptySemesterList }

        let restoredPeriods = term.periods.sorted { $0.index < $1.index }
            .map { DemoPeriod(id: $0.index, start: $0.start, end: $0.end) }
        // 节次编号不保证从 1 连续，用编号查时间而不是用数组下标。
        let periodTimes = Dictionary(uniqueKeysWithValues: restoredPeriods.map { ($0.id, $0) })
        let restoredCourses = term.courses.compactMap { archived -> DemoCourse? in
            guard let start = periodTimes[archived.startPeriod],
                  let end = periodTimes[archived.endPeriod],
                  let color = CourseColor(rawValue: archived.color) ?? Optional(.blue) else { return nil }
            var course = DemoCourse(id: archived.id, title: archived.title, room: archived.room,
                                    teacher: archived.teacher, weekday: archived.weekday,
                                    startPeriod: archived.startPeriod, endPeriod: archived.endPeriod,
                                    startTime: start.start, endTime: end.end,
                                    color: color, weeks: Set(archived.weeks))
            course.sourceID = archived.sourceID
            course.remindersEnabled = archived.remindersEnabled
            return course
        }
        let restoredExceptions = term.exceptions.map { change in
            CourseException(id: UUID(uuidString: change.id) ?? UUID(), courseID: change.courseID,
                            day: change.day, cancelled: change.cancelled,
                            start: change.start, end: change.end, room: change.room)
        }

        guard restoredCourses.count == term.courses.count else {
            throw ArchiveError.courseOutsidePeriodRange(term.name, term.name)
        }
        // 学期设置页假设恰好 10 节且编号 1…10；备份允许任意编号，这里拒绝会让设置页越界的数据。
        guard restoredPeriods.map(\.id) == Array(1...restoredPeriods.count), restoredPeriods.count == 10 else {
            throw ArchiveError.emptyPeriods(term.name)
        }

        semesterName = term.name
        semesterStart = term.startDate
        totalWeeks = term.totalWeeks
        periods = restoredPeriods
        courses = restoredCourses
        exceptions = restoredExceptions
        selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        errorMessage = nil
        save()
    }
}
