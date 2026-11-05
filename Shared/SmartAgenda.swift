import Foundation

/// 「智能课间」组件要展示的一条安排。
///
/// 只描述**该显示什么**，不含任何 SwiftUI 类型：同一份选择结果要同时供桌面、
/// 锁屏与单元测试使用，渲染层只负责排版。
public struct SmartAgendaItem: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case exam, course, task, milestone
    }

    /// 组件的点击目标。由渲染层翻译成深链。
    public enum Target: Equatable, Sendable {
        case exam(id: String, termID: String)
        case course(courseID: String, termID: String?, occurrenceID: String)
        /// 待办打开所属课程，那段流程里能看到该课程的清单。
        case task(courseID: String, termID: String?)
        case milestone(id: String)
    }

    /// 从「多紧急」到「只是提醒」的强弱，仅用于配色，不参与排序。
    public enum Urgency: Sendable {
        case happening   // 正在发生
        case imminent    // 一小时内 / 即将开始
        case upcoming    // 稍后
        case distant     // 只是提醒
    }

    public var id: String
    public var kind: Kind
    /// 顶部小字，例如「09:00 开考」「还有 20 分钟」「今天」「2 天后」。
    public var status: String
    public var title: String
    /// 次要信息：考场座位、教室、课程名。
    public var detail: String
    public var examSeat: String?
    /// 右侧主数值：时刻或天数。
    public var value: String
    /// 数值单位。纪念事件的天数与单位一起显示，其他类型为空。
    public var unit: String
    public var urgency: Urgency
    public var target: Target
    /// 这条状态会在什么时候改变。用于提前排好时间线切换点。
    public var changesAt: Date?

    public init(id: String, kind: Kind, status: String, title: String, detail: String,
                value: String, unit: String = "", urgency: Urgency, target: Target,
                changesAt: Date? = nil, examSeat: String? = nil) {
        self.id = id
        self.kind = kind
        self.status = status
        self.title = title
        self.detail = detail
        self.examSeat = examSeat
        self.value = value
        self.unit = unit
        self.urgency = urgency
        self.target = target
        self.changesAt = changesAt
    }

    /// 一行无障碍朗读文本，避免把四段文字拆成四个元素。
    public var accessibilityText: String {
        [statusWithQuantity, title, detailWithSeat]
            .filter { !$0.isEmpty }
            .joined(separator: "，")
    }

    var quantity: String { unit.isEmpty ? value : "\(value) \(unit)" }
    var statusWithQuantity: String { unit.isEmpty ? status : "\(status) \(quantity)" }
    var detailWithSeat: String {
        [detail, examSeat ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// 用户在长按编辑里对「智能课间」的选择。
///
/// 锁屏默认只允许课程与考试，待办和纪念事件必须显式开启：锁屏空间只够一行，
/// 不该被一条不紧急的作业占住。
public struct SmartAgendaOptions: Codable, Equatable, Sendable {
    public var allowTasks: Bool
    public var allowMilestones: Bool
    /// 用户选中的纪念事件。为空时只看置顶事件，不擅自挑一个。
    public var milestoneID: String?

    public init(allowTasks: Bool = false, allowMilestones: Bool = false, milestoneID: String? = nil) {
        self.allowTasks = allowTasks
        self.allowMilestones = allowMilestones
        self.milestoneID = milestoneID
    }

    /// 桌面默认全部开启，锁屏默认只开课程与考试。
    public static func defaults(forLockScreen: Bool) -> SmartAgendaOptions {
        SmartAgendaOptions(allowTasks: !forLockScreen, allowMilestones: !forLockScreen)
    }
}

/// 待办在组件侧的投影。
///
/// 组件拿不到课程对象，只拿到快照。课程名在写入快照时就解析好，避免组件进程里
/// 再做一次查找。
public struct AgendaTask: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var courseID: String
    public var courseTitle: String
    public var title: String
    public var due: Date
    public var termID: String?

    public init(id: String, courseID: String, courseTitle: String, title: String, due: Date, termID: String? = nil) {
        self.id = id
        self.courseID = courseID
        self.courseTitle = courseTitle
        self.title = title
        self.due = due
        self.termID = termID
    }
}

/// 一次选择的结果。
public struct SmartAgendaSelection: Equatable, Sendable {
    public var primary: SmartAgendaItem?
    /// 中号组件底部的补充。主信息存在时，两条属于不同类别。
    public var secondary: SmartAgendaItem?
    /// 已逾期但未完成的待办数量。中号组件在底部提示，不占主位。
    public var overdueCount: Int

    public init(primary: SmartAgendaItem?, secondary: SmartAgendaItem?, overdueCount: Int) {
        self.primary = primary
        self.secondary = secondary
        self.overdueCount = overdueCount
    }

    public var isEmpty: Bool { primary == nil }
}

/// 智能课间的选条规则。
///
/// 五档优先级来自产品定义，档位内一律取**时间最近**的一条；同一时刻再按类别
/// 固定顺序决定，保证输入相同时结果稳定 —— 组件在多个切换点重复求值时不能
/// 出现来回跳变。
public enum SmartAgenda {
    /// 考试开考前一小时进入「即将开考」。
    public static let examLead: TimeInterval = 60 * 60
    /// 待办两小时内算「紧急」。
    public static let taskLead: TimeInterval = 2 * 60 * 60
    /// 纪念事件剩余三天内进入主位。
    public static let milestoneLeadDays = 3

    /// 这两个入口接收 `CourseOccurrence` / `ExamSession`，它们只在模块内可见，
    /// 因此函数本身也保持 internal。App 与组件各自把 `Shared` 编进同一个模块，
    /// 测试用 `@testable import`，都不需要 public。
    static func select(courses: [CourseOccurrence], exams: [ExamSession],
                       tasks: [AgendaTask], milestones: [Milestone],
                       now: Date, leadMinutes: Int,
                       options: SmartAgendaOptions,
                       calendar: Calendar = ScheduleRules.calendar, courseTermID: String? = nil) -> SmartAgendaSelection {
        let candidates = buildCandidates(courses: courses, exams: exams, tasks: tasks,
                                         milestones: milestones, now: now,
                                         leadMinutes: leadMinutes, options: options,
                                         calendar: calendar, courseTermID: courseTermID)
        let overdue = options.allowTasks ? tasks.count(where: { $0.due <= now }) : 0

        guard let primary = best(in: candidates.filter { !$0.secondaryOnly }) else {
            return SmartAgendaSelection(primary: nil, secondary: best(in: candidates)?.item, overdueCount: overdue)
        }
        // 第二条必须换一个类别：同一类两行只会挤占信息量。
        let secondary = best(in: candidates.filter {
            $0.item.kind != primary.item.kind
        })?.item
        return SmartAgendaSelection(primary: primary.item, secondary: secondary, overdueCount: overdue)
    }

    /// 组件需要重新求值的时间点。
    ///
    /// 覆盖：所有课程与考试的起止、开考前一小时的提醒阈值、待办的截止与
    /// 两小时阈值、纪念事件的日期切换、以及下一个零点。只保留未来且落在观察
    /// 窗口内的点，避免塞给系统几百个无意义的条目。
    static func switchDates(courses: [CourseOccurrence], exams: [ExamSession],
                            tasks: [AgendaTask], milestones: [Milestone],
                            now: Date, leadMinutes: Int,
                            options: SmartAgendaOptions,
                            horizonHours: Int = 48,
                            limit: Int = 20,
                            calendar: Calendar = ScheduleRules.calendar) -> [Date] {
        let horizon = now.addingTimeInterval(Double(horizonHours) * 3600)
        var dates: Set<Date> = [now]

        for course in courses {
            let lead = course.start.addingTimeInterval(-Double(max(0, leadMinutes)) * 60)
            for date in [course.start, course.end, lead] where date > now && date < horizon {
                dates.insert(date)
            }
        }
        for exam in exams {
            for date in [exam.start, exam.end, exam.start.addingTimeInterval(-examLead)]
            where date > now && date < horizon {
                dates.insert(date)
            }
        }
        if options.allowTasks {
            for task in tasks {
                for date in [task.due, task.due.addingTimeInterval(-taskLead)]
                where date > now && date < horizon {
                    dates.insert(date)
                }
            }
        }
        // 天数与「今天/明天」都按日历日变化，零点必须重新求值，与开关无关。
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           midnight > now, midnight < horizon {
            dates.insert(midnight)
        }
        return Array(dates.sorted().prefix(limit))
    }

    // MARK: - 候选

    struct Candidate {
        var item: SmartAgendaItem
        /// 档位越小越优先。档位相同时按 `moment` 由近到远。
        var tier: Int
        var moment: Date
        var secondaryOnly = false
    }

    static func buildCandidates(courses: [CourseOccurrence], exams: [ExamSession],
                                tasks: [AgendaTask], milestones: [Milestone],
                                now: Date, leadMinutes: Int, options: SmartAgendaOptions,
                                calendar: Calendar, courseTermID: String?) -> [Candidate] {
        var result: [Candidate] = []

        // 1. 考试进行中或一小时内开考。
        let leadSeconds = Double(max(0, leadMinutes)) * 60
        for exam in exams {
            guard exam.end > now else { continue }
            let inProgress = exam.start <= now
            guard inProgress || exam.start.timeIntervalSince(now) <= examLead else { continue }
            result.append(Candidate(
                item: examItem(exam, now: now, inProgress: inProgress),
                tier: 1, moment: exam.start))
        }

        // 2. 正在上课，或下一节进入课前提醒时段。
        let sorted = courses.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        let upcoming = sorted.first { $0.start > now }
        if let current = sorted.first(where: { $0.start <= now && $0.end > now }) {
            let following = sorted.first { $0.start >= current.end && calendar.isDate($0.start, inSameDayAs: current.start) }
            result.append(Candidate(item: courseItem(current, now: now, inProgress: true,
                                                     next: following, calendar: calendar, termID: courseTermID),
                                    tier: 2, moment: current.start))
        } else if let next = upcoming {
            // 只有进入提醒时段才占第 2 档；更远的课留到第 5 档兜底。
            if next.start.timeIntervalSince(now) <= leadSeconds {
                result.append(Candidate(item: courseItem(next, now: now, inProgress: false,
                                                         calendar: calendar, termID: courseTermID),
                                        tier: 2, moment: next.start))
            }
        }

        // 3. 两小时内有待办截止。已逾期的由底部提示承担，不抢主位。
        if options.allowTasks {
            for task in tasks where task.due > now && task.due.timeIntervalSince(now) <= taskLead {
                result.append(Candidate(item: taskItem(task),
                                        tier: 3, moment: task.due))
            }
        }

        // 4. 关注的事件临近或到日时占主位。普通累计日作为中号补充。
        if options.allowMilestones {
            for milestone in watchedMilestones(milestones, options: options) {
                let reading = MilestoneCounter.read(milestone, now: now, calendar: calendar)
                guard !reading.isHidden(expiry: milestone.expiry) else { continue }
                let secondaryOnly: Bool
                switch reading.state {
                case .today:
                    secondaryOnly = false
                case .upcoming(let days):
                    guard days <= milestoneLeadDays else { continue }
                    secondaryOnly = false
                case .past(let days):
                    guard milestone.direction == .countUp else { continue }
                    secondaryOnly = !MilestoneFormat.isRelationshipMarker(milestone, elapsed: days)
                }
                let moment = max(calendar.startOfDay(for: now), calendar.startOfDay(for: reading.effectiveDate))
                result.append(Candidate(
                    item: milestoneItem(milestone, reading: reading, now: now, calendar: calendar),
                     tier: secondaryOnly ? 6 : 4, moment: moment, secondaryOnly: secondaryOnly))
            }
        }

        // 5. 兜底：下一节课。没有任何紧急事项时，用户最想知道的还是下节课在哪。
        if let next = upcoming {
            result.append(Candidate(item: courseItem(next, now: now, inProgress: false,
                                                     calendar: calendar, termID: courseTermID),
                                    tier: 5, moment: next.start))
        }
        return result
    }

    static func best(in candidates: [Candidate]) -> Candidate? {
        candidates.min {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.moment != $1.moment { return $0.moment < $1.moment }
            // 同一档位同一时刻时按类别、再按标识固定顺序，保证多次求值结果一致。
            if $0.item.kind.rawValue != $1.item.kind.rawValue {
                return $0.item.kind.rawValue < $1.item.kind.rawValue
            }
            return $0.item.id < $1.item.id
        }
    }

    /// 用户选中的事件优先；没选时只看置顶的，不擅自挑一条没被关注的日子。
    static func watchedMilestones(_ milestones: [Milestone], options: SmartAgendaOptions) -> [Milestone] {
        if let id = options.milestoneID, let match = milestones.first(where: { $0.id == id }) {
            return [match]
        }
        guard options.milestoneID == nil else { return [] }
        return milestones.filter(\.pinned)
    }

    // MARK: - 文案

    static func examItem(_ exam: ExamSession, now: Date, inProgress: Bool) -> SmartAgendaItem {
        return SmartAgendaItem(
            id: "exam:\(exam.termID.utf8.count):\(exam.termID).\(exam.id)",
            kind: .exam,
            status: inProgress ? "考试中 · \(ScheduleRules.time(exam.end)) 结束"
                               : "\(ScheduleRules.time(exam.start)) 开考",
            title: exam.title,
            detail: exam.room,
            value: ScheduleRules.time(inProgress ? exam.end : exam.start),
            urgency: inProgress ? .happening : .imminent,
            target: .exam(id: exam.id, termID: exam.termID),
            changesAt: inProgress ? exam.end : exam.start,
            examSeat: exam.seat.isEmpty ? nil : "\(exam.seat) 号座")
    }

    static func courseItem(_ course: CourseOccurrence, now: Date, inProgress: Bool,
                            next: CourseOccurrence? = nil, calendar: Calendar, termID: String?) -> SmartAgendaItem {
        let room = NowStatus.shorten(course.room)
        var detail = room.isEmpty ? "地点待确认" : room
        if inProgress, let next, ScheduleRules.needsMove(from: course.room, to: next.room) == true {
            detail += " · 下节去 \(NowStatus.shorten(next.room))"
        }
        return SmartAgendaItem(
            id: "course:" + course.id,
            kind: .course,
            status: inProgress ? "正在上课 · \(ScheduleRules.time(course.end)) 下课"
                               : "\(dayLabel(course.start, now: now, calendar: calendar)) \(ScheduleRules.time(course.start))",
            title: course.title,
            detail: detail,
            value: ScheduleRules.time(inProgress ? course.end : course.start),
            urgency: inProgress ? .happening : .upcoming,
            target: .course(courseID: course.courseID, termID: termID, occurrenceID: course.id),
            changesAt: inProgress ? course.end : course.start)
    }

    static func taskItem(_ task: AgendaTask) -> SmartAgendaItem {
        SmartAgendaItem(
            id: "task:" + task.id,
            kind: .task,
            status: "\(ScheduleRules.time(task.due)) 截止",
            title: task.title,
            detail: task.courseTitle,
            value: ScheduleRules.time(task.due),
            urgency: .imminent,
            target: .task(courseID: task.courseID, termID: task.termID),
            changesAt: task.due)
    }

    static func milestoneItem(_ milestone: Milestone, reading: MilestoneReading,
                              now: Date, calendar: Calendar) -> SmartAgendaItem {
        let title = milestone.title.isEmpty ? "纪念事件" : milestone.title
        let value: String
        let unit: String
        switch reading.state {
        case .today:
            value = "今天"; unit = ""
        case .upcoming(let days), .past(let days):
            value = String(days); unit = "天"
        }
        let status = reading.state == .today ? "就是今天" : (MilestoneFormat.counterCaption(milestone, reading: reading) ?? "")
        let detail = MilestoneFormat.dateText(reading.effectiveDate, relativeTo: now, calendar: calendar)
        return SmartAgendaItem(
            id: "milestone:" + milestone.id,
            kind: .milestone,
            status: status,
            title: title,
            detail: detail,
            value: value,
            unit: unit,
            urgency: reading.state == .today ? .happening : .distant,
            target: .milestone(id: milestone.id),
            changesAt: reading.effectiveDate)
    }

    static func dayLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        if day == today { return "今天" }
        if day == calendar.date(byAdding: .day, value: 1, to: today) { return "明天" }
        return "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }
}
