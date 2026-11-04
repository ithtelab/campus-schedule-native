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
    /// 该次安排被调课过（时间或地点与课程原定不同）。
    var wasRescheduled = false
    /// 原定教室，仅在调课换教室时有值。
    var originalRoom: String?
    /// 周次规律，用于课表角标。
    var weekPattern: WeekPattern = .everyWeek
    var shortRoom: String { Self.shorten(room) }

    /// 教室名的缩写规则。与状态条共用 `NowStatus.shorten`，只保留一个实现。
    static func shorten(_ room: String) -> String { NowStatus.shorten(room) }

    func replacingTimes(start: String, end: String) -> DemoCourse {
        var result = DemoCourse(id: id, title: title, room: room, teacher: teacher,
            weekday: weekday, startPeriod: startPeriod, endPeriod: endPeriod,
            startTime: start, endTime: end, color: color, weeks: weeks)
        result.sourceID = sourceID; result.remindersEnabled = remindersEnabled
        result.wasRescheduled = wasRescheduled; result.originalRoom = originalRoom; result.weekPattern = weekPattern
        return result
    }
}

struct DemoPeriod: Identifiable, Codable, Equatable {
    let id: Int
    var start: String
    var end: String
}

/// 本机课表及用户设置。模拟器的界面验收使用独立内存数据。
@MainActor @Observable
final class PreviewStore {
    var selectedWeek = 8
    var reminderPreview = true { didSet { save() } }
    var reminderMinutes = 10 { didSet { save() } }
    var showsWeekend = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_WEEKEND"] == "1"

    /// 单个学期的全部内容。多学期共用一个容器，靠 `activeTermID` 切换。
    struct TermContent: Codable {
        var name: String
        var startDate: Date
        var totalWeeks: Int
        var periods: [DemoPeriod]
        var courses: [DemoCourse]
        var exceptions: [CourseException] = []
        var exams: [Exam] = []

        enum CodingKeys: String, CodingKey { case name, startDate, totalWeeks, periods, courses, exceptions, exams }

        init(name: String, startDate: Date, totalWeeks: Int, periods: [DemoPeriod],
             courses: [DemoCourse], exceptions: [CourseException] = [], exams: [Exam] = []) {
            self.name = name
            self.startDate = startDate
            self.totalWeeks = totalWeeks
            self.periods = periods
            self.courses = courses
            self.exceptions = exceptions
            self.exams = exams
        }

        // 考试字段是后加的，旧数据没有它，缺省为空以避免迁移失败。
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            startDate = try container.decode(Date.self, forKey: .startDate)
            totalWeeks = try container.decode(Int.self, forKey: .totalWeeks)
            periods = try container.decode([DemoPeriod].self, forKey: .periods)
            courses = try container.decode([DemoCourse].self, forKey: .courses)
            exceptions = try container.decodeIfPresent([CourseException].self, forKey: .exceptions) ?? []
            exams = try container.decodeIfPresent([Exam].self, forKey: .exams) ?? []
        }
    }

    /// 所有学期的内容，键是学期标识。
    var termContents: [String: TermContent] = [:] { didSet { save() } }
    /// 当前正在查看的学期。
    var activeTermID = "" { didSet { guard activeTermID != oldValue else { return }; save() } }

    /// 学期列表，按开学日期从新到旧。
    var terms: [TermSummary] {
        TermSelection.sorted(termContents.map { TermSummary(id: $0.key, name: $0.value.name,
                                                            startDate: $0.value.startDate,
                                                            totalWeeks: $0.value.totalWeeks) })
    }

    private var activeContent: TermContent? { termContents[activeTermID] }

    /// 写入活动学期后统一保存，避免每个字段各写一次。
    private func mutateActive(_ change: (inout TermContent) -> Void) {
        guard !storageReadOnly else { errorMessage = storageIssue; return }
        guard var content = termContents[activeTermID] else { return }
        change(&content)
        termContents[activeTermID] = content
    }

    // MARK: 活动学期字段（保持既有调用方式）

    var semesterName: String {
        get { activeContent?.name ?? "" }
        set { mutateActive { $0.name = newValue } }
    }
    var semesterStart: Date {
        get { activeContent?.startDate ?? ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))! }
        set { mutateActive { $0.startDate = newValue } }
    }
    var totalWeeks: Int {
        get { activeContent?.totalWeeks ?? 20 }
        set { mutateActive { $0.totalWeeks = newValue } }
    }
    var periods: [DemoPeriod] {
        get { activeContent?.periods ?? PreviewStore.defaultPeriods }
        set { mutateActive { $0.periods = newValue } }
    }
    var courses: [DemoCourse] {
        get { activeContent?.courses ?? [] }
        set { mutateActive { $0.courses = newValue } }
    }
    var exceptions: [CourseException] {
        get { activeContent?.exceptions ?? [] }
        set { mutateActive { $0.exceptions = newValue } }
    }
    var exams: [Exam] {
        get { activeContent?.exams ?? [] }
        set { mutateActive { $0.exams = newValue } }
    }

    /// 当前学期即将到来的考试。
    var upcomingExams: [Exam] { ExamPlan.upcoming(exams.filter { $0.id != "" }, now: now) }

    static let defaultPeriods: [DemoPeriod] = [
        .init(id: 1, start: "08:00", end: "08:45"), .init(id: 2, start: "08:50", end: "09:35"),
        .init(id: 3, start: "10:00", end: "10:45"), .init(id: 4, start: "10:50", end: "11:35"),
        .init(id: 5, start: "14:00", end: "14:45"), .init(id: 6, start: "14:50", end: "15:35"),
        .init(id: 7, start: "16:00", end: "16:45"), .init(id: 8, start: "16:50", end: "17:35"),
        .init(id: 9, start: "19:00", end: "19:45"), .init(id: 10, start: "19:50", end: "20:35")
    ]

    #if targetEnvironment(simulator)
    private static let sampleCourses: [DemoCourse] = [
        .init(id: "math-mon", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 0, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "english-mon", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 0, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-mon", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 0, startPeriod: 7, endPeriod: 8, startTime: "16:00", endTime: "17:35", color: .orange),
        .init(id: "code-tue", title: "程序设计", room: "实验楼 · 502", teacher: "王老师", weekday: 1, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green),
        .init(id: "math-wed", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 2, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "sport-wed", title: "大学体育", room: "东区体育馆", teacher: "刘老师", weekday: 2, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .green),
        .init(id: "english-thu", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 3, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-fri", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 4, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .orange)
    ]

    #endif

    private let testingInMemory: Bool
    var isPreview: Bool {
        #if targetEnvironment(simulator)
        testingInMemory || ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] != nil
        #else
        false
        #endif
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
            copy.wasRescheduled = occurrence.wasRescheduled
            copy.originalRoom = occurrence.originalRoom
            copy.weekPattern = occurrence.weekPattern
            return copy
        }
    }
    var errorMessage: String?
    private(set) var storageIssue: String?
    var storageReadOnly: Bool { storageIssue != nil }
    @ObservationIgnored private var originalRecoveryData: Data?
    @ObservationIgnored private var batchDepth = 0
    var liveEnabled = false { didSet { save() } }
    var endReminder = false { didSet { save() } }
    var endLead = 0 { didSet { save() } }

    /// 纪念事件。跨学期保留，不随切换学期消失。
    var milestones: [Milestone] = [] { didSet { save() } }

    /// 外观偏好。人物、主题、装饰密度与互动效果与课程数据分开保存，
    /// 切换身份或学期都不会重置。
    var appearance = AppearancePreferences() { didSet { guard appearance != oldValue else { return }; save() } }

    /// 当前形象对应的角色资源。尚未绘制完成的形象退回默认角色，
    /// 但保留用户的选择，等资源补齐后自动生效。
    var characterStyle: CampusCharacterStyle {
        switch appearance.persona {
        case .boy: .boy
        case .girl, .teacher, .cat: .girl
        }
    }

    /// 是否显示人物。关闭装饰后界面必须仍然完整可用。
    var showsCharacter: Bool { appearance.density.showsCharacter }

    /// 按今日页的展示顺序排好的纪念事件，已归档的排在最后。
    var sortedMilestones: [Milestone] { MilestoneCounter.sorted(milestones, now: now) }

    /// 今日页只展示置顶且未归档的事件，最多三条，避免挤占课程信息。
    var pinnedMilestones: [Milestone] {
        sortedMilestones.filter { $0.pinned && !MilestoneCounter.read($0, now: now).isHidden(expiry: $0.expiry) }
            .prefix(3).map { $0 }
    }

    /// 用户是否开启了 iCloud 同步。默认关闭，与产品约定一致。
    var cloudSyncEnabled = false {
        didSet {
            guard cloudSyncEnabled != oldValue, !adjustingCloudToggle else { return }
            if cloudSyncEnabled {
                if !beginCloudSync() {
                    adjustingCloudToggle = true; cloudSyncEnabled = false; adjustingCloudToggle = false
                }
            } else { stopCloudSync() }
            save()
        }
    }
    @ObservationIgnored private var adjustingCloudToggle = false
    /// 同步状态文案，设置在界面展示。
    private(set) var cloudSyncStatus: String?
    /// 云端与本地都改过时挂起，等待用户选择。
    private(set) var pendingCloudConflict: StampedPayload?
    @ObservationIgnored private var cloudSync = CloudSync.shared
    @ObservationIgnored private var cloudPushTask: Task<Void, Never>?
    @ObservationIgnored private var restoreCloudSync = false
    @ObservationIgnored private var persistence: LocalPersistence?
    @ObservationIgnored private var ready = false
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    private struct Saved: Codable {
        var activeTermID: String
        var terms: [String: TermContent]
        var reminders: Bool; var lead: Int; var endReminder: Bool; var endLead: Int
        var liveEnabled: Bool
        var cloudSyncEnabled: Bool?
        /// 纪念事件跨学期保留，因此存在顶层而不是学期容器里。
        var milestones: [Milestone] = []
        /// 外观偏好。旧文件没有这个键，缺省即可。
        var appearance: AppearancePreferences?

        init(activeTermID: String, terms: [String: TermContent], reminders: Bool, lead: Int,
             endReminder: Bool, endLead: Int, liveEnabled: Bool,
             cloudSyncEnabled: Bool?, milestones: [Milestone] = [],
             appearance: AppearancePreferences? = nil) {
            self.activeTermID = activeTermID
            self.terms = terms
            self.reminders = reminders
            self.lead = lead
            self.endReminder = endReminder
            self.endLead = endLead
            self.liveEnabled = liveEnabled
            self.cloudSyncEnabled = cloudSyncEnabled
            self.milestones = milestones
            self.appearance = appearance
        }

        // 纪念事件、外观偏好与备课状态都是后加的字段，旧文件没有它们。
        enum CodingKeys: String, CodingKey {
            case activeTermID, terms, reminders, lead, endReminder, endLead, liveEnabled,
                 cloudSyncEnabled, milestones, appearance
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            activeTermID = try container.decode(String.self, forKey: .activeTermID)
            terms = try container.decode([String: TermContent].self, forKey: .terms)
            reminders = try container.decode(Bool.self, forKey: .reminders)
            lead = try container.decode(Int.self, forKey: .lead)
            endReminder = try container.decode(Bool.self, forKey: .endReminder)
            endLead = try container.decode(Int.self, forKey: .endLead)
            liveEnabled = try container.decode(Bool.self, forKey: .liveEnabled)
            cloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled)
            milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
            appearance = try container.decodeIfPresent(AppearancePreferences.self, forKey: .appearance)
        }
    }

    /// 单学期时代的存储结构。仅用于把旧文件迁移到多学期容器，不参与新写入。
    private struct LegacySaved: Codable {
        var courses: [DemoCourse]; var periods: [DemoPeriod]; var semesterName: String; var semesterStart: Date
        var totalWeeks: Int; var reminders: Bool; var lead: Int; var endReminder: Bool; var endLead: Int
        var liveEnabled: Bool; var exceptions: [CourseException]
        var cloudSyncEnabled: Bool?
    }

    init(testingInMemory: Bool = false, recoveryTestData: Data? = nil) {
        self.testingInMemory = testingInMemory
        // 先建立活动学期，之后的字段读写都落到这个容器里。
        var initialID = "term-" + UUID().uuidString
        let calendar = ScheduleRules.calendar
        let today = calendar.startOfDay(for: clockDate)
        let daysFromMonday = (calendar.component(.weekday, from: today) + 5) % 7
        var initialTerm = TermContent(
            name: "我的学期",
            startDate: calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today,
            totalWeeks: 20,
            periods: Self.defaultPeriods,
            courses: [],
            exceptions: []
        )
        #if targetEnvironment(simulator)
        if isPreview {
            initialID = "preview-term"
            initialTerm.name = "2026 秋季学期"
            initialTerm.startDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!
            initialTerm.courses = Self.sampleCourses
        }
        #endif
        termContents[initialID] = initialTerm
        activeTermID = initialID

        #if targetEnvironment(simulator)
        if isPreview && ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_LAYOUT"] == "long" {
            courses[3] = .init(id: "layout-long", title: "大学英语视听说与学术交流", room: "第二教学楼北区 · 1205", teacher: "王老师", weekday: 1,
                startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green)
            courses.append(.init(id: "layout-single", title: "学术写作", room: "图书馆 · 201", teacher: "李老师", weekday: 6,
                startPeriod: 9, endPeriod: 9, startTime: "19:00", endTime: "19:45", color: .blue))
        }
        // 今日页与考试页都需要示范考试，才能验证倒计时条的排版。
        if isPreview && (ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "exams"
                         || ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_EXAMS"] == "1") {
            // 截图专用示范数据，让考试页展示真实排版而不是空状态。
            let calendar = ScheduleRules.calendar
            let base = calendar.startOfDay(for: clockDate)
            let offsets = [3, 8, 15]
            let samples = [("高等数学", "09:00", "11:00", "A302", "17"),
                           ("大学英语", "14:00", "16:00", "B205", "08"),
                           ("程序设计", "19:00", "21:00", "实验楼502", "")]
            var seeded: [Exam] = []
            for (index, offset) in offsets.enumerated() {
                let sample = samples[index]
                let day = calendar.date(byAdding: .day, value: offset, to: base) ?? base
                seeded.append(Exam(courseTitle: sample.0, date: day, startTime: sample.1,
                                   endTime: sample.2, room: sample.3, seatNumber: sample.4))
            }
            exams = seeded
        }
        if isPreview {
            // 截图用：构造单双周课程与一次调课，验证角标与提示。
            if ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_LAYOUT"] == "changes" {
                courses[1].weeks = Set(stride(from: 1, through: 20, by: 2))   // 单周
                courses[5].weeks = Set(stride(from: 2, through: 20, by: 2))   // 双周
                let day = date(week: 8, day: courses[3].weekday)
                exceptions = [CourseException(courseID: courses[3].id, day: day,
                                              cancelled: false, start: nil, end: nil,
                                              room: "实验楼 · 605")]
            }
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
        #endif
        if !isPreview {
            do {
                let storage = try LocalPersistence()
                persistence = storage
                if let data = try storage.load() {
                    if !loadSaved(data) {
                        originalRecoveryData = data
                        storageIssue = errorMessage ?? "本地数据读取失败，已保护原始数据。"
                        termContents = [:]
                    }
                } else {
                    // 全新安装：保留空学期，等待用户添加课程。
                    courses = []; reminderPreview = false
                }
                if termContents.isEmpty { courses = [] }
                if activeContent == nil { courses = [] }
            } catch {
                originalRecoveryData = try? persistence?.recoveryData()
                storageIssue = "本地数据无法读取，已保护原始数据：\(error.localizedDescription)"
                errorMessage = storageIssue
                termContents = [:]
            }
        }
        if testingInMemory, let recoveryTestData, !loadSaved(recoveryTestData) {
            originalRecoveryData = recoveryTestData
            storageIssue = errorMessage ?? "原始数据无法读取。"
            termContents = [:]
        }
        selectedWeek = min(totalWeeks, max(1, currentWeek))
        ready = true
        // 存储已就绪，此时再开启同步才能读到本地内容；直接在这里赋值会绕过持久化准备。
        if restoreCloudSync { cloudSyncEnabled = true; restoreCloudSync = false }
    }

    /// 读取存储内容，优先多学期格式，失败后尝试单学期旧格式迁移。
    private func loadSaved(_ data: Data) -> Bool {
        let decoder = JSONDecoder()
        if let saved = try? decoder.decode(Saved.self, from: data) {
            guard !saved.terms.isEmpty else { errorMessage = "本地数据中没有学期。"; return false }
            guard saved.terms.allSatisfy({ _, content in Self.isValid(content) }) else {
                errorMessage = "本地数据校验未通过，未覆盖原有文件。"; return false
            }
            termContents = saved.terms
            activeTermID = saved.terms[saved.activeTermID] != nil ? saved.activeTermID : (saved.terms.keys.sorted().first ?? "")
            reminderPreview = saved.reminders; reminderMinutes = saved.lead
            endReminder = saved.endReminder; endLead = saved.endLead; liveEnabled = saved.liveEnabled
            milestones = saved.milestones
            appearance = saved.appearance ?? AppearancePreferences()
            restoreCloudSync = saved.cloudSyncEnabled == true
            return true
        }
        guard let legacy = try? decoder.decode(LegacySaved.self, from: data) else {
            errorMessage = "本地数据无法读取，未覆盖原有文件。"
            return false
        }
        let content = TermContent(name: legacy.semesterName, startDate: legacy.semesterStart,
                                  totalWeeks: legacy.totalWeeks, periods: legacy.periods,
                                  courses: legacy.courses, exceptions: legacy.exceptions)
        guard Self.isValid(content) else {
            errorMessage = "本地数据校验未通过，未覆盖原有文件。"; return false
        }
        let migratedID = "term-migrated"
        termContents = [migratedID: content]
        activeTermID = migratedID
        reminderPreview = legacy.reminders; reminderMinutes = legacy.lead
        endReminder = legacy.endReminder; endLead = legacy.endLead; liveEnabled = legacy.liveEnabled
        restoreCloudSync = legacy.cloudSyncEnabled == true
        return true
    }

    /// 学期内容的完整性检查。
    ///
    /// 节次数允许 1…20：各校作息差异很大（有 8 节、有 14 节），早期版本固定 10 节
    /// 会让非 10 节的学校无法录入。编号必须从 1 连续，网格按下标定位。
    static let supportedPeriodRange = 1...20

    static func isValid(_ content: TermContent) -> Bool {
        guard (1...53).contains(content.totalWeeks),
              supportedPeriodRange.contains(content.periods.count) else { return false }
        guard content.periods.map(\.id) == Array(1...content.periods.count) else { return false }
        for (index, period) in content.periods.enumerated() {
            guard ScheduleArchive.isClockTime(period.start), ScheduleArchive.isClockTime(period.end),
                  period.start < period.end,
                  index == 0 || content.periods[index - 1].end <= period.start else { return false }
        }
        let indices = Set(content.periods.map(\.id))
        let courseIDs = Set(content.courses.map(\.id))
        guard courseIDs.count == content.courses.count,
              content.courses.allSatisfy({ course in
            (0...6).contains(course.weekday) && indices.contains(course.startPeriod)
                && indices.contains(course.endPeriod) && course.endPeriod >= course.startPeriod
                && !course.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !course.weeks.isEmpty && course.weeks.allSatisfy { (1...content.totalWeeks).contains($0) }
        }) else { return false }
        return content.exceptions.allSatisfy { courseIDs.contains($0.courseID) }
            && Set(content.exams.map(\.id)).count == content.exams.count
            && content.exams.allSatisfy { ExamPlan.validate($0) == .valid }
    }

    func academicChangesRemovingCourses(periodCount: Int, weeks: Int) -> [String] {
        courses.filter { $0.startPeriod < 1 || $0.endPeriod > periodCount
            || $0.weeks.filter { (1...max(1, weeks)).contains($0) }.isEmpty }.map(\.title)
    }

    @discardableResult
    func applyAcademicSettings(termID: String, name: String, start: Date, weeks: Int, periods: [DemoPeriod]) -> Bool {
        guard !storageReadOnly, termID == activeTermID, var content = termContents[termID] else {
            errorMessage = storageIssue ?? "当前学期已切换，请重新打开学期设置。"; return false
        }
        let day = ScheduleRules.calendar.startOfDay(for: start)
        guard ScheduleRules.calendar.component(.weekday, from: day) == 2 else { return false }
        let offset = ScheduleRules.calendar.dateComponents([.day], from: content.startDate, to: day).day ?? 0
        let adjusted = ArchiveMapping.adjustCourses(content.courses, totalWeeks: weeks, periodCount: periods.count,
            periodsOf: { ($0.startPeriod, $0.endPeriod) }, weeksOf: { $0.weeks },
            apply: { course, weeks in var result = course; result.weeks = weeks; return result })
        let times = Dictionary(grouping: periods, by: \.id)
        guard times.values.allSatisfy({ $0.count == 1 }) else { return false }
        content.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        content.startDate = day; content.totalWeeks = weeks; content.periods = periods
        content.courses = adjusted.kept.map { course in
            course.replacingTimes(start: times[course.startPeriod]?.first?.start ?? course.startTime,
                                  end: times[course.endPeriod]?.first?.end ?? course.endTime)
        }
        let kept = Set(content.courses.map(\.id))
        content.exceptions = content.exceptions.filter { kept.contains($0.courseID) }.map { ArchiveMapping.shifted($0, days: offset) }
        guard !content.name.isEmpty, Self.isValid(content) else { errorMessage = "学期或作息数据不合法，未保存。"; return false }
        do { try backupBeforeReplacing() }
        catch { errorMessage = "无法保留修改前的副本，未保存：\(error.localizedDescription)"; return false }
        let saved = commitBatch {
            termContents[termID] = content
            selectedWeek = min(weeks, max(1, selectedWeek))
        }
        if saved { errorMessage = nil }
        return saved
    }
    var occurrences: [CourseOccurrence] {
        var result: [CourseOccurrence] = []
        for course in courses {
            let pattern = WeekPattern.infer(from: course.weeks, totalWeeks: totalWeeks)
            for week in course.weeks where (1...totalWeeks).contains(week) {
                let day = date(week: week, day: course.weekday)
                let change = exceptions.last { $0.courseID == course.id && ScheduleRules.calendar.isDate($0.day, inSameDayAs: day) }
                // 停课不在课表里占位：学生看到的应当是没有这节课，而不是一条划掉的记录。
                // 需要回顾停课的话，课程详情里仍可查到。
                if change?.cancelled == true { continue }
                guard let start = change?.start ?? ScheduleRules.date(day: day, time: course.startTime),
                      let end = change?.end ?? ScheduleRules.date(day: day, time: course.endTime), end > start else { continue }
                var occurrence = CourseOccurrence(
                    id: course.id + ":" + String(Int(day.timeIntervalSince1970)),
                    courseID: course.id, title: course.title,
                    room: change?.room ?? course.room, teacher: course.teacher,
                    start: start, end: end)
                occurrence.remindersEnabled = course.remindersEnabled
                occurrence.weekPattern = pattern
                // 与原定时间或地点不同即为调课，界面据此提示。
                if let change, change.room != nil || change.start != nil || change.end != nil {
                    occurrence.wasRescheduled = true
                    if let newRoom = change.room, newRoom != course.room {
                        occurrence.originalRoom = course.room
                    }
                }
                result.append(occurrence)
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
    @discardableResult
    func save() -> Bool {
        guard batchDepth == 0 else { return true }
        guard !storageReadOnly else { errorMessage = storageIssue; return false }
        guard ready else { return true }
        if isPreview { return true }
        guard let persistence else { return false }
        guard !termContents.isEmpty, termContents[activeTermID] != nil,
              termContents.values.allSatisfy({ Self.isValid($0) }) else {
            errorMessage = "课表数据未通过校验，原始存储未改写。"; return false
        }
        do {
            let data = Saved(activeTermID: activeTermID, terms: termContents,
                reminders: reminderPreview, lead: reminderMinutes, endReminder: endReminder,
                endLead: endLead, liveEnabled: liveEnabled, cloudSyncEnabled: cloudSyncEnabled,
                milestones: milestones, appearance: appearance)
            let encoded = try JSONEncoder().encode(data)
            try persistence.save(encoded)
            synchronize()
            // 云端统一使用归档格式：它有版本号与校验，恢复路径也复用它。
            if cloudSyncEnabled, hasCloudContent, let archive = try? makeArchive().encoded() {
                scheduleCloudPush(archive)
            }
            return true
        } catch { errorMessage = "保存失败：\(error.localizedDescription)"; return false }
    }

    /// 多字段编辑只落盘一次；失败时恢复内存中的原学期与设置。
    @discardableResult
    private func commitBatch(_ changes: () -> Void) -> Bool {
        let oldTerms = termContents, oldActive = activeTermID, oldWeek = selectedWeek
        let oldMilestones = milestones, oldAppearance = appearance
        batchDepth += 1
        changes()
        batchDepth -= 1
        if save() { return true }
        batchDepth += 1
        termContents = oldTerms; activeTermID = oldActive; selectedWeek = oldWeek
        milestones = oldMilestones
        appearance = oldAppearance
        batchDepth -= 1
        return false
    }

    func recoveryDataForExport() throws -> Data {
        if let originalRecoveryData { return originalRecoveryData }
        if let data = try persistence?.recoveryData() { return data }
        throw CocoaError(.fileReadNoSuchFile)
    }

    private func backupBeforeReplacing() throws {
        guard !isPreview else { return }
        // 正常数据保留为可再次导入的标准备份；损坏数据保留原始载荷。
        let archive: Data? = storageReadOnly ? nil : (try? makeArchive().encoded())
        try persistence?.backupCurrent(archive: archive)
    }

    func previousBackupForExport() throws -> Data {
        guard let persistence else { throw CocoaError(.fileReadNoSuchFile) }
        return try persistence.latestArchiveBackup()
    }

    // MARK: - iCloud 同步

    func refreshCloudSync() {
        guard cloudSyncEnabled else { return }
        _ = beginCloudSync()
    }

    func removeCloudCopy() {
        guard cloudSyncEnabled, !storageReadOnly else { return }
        cloudPushTask?.cancel()
        do {
            try cloudSync.removeCloudCopy()
            cloudSyncEnabled = false
            cloudSyncStatus = "已向 iCloud 请求删除副本，本机课表已保留。"
        } catch { cloudSyncStatus = error.localizedDescription }
    }

    /// 初次启用时，空的默认学期不应覆盖 iCloud 中的课表。
    private var hasCloudContent: Bool {
        cloudSync.lastSyncedPayloadForComparison != nil || !milestones.isEmpty || termContents.count > 1
            || termContents.values.contains {
                $0.name != "我的学期" || !$0.courses.isEmpty || !$0.exams.isEmpty || !$0.exceptions.isEmpty
                    || $0.periods != Self.defaultPeriods || $0.totalWeeks != 20
            }
    }

    private func beginCloudSync() -> Bool {
        guard !storageReadOnly else { cloudSyncStatus = storageIssue; return false }
        guard !isPreview else { return false }
        cloudSync.startObserving { [weak self] payload in self?.handleRemoteChange(payload) }
        do {
            try cloudSync.requestSync()
            guard !cloudSync.remoteIsCorrupt else { throw CloudSyncError.decodeFailed }
            // 云端只存归档格式：它有版本号与校验，恢复路径也复用它。
            // 比较必须用同一种格式，否则「本地未改动」永远判不出来。
            let localData = hasCloudContent ? try makeArchive().encoded() : nil
            switch cloudSync.decision(local: localData) {
            case .idle:
                cloudSyncStatus = localData == nil ? "正在检查 iCloud 中是否有课表。" : "已是最新。"
            case .pushLocal:
                if let localData { try cloudSync.push(localData) }
                cloudSyncStatus = "已交给 iCloud 同步，其他设备更新可能稍有延迟。"
            case .applyRemote:
                guard let remote = cloudSync.remote(), let term = try? ScheduleArchive.decoded(from: remote.payload) else {
                    throw CloudSyncError.decodeFailed
                }
                try restore(from: term)
                cloudSync.markSynced(remote.payload)
                cloudSyncStatus = "已采用 iCloud 中的课表。"
            case .conflict:
                pendingCloudConflict = cloudSync.remote()
                cloudSyncStatus = "iCloud 与本机都有改动，需要你选择保留哪一份。"
            }
        } catch {
            cloudSync.stopObserving()
            cloudSyncStatus = error.localizedDescription
            return false
        }
        return true
    }

    private func stopCloudSync() {
        cloudPushTask?.cancel()
        cloudSync.stopObserving()
        cloudSync.resetSyncState()
        pendingCloudConflict = nil
        cloudSyncStatus = "已关闭同步。"
    }

    /// 远端变化：本地没改过就直接采用，改过则挂起等用户决定。
    private func handleRemoteChange(_ payload: StampedPayload) {
        guard cloudSyncEnabled, !storageReadOnly, payload.deviceID != cloudSync.deviceID else { return }
        guard !payload.payload.isEmpty else { cloudSyncStatus = "iCloud 同步空间不足，课表已保留在本机。"; return }
        guard let localData = try? makeArchive().encoded() else {
            cloudSyncStatus = "本机课表尚未通过校验，未应用云端内容。"; return
        }
        switch CloudSyncPlan.decide(
            local: hasCloudContent ? StampedPayload(updatedAt: Date(), deviceID: cloudSync.deviceID, payload: localData) : nil,
            remote: payload,
            lastSyncedPayload: cloudSync.lastSyncedPayloadForComparison
        ) {
        case .applyRemote: applyRemote(payload)
        case .conflict: pendingCloudConflict = payload
        default: break
        }
    }

    private func applyRemote(_ payload: StampedPayload) {
        do {
            let term = try ScheduleArchive.decoded(from: payload.payload)
            try restore(from: term)
            cloudSync.markSynced(payload.payload)
            pendingCloudConflict = nil
            cloudSyncStatus = "已同步来自其他设备的改动。"
        } catch {
            cloudSyncStatus = "远端课表无法读取：\(error.localizedDescription)"
        }
    }

    /// 用户选择采用 iCloud 版本。
    func resolveConflictUsingCloud() {
        guard let payload = pendingCloudConflict else { return }
        applyRemote(payload)
    }

    /// 用户选择保留本机版本，覆盖云端。
    func resolveConflictKeepingLocal() {
        guard pendingCloudConflict != nil else { return }
        do {
            try cloudSync.push(try makeArchive().encoded())
            pendingCloudConflict = nil
            cloudSyncStatus = "已保留本机课表并覆盖 iCloud。"
        } catch {
            cloudSyncStatus = error.localizedDescription
        }
    }

    func dismissCloudConflict() { pendingCloudConflict = nil }

    /// 合并连续保存，避免每敲一个字就写一次 iCloud。
    private func scheduleCloudPush(_ data: Data) {
        cloudPushTask?.cancel()
        cloudPushTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2))
                try Task.checkCancellation()
                guard cloudSyncEnabled, pendingCloudConflict == nil else { return }
                try cloudSync.push(data)
                cloudSyncStatus = "已交给 iCloud 同步，其他设备更新可能稍有延迟。"
            } catch is CancellationError {} catch { cloudSyncStatus = error.localizedDescription }
        }
    }
    func synchronize() {
        guard !isPreview, !storageReadOnly else { return }
        syncTask?.cancel()
        let items = occurrences
        let snapshotTerm = activeTermID
        let snapshotLead = reminderMinutes
        let snapshotMilestones = milestones
        syncTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                try SystemSnapshot.write(items, leadMinutes: snapshotLead, termID: snapshotTerm,
                                         milestones: snapshotMilestones)
                WidgetCenter.shared.reloadAllTimelines()
                try await CourseNotifications.shared.replace(courses: items, enabled: reminderPreview, lead: reminderMinutes, endEnabled: endReminder, endLead: endLead)
                try await CourseNotifications.shared.replaceMilestones(snapshotMilestones)
                await CourseLiveActivities.shared.reconcile(items: items, enabled: liveEnabled, lead: reminderMinutes, termID: snapshotTerm)
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
            copy.wasRescheduled = item.wasRescheduled
            copy.originalRoom = item.originalRoom
            copy.weekPattern = item.weekPattern
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

    /// 缩短学期周数后，把课程里超出范围的周次裁掉。
    ///
    /// 不裁剪的话课表显示正常（渲染时按 totalWeeks 过滤），但导出与 iCloud 同步
    /// 会因为 weeksOutsideTerm 校验失败，用户会看到一个莫名其妙的错误。
    func clampCourseWeeksToTerm() {
        let limit = totalWeeks
        mutateActive { term in
            let result = ArchiveMapping.clampWeeks(
                term.courses, totalWeeks: limit,
                weeksOf: { $0.weeks },
                apply: { course, weeks in
                    var fixed = course
                    fixed.weeks = weeks
                    return fixed
                }
            )
            // 裁到没有周次的课程说明整门课都在被删掉的周里，一并移除。
            term.courses = result.kept
        }
    }

    /// 缩短作息表后，清理引用了已删除节次的课程。
    ///
    /// 这些课程在网格上无法定位，留着会导致绘制越界。删除前记录数量以便提示用户。
    @discardableResult
    func dropCoursesBeyondPeriod(_ lastValidPeriod: Int) -> Int {
        guard let content = termContents[activeTermID] else { return 0 }
        let removed = content.courses.filter { $0.startPeriod > lastValidPeriod || $0.endPeriod > lastValidPeriod }
        guard !removed.isEmpty else { return 0 }
        mutateActive { term in
            term.courses.removeAll { $0.startPeriod > lastValidPeriod || $0.endPeriod > lastValidPeriod }
            // 相关调课记录同时清理，避免悬挂引用。
            let kept = Set(term.courses.map(\.id))
            term.exceptions.removeAll { !kept.contains($0.courseID) }
        }
        errorMessage = "已移除 \(removed.count) 门课程，它们使用了被删除的节次。"
        return removed.count
    }

    // MARK: - 导出与恢复

    /// 把全部学期导出为可存档的格式。
    func makeArchive(exportedAt: Date = Date()) throws -> ScheduleArchive {
        guard !isPreview else { throw ArchiveError.emptySemesterList }
        let semesters = terms.compactMap { summary -> ArchivedSemester? in
            guard let content = termContents[summary.id] else { return nil }
            return ArchivedSemester(
                id: summary.id,
                name: content.name,
                startDate: content.startDate,
                totalWeeks: content.totalWeeks,
                periods: content.periods.map { ArchivedPeriod(index: $0.id, start: $0.start, end: $0.end) },
                courses: content.courses.map { course in
                    ArchivedCourse(id: course.id, sourceID: course.sourceID, title: course.title, room: course.room,
                                   teacher: course.teacher, weekday: course.weekday, startPeriod: course.startPeriod,
                                   endPeriod: course.endPeriod, color: course.color.rawValue,
                                   weeks: course.weeks.sorted(), remindersEnabled: course.remindersEnabled)
                },
                exceptions: content.exceptions.map { change in
                    ArchivedException(id: change.id.uuidString, courseID: change.courseID, day: change.day,
                                      cancelled: change.cancelled, start: change.start, end: change.end, room: change.room)
                },
                exams: content.exams
            )
        }
        return try ScheduleArchive(exportedAt: exportedAt, appVersion: Self.appVersion,
                                   semesters: semesters, milestones: milestones).validated()
    }

    static var appVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// 导入前的预检：只解析和校验，不写入任何状态，便于先向用户确认。
    nonisolated static func inspectArchive(_ data: Data) throws -> ScheduleArchive {
        try ScheduleArchive.decoded(from: data)
    }

    /// 用备份替换全部学期。调用方必须已经让用户确认；成功后立即保存并同步系统状态。
    func restore(from archive: ScheduleArchive, now: Date = Date()) throws {
        let validated = try archive.validated()
        guard !validated.semesters.isEmpty else { throw ArchiveError.emptySemesterList }

        var restored: [String: TermContent] = [:]
        for term in validated.semesters {
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
            guard restoredCourses.count == term.courses.count else {
                throw ArchiveError.courseOutsidePeriodRange(term.name, term.name)
            }
            // 编号必须从 1 连续，网格按下标定位；数量限制与学期内容校验保持一致。
            guard ArchiveMapping.periodsAreContiguous(term.periods, range: Self.supportedPeriodRange) else {
                throw ArchiveError.emptyPeriods(term.name)
            }
            restored[term.id] = TermContent(
                name: term.name, startDate: term.startDate, totalWeeks: term.totalWeeks,
                periods: restoredPeriods, courses: restoredCourses,
                exceptions: term.exceptions.map { change in
                    CourseException(id: UUID(uuidString: change.id) ?? UUID(), courseID: change.courseID,
                                    day: change.day, cancelled: change.cancelled,
                                    start: change.start, end: change.end, room: change.room)
                },
                exams: term.exams
            )
        }

        guard restored.values.allSatisfy({ Self.isValid($0) }) else { throw CocoaError(.fileReadCorruptFile) }
        if persistence == nil && !isPreview { persistence = try LocalPersistence() }
        // 包括读取失败的原始载荷；副本失败则整个恢复停止。
        try backupBeforeReplacing()
        let oldIssue = storageIssue
        storageIssue = nil
        // 恢复后把当前学期指向按日期应当显示的那个，而不是备份里第一个。
        let summaries = restored.map { TermSummary(id: $0.key, name: $0.value.name,
                                                   startDate: $0.value.startDate, totalWeeks: $0.value.totalWeeks) }
        let selected = TermSelection.preferred(in: summaries, on: now)?.id ?? restored.keys.sorted().first ?? ""
        guard commitBatch({
            termContents = restored
            activeTermID = selected
            milestones = validated.milestones
            selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        }) else {
            storageIssue = oldIssue
            throw CocoaError(.fileWriteUnknown)
        }
        originalRecoveryData = nil; errorMessage = nil
    }

    // MARK: - 学期管理

    /// 切换当前学期。
    func selectTerm(_ id: String, now: Date = Date()) {
        guard !storageReadOnly, termContents[id] != nil, id != activeTermID else { return }
        commitBatch {
            activeTermID = id
            selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        }
    }

    func resolveCourseLink(_ target: CourseDeepLink.Target) -> DemoCourse? {
        guard !storageReadOnly else { return nil }
        if let term = target.termID {
            guard termContents[term]?.courses.contains(where: { $0.id == target.courseID }) == true else { return nil }
            selectTerm(term)
            guard activeTermID == term else { return nil }
        } else if !courses.contains(where: { $0.id == target.courseID }) {
            let matches = termContents.filter { $0.value.courses.contains { $0.id == target.courseID } }.map(\.key)
            guard matches.count == 1 else { return nil }
            selectTerm(matches[0])
        }
        return courses.first { $0.id == target.courseID }
    }

    /// 新建学期，返回新学期标识。节次时间沿用当前学期的作息，减少重复输入。
    @discardableResult
    func addTerm(name: String? = nil, start: Date? = nil, totalWeeks weeks: Int = 20) -> String {
        guard !storageReadOnly else { errorMessage = storageIssue; return activeTermID }
        let id = "term-" + UUID().uuidString
        let suggested = name ?? TermSelection.uniqueName("新学期", existing: terms)
        let content = TermContent(
            name: suggested,
            startDate: start ?? TermSelection.suggestedStart(after: terms),
            totalWeeks: weeks,
            periods: periods.isEmpty ? Self.defaultPeriods : periods,
            courses: [],
            exceptions: []
        )
        return commitBatch({ termContents[id] = content }) ? id : activeTermID
    }

    /// 删除学期。至少保留一个，避免界面进入没有任何学期的状态。
    @discardableResult
    func deleteTerm(_ id: String, now: Date = Date()) -> Bool {
        guard !storageReadOnly, termContents.count > 1, termContents[id] != nil else { return false }
        do { try backupBeforeReplacing() } catch { errorMessage = "无法备份原学期，未删除。"; return false }
        return commitBatch {
            termContents.removeValue(forKey: id)
            if activeTermID == id {
                activeTermID = TermSelection.afterRemoving(id, from: terms, on: now)?.id
                    ?? termContents.keys.sorted().first ?? ""
                selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
            }
        }
    }

    /// 重命名学期。
    func renameTerm(_ id: String, to name: String) {
        guard !storageReadOnly, var content = termContents[id] else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        content.name = trimmed
        commitBatch { termContents[id] = content }
    }

    @discardableResult
    func deleteCourse(_ id: String) -> Bool {
        guard !storageReadOnly else { return false }
        do { try backupBeforeReplacing() } catch { errorMessage = "无法保留课程副本，未删除。"; return false }
        return commitBatch {
            mutateActive { term in
                term.courses.removeAll { $0.id == id }
                term.exceptions.removeAll { $0.courseID == id }
            }
        }
    }

    // MARK: - 导入

    /// 用当前学期的现状为一次解析结果生成导入方案。
    ///
    /// 导入页与网页登录页都要做同一件事：把现有课程转成可比较的形状、带上当前
    /// 节次与周数上限。集中在这里，避免两处入口对同一规则各写一份。
    func makeImportPlan(_ outcome: ParseOutcome) -> ImportPlanner.Plan {
        let existing = courses.map {
            ParsedCourse(title: $0.title, teacher: $0.teacher, room: $0.room,
                         weekday: $0.weekday, startPeriod: $0.startPeriod,
                         endPeriod: $0.endPeriod, weeks: $0.weeks)
        }
        var plan = ImportPlanner.plan(outcome, existing: existing,
                                      totalWeeks: totalWeeks, periodCount: periods.count)
        plan.targetTermID = activeTermID
        return plan
    }

    @discardableResult
    func applyImport(_ plan: ImportPlanner.Plan) -> Int {
        guard plan.targetTermID == activeTermID else {
            errorMessage = "当前学期已改变，请重新预览导入内容。"; return 0
        }
        return applyImport(plan.courses)
    }


    /// 把导入的课程合并进当前学期。
    ///
    /// 同名同时间的课程覆盖原条目而不是重复添加；其余追加。
    /// 时间标签根据节次从作息表推导，保证导入后立即显示正确时刻。
    /// - Returns: 实际写入的课程数。少于输入数量说明有课程被跳过，调用方应当提示用户。
    @discardableResult
    func applyImport(_ imported: [ParsedCourse]) -> Int {
        guard !storageReadOnly, !imported.isEmpty else { return 0 }
        // 确认之前作息或周数可能改变，写入前再做一次边界校验。
        let reviewed = makeImportPlan(ParseOutcome(courses: imported))
        let byIndex = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
        var result = courses
        var written = 0
        var skipped = 0
        for parsed in reviewed.courses {
            guard let start = byIndex[parsed.startPeriod], let end = byIndex[parsed.endPeriod] else {
                skipped += 1
                continue
            }
            let existing = result.map { ParsedCourse(title: $0.title, teacher: $0.teacher, room: $0.room,
                weekday: $0.weekday, startPeriod: $0.startPeriod, endPeriod: $0.endPeriod, weeks: $0.weeks) }
            let matchingIndex = ImportPlanner.replacementIndex(for: parsed, in: existing, totalWeeks: totalWeeks)
            var course = DemoCourse(
                id: matchingIndex.map { result[$0].id } ?? "import-\(UUID().uuidString)",
                title: parsed.title,
                room: parsed.room,
                teacher: parsed.teacher,
                weekday: parsed.weekday,
                startPeriod: parsed.startPeriod,
                endPeriod: parsed.endPeriod,
                startTime: start.start,
                endTime: end.end,
                color: matchingIndex.map { result[$0].color } ?? Self.color(for: parsed.title),
                weeks: parsed.weeks.isEmpty ? Set(1...totalWeeks) : parsed.weeks
            )
            // 同名同节次同天视为同一门课，替换以保留用户之后的手动修改位置。
            if let index = matchingIndex {
                // 保留身份与用户设置，调停课记录继续引用同一门课程。
                var replacement = course
                replacement.remindersEnabled = result[index].remindersEnabled
                replacement.sourceID = result[index].sourceID
                result[index] = replacement
            } else {
                result.append(course)
            }
            written += 1
        }
        do { try backupBeforeReplacing() }
        catch { errorMessage = "无法备份导入前的数据，未导入。"; return 0 }
        guard commitBatch({ courses = result }) else { return 0 }
        // 不静默吞掉：跳过任何课程都要让用户知道。
        skipped += imported.count - reviewed.courses.count
        errorMessage = skipped > 0
            ? "已导入 \(written) 门课程，另有 \(skipped) 条未写入，请检查导入预览和学期作息。"
            : nil
        return written
    }

    /// 按课程名稳定地分配颜色，使同一门课在多次导入后保持一致。
    static func color(for title: String) -> CourseColor {
        let palette = CourseColor.allCases
        var hash = 5381
        for byte in title.utf8 { hash = (hash &* 33) &+ Int(byte) }
        return palette[abs(hash) % palette.count]
    }
}
