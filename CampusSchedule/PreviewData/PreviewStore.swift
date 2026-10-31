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
    var showsWeekend = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_WEEKEND"] == "1"

    /// 单个学期的全部内容。多学期共用一个容器，靠 `activeTermID` 切换。
    struct TermContent: Codable {
        var name: String
        var startDate: Date
        var totalWeeks: Int
        var periods: [DemoPeriod]
        var courses: [DemoCourse]
        var exceptions: [CourseException] = []
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

    static let defaultPeriods: [DemoPeriod] = [
        .init(id: 1, start: "08:00", end: "08:45"), .init(id: 2, start: "08:50", end: "09:35"),
        .init(id: 3, start: "10:00", end: "10:45"), .init(id: 4, start: "10:50", end: "11:35"),
        .init(id: 5, start: "14:00", end: "14:45"), .init(id: 6, start: "14:50", end: "15:35"),
        .init(id: 7, start: "16:00", end: "16:45"), .init(id: 8, start: "16:50", end: "17:35"),
        .init(id: 9, start: "19:00", end: "19:45"), .init(id: 10, start: "19:50", end: "20:35")
    ]

    static let sampleCourses: [DemoCourse] = [
        .init(id: "math-mon", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 0, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "english-mon", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 0, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-mon", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 0, startPeriod: 7, endPeriod: 8, startTime: "16:00", endTime: "17:35", color: .orange),
        .init(id: "code-tue", title: "程序设计", room: "实验楼 · 502", teacher: "王老师", weekday: 1, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .green),
        .init(id: "math-wed", title: "高等数学", room: "教学楼 A · 302", teacher: "陈老师", weekday: 2, startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue),
        .init(id: "sport-wed", title: "大学体育", room: "东区体育馆", teacher: "刘老师", weekday: 2, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .green),
        .init(id: "english-thu", title: "大学英语", room: "教学楼 B · 205", teacher: "林老师", weekday: 3, startPeriod: 3, endPeriod: 4, startTime: "10:00", endTime: "11:35", color: .purple),
        .init(id: "design-fri", title: "设计基础", room: "艺术楼 · 401", teacher: "周老师", weekday: 4, startPeriod: 5, endPeriod: 6, startTime: "14:00", endTime: "15:35", color: .orange)
    ]

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

    /// 用户是否开启了 iCloud 同步。默认关闭，与产品约定一致。
    var cloudSyncEnabled = false {
        didSet {
            guard cloudSyncEnabled != oldValue else { return }
            if cloudSyncEnabled { beginCloudSync() } else { stopCloudSync() }
        }
    }
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
    }

    /// 单学期时代的存储结构。仅用于把旧文件迁移到多学期容器，不参与新写入。
    private struct LegacySaved: Codable {
        var courses: [DemoCourse]; var periods: [DemoPeriod]; var semesterName: String; var semesterStart: Date
        var totalWeeks: Int; var reminders: Bool; var lead: Int; var endReminder: Bool; var endLead: Int
        var liveEnabled: Bool; var exceptions: [CourseException]
        var cloudSyncEnabled: Bool?
    }

    init() {
        // 先建立活动学期，之后的字段读写都落到这个容器里。
        let initialID = "term-" + UUID().uuidString
        termContents[initialID] = TermContent(
            name: "2026 秋季学期",
            startDate: ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!,
            totalWeeks: 20,
            periods: Self.defaultPeriods,
            courses: Self.sampleCourses,
            exceptions: []
        )
        activeTermID = initialID

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
            do {
                let storage = try LocalPersistence()
                persistence = storage
                if let data = try storage.load() {
                    loadSaved(data)
                } else {
                    // 全新安装：保留空学期，等待用户添加课程。
                    courses = []; reminderPreview = false
                }
                if termContents.isEmpty { courses = [] }
                if activeContent == nil { courses = [] }
            } catch { errorMessage = "本地数据无法读取，未覆盖原有文件：\(error.localizedDescription)" }
        }
        selectedWeek = min(totalWeeks, max(1, currentWeek))
        ready = true
        // 存储已就绪，此时再开启同步才能读到本地内容；直接在这里赋值会绕过持久化准备。
        if restoreCloudSync { cloudSyncEnabled = true; restoreCloudSync = false }
    }

    /// 读取存储内容，优先多学期格式，失败后尝试单学期旧格式迁移。
    private func loadSaved(_ data: Data) {
        let decoder = JSONDecoder()
        if let saved = try? decoder.decode(Saved.self, from: data) {
            guard !saved.terms.isEmpty else { errorMessage = "本地数据中没有学期。"; return }
            guard saved.terms.allSatisfy({ _, content in Self.isValid(content) }) else {
                errorMessage = "本地数据校验未通过，未覆盖原有文件。"; return
            }
            termContents = saved.terms
            activeTermID = saved.terms[saved.activeTermID] != nil ? saved.activeTermID : (saved.terms.keys.sorted().first ?? "")
            reminderPreview = saved.reminders; reminderMinutes = saved.lead
            endReminder = saved.endReminder; endLead = saved.endLead; liveEnabled = saved.liveEnabled
            restoreCloudSync = saved.cloudSyncEnabled == true
            return
        }
        guard let legacy = try? decoder.decode(LegacySaved.self, from: data) else {
            errorMessage = "本地数据无法读取，未覆盖原有文件。"
            return
        }
        let content = TermContent(name: legacy.semesterName, startDate: legacy.semesterStart,
                                  totalWeeks: legacy.totalWeeks, periods: legacy.periods,
                                  courses: legacy.courses, exceptions: legacy.exceptions)
        guard Self.isValid(content) else {
            errorMessage = "本地数据校验未通过，未覆盖原有文件。"; return
        }
        let migratedID = "term-migrated"
        termContents = [migratedID: content]
        activeTermID = migratedID
        reminderPreview = legacy.reminders; reminderMinutes = legacy.lead
        endReminder = legacy.endReminder; endLead = legacy.endLead; liveEnabled = legacy.liveEnabled
        restoreCloudSync = legacy.cloudSyncEnabled == true
    }

    /// 学期内容的完整性检查。学期设置页固定 10 节，越界数据会让网格绘错。
    static func isValid(_ content: TermContent) -> Bool {
        guard (1...53).contains(content.totalWeeks), content.periods.count == 10 else { return false }
        guard content.periods.map(\.id) == Array(1...10) else { return false }
        guard content.periods.allSatisfy({
            ScheduleRules.date(day: Date(), time: $0.start) != nil && ScheduleRules.date(day: Date(), time: $0.end) != nil
        }) else { return false }
        let indices = Set(content.periods.map(\.id))
        return content.courses.allSatisfy { course in
            (0...6).contains(course.weekday) && indices.contains(course.startPeriod)
                && indices.contains(course.endPeriod) && course.endPeriod >= course.startPeriod
        }
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
            let data = Saved(activeTermID: activeTermID, terms: termContents,
                reminders: reminderPreview, lead: reminderMinutes, endReminder: endReminder,
                endLead: endLead, liveEnabled: liveEnabled, cloudSyncEnabled: cloudSyncEnabled)
            let encoded = try JSONEncoder().encode(data)
            try persistence.save(encoded)
            synchronize()
            // 云端统一使用归档格式：它有版本号与校验，恢复路径也复用它。
            if cloudSyncEnabled, let archive = try? makeArchive().encoded() {
                scheduleCloudPush(archive)
            }
        } catch { errorMessage = "保存失败：\(error.localizedDescription)" }
    }

    // MARK: - iCloud 同步

    private func beginCloudSync() {
        guard !isDemoEdition, !isPreview else {
            cloudSyncStatus = "演示版不参与 iCloud 同步。"
            return
        }
        guard cloudSync.isAvailable else {
            cloudSyncStatus = CloudSyncError.unavailable.errorDescription
            return
        }
        do {
            let localData = try persistence?.load()
            switch cloudSync.decision(local: localData) {
            case .idle:
                cloudSyncStatus = "已是最新。"
            case .pushLocal:
                guard let localData else { throw CloudSyncError.decodeFailed }
                try cloudSync.push(localData)
                cloudSyncStatus = "已上传本机课表。"
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
            cloudSyncStatus = error.localizedDescription
        }
        cloudSync.startObserving { [weak self] payload in
            self?.handleRemoteChange(payload)
        }
    }

    private func stopCloudSync() {
        cloudSync.stopObserving()
        cloudSync.resetSyncState()
        pendingCloudConflict = nil
        cloudSyncStatus = "已关闭同步。"
    }

    /// 远端变化：本地没改过就直接采用，改过则挂起等用户决定。
    private func handleRemoteChange(_ payload: StampedPayload) {
        guard cloudSyncEnabled, !payload.payload.isEmpty, payload.deviceID != cloudSync.deviceID else { return }
        guard let localData = try? persistence?.load() else {
            applyRemote(payload); return
        }
        switch CloudSyncPlan.decide(
            local: StampedPayload(updatedAt: Date(), deviceID: cloudSync.deviceID, payload: localData),
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
                cloudSyncStatus = "已同步到 iCloud。"
            } catch is CancellationError {} catch { cloudSyncStatus = error.localizedDescription }
        }
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

    /// 把全部学期导出为可存档的格式。演示版与截图模式不产出真实数据。
    func makeArchive(exportedAt: Date = Date()) throws -> ScheduleArchive {
        guard !isDemoEdition, !isPreview else { throw ArchiveError.emptySemesterList }
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
                }
            )
        }
        return try ScheduleArchive(exportedAt: exportedAt, appVersion: Self.appVersion, semesters: semesters).validated()
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
            // 学期设置页假设恰好 10 节且编号 1…10；备份允许任意编号，这里拒绝会让设置页越界的数据。
            guard restoredPeriods.map(\.id) == Array(1...restoredPeriods.count), restoredPeriods.count == 10 else {
                throw ArchiveError.emptyPeriods(term.name)
            }
            restored[term.id] = TermContent(
                name: term.name, startDate: term.startDate, totalWeeks: term.totalWeeks,
                periods: restoredPeriods, courses: restoredCourses,
                exceptions: term.exceptions.map { change in
                    CourseException(id: UUID(uuidString: change.id) ?? UUID(), courseID: change.courseID,
                                    day: change.day, cancelled: change.cancelled,
                                    start: change.start, end: change.end, room: change.room)
                }
            )
        }

        termContents = restored
        // 恢复后把当前学期指向按日期应当显示的那个，而不是备份里第一个。
        let summaries = restored.map { TermSummary(id: $0.key, name: $0.value.name,
                                                   startDate: $0.value.startDate, totalWeeks: $0.value.totalWeeks) }
        activeTermID = TermSelection.preferred(in: summaries, on: now)?.id ?? restored.keys.sorted().first ?? ""
        selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        errorMessage = nil
        save()
    }

    // MARK: - 学期管理

    /// 切换当前学期。
    func selectTerm(_ id: String, now: Date = Date()) {
        guard termContents[id] != nil, id != activeTermID else { return }
        activeTermID = id
        selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        save()
    }

    /// 新建学期，返回新学期标识。节次时间沿用当前学期的作息，减少重复输入。
    @discardableResult
    func addTerm(name: String? = nil, start: Date? = nil, totalWeeks weeks: Int = 20) -> String {
        let id = "term-" + UUID().uuidString
        let suggested = name ?? TermSelection.uniqueName("新学期", existing: terms)
        termContents[id] = TermContent(
            name: suggested,
            startDate: start ?? TermSelection.suggestedStart(after: terms),
            totalWeeks: weeks,
            periods: periods.isEmpty ? Self.defaultPeriods : periods,
            courses: [],
            exceptions: []
        )
        save()
        return id
    }

    /// 删除学期。至少保留一个，避免界面进入没有任何学期的状态。
    @discardableResult
    func deleteTerm(_ id: String, now: Date = Date()) -> Bool {
        guard termContents.count > 1, termContents[id] != nil else { return false }
        termContents.removeValue(forKey: id)
        if activeTermID == id {
            activeTermID = TermSelection.afterRemoving(id, from: terms, on: now)?.id
                ?? termContents.keys.sorted().first ?? ""
            selectedWeek = min(totalWeeks, max(1, ScheduleRules.week(on: now, semesterStart: semesterStart)))
        }
        save()
        return true
    }

    /// 重命名学期。
    func renameTerm(_ id: String, to name: String) {
        guard var content = termContents[id] else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        content.name = trimmed
        termContents[id] = content
    }
}
