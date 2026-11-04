import Foundation

/// 纪念事件：一个值得记住的日期，既可以倒数也可以累计。
///
/// 与考试的区别在语义：考试有具体的起止时刻并可能排进课表，纪念事件通常只有
/// 一个日期，用途是「距离毕业还有 120 天」这类持续的计数。
public struct Milestone: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// 目标日期。计数只取年月日，时分秒被忽略。
    public var date: Date
    public var direction: Direction
    public var category: Category
    /// 是否置顶到今日页。
    public var pinned: Bool
    /// 提前几天提醒。0 表示不提醒。
    public var reminderDaysBefore: Int
    /// 每年在同一天重复。
    public var repeatsAnnually: Bool
    /// 过期后的处理方式。
    public var expiry: Expiry

    public init(id: String = UUID().uuidString, title: String, date: Date,
                direction: Direction = .countdown, category: Category = .personal,
                pinned: Bool = false, reminderDaysBefore: Int = 0,
                repeatsAnnually: Bool = false, expiry: Expiry = .continueCounting) {
        self.id = id
        self.title = title
        self.date = date
        self.direction = direction
        self.category = category
        self.pinned = pinned
        self.reminderDaysBefore = reminderDaysBefore
        self.repeatsAnnually = repeatsAnnually
        self.expiry = expiry
    }

    /// 新增字段一律按缺省值解码，旧备份里没有这些键时仍能读回事件本身。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        direction = try container.decodeIfPresent(Direction.self, forKey: .direction) ?? .countdown
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .personal
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        reminderDaysBefore = try container.decodeIfPresent(Int.self, forKey: .reminderDaysBefore) ?? 0
        repeatsAnnually = try container.decodeIfPresent(Bool.self, forKey: .repeatsAnnually) ?? false
        expiry = try container.decodeIfPresent(Expiry.self, forKey: .expiry) ?? .continueCounting
    }

    /// 计数方向。倒数日等日期到来，累计日从日期往后记。
    ///
    /// 原始值是稳定的英文标识而不是中文文案：展示文字随时可能改措辞，
    /// 一旦参与持久化，改文案就等于丢数据。
    public enum Direction: String, Codable, Sendable, CaseIterable {
        case countdown
        case countUp

        public var title: String {
            switch self {
            case .countdown: "倒数"
            case .countUp: "累计"
            }
        }
    }

    public enum Category: String, Codable, Sendable, CaseIterable {
        case exam
        case birthday
        case enrollment
        case graduation
        case personal
        case custom

        /// 分类图标。使用系统符号，避免为每个分类绘制一份资源。
        public var symbol: String {
            switch self {
            case .exam: "checkmark.seal"
            case .birthday: "birthday.cake"
            case .enrollment: "graduationcap"
            case .graduation: "scroll"
            case .personal: "heart"
            case .custom: "star"
            }
        }

        public var title: String {
            switch self {
            case .exam: "考试"
            case .birthday: "生日"
            case .enrollment: "入学"
            case .graduation: "毕业"
            case .personal: "纪念日"
            case .custom: "其他"
            }
        }
    }

    /// 目标日期已过后怎么处理。
    public enum Expiry: String, Codable, Sendable, CaseIterable {
        /// 倒数日转为累计，继续显示天数。
        case continueCounting
        /// 从展示列表归档，管理列表里仍可找到并删除。
        case archive

        public var title: String {
            switch self {
            case .continueCounting: "继续计数"
            case .archive: "归档"
            }
        }
    }
}

/// 纪念事件的计数结果。
public struct MilestoneReading: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// 距目标日还有 n 天（n > 0）。
        case upcoming(days: Int)
        /// 就是今天。
        case today
        /// 已经过去 n 天（n > 0）。
        case past(days: Int)
    }

    public var state: State
    /// 实际参与计数的目标日期。每年重复时会滚动到今年或明年。
    public var effectiveDate: Date

    public init(state: State, effectiveDate: Date) {
        self.state = state
        self.effectiveDate = effectiveDate
    }

    /// 主文案里的天数，今天为 0。
    public var dayCount: Int {
        switch state {
        case .upcoming(let days): days
        case .today: 0
        case .past(let days): days
        }
    }

    /// 是否应当从展示列表隐藏。
    public func isHidden(expiry: Milestone.Expiry) -> Bool {
        if case .past = state, expiry == .archive { return true }
        return false
    }
}

public enum MilestoneCounter {
    /// 计数统一使用公历 + 应用固定时区。
    ///
    /// 课表本身按 `ScheduleRules.calendar` 的固定时区排课，纪念事件与之共用，
    /// 用户更换系统时区（例如出国）时天数不会突然跳变一天。存储的是绝对时刻，
    /// 这里只取「北京的这一天」，因此跨设备结果一致。
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    /// 计算一条纪念事件相对今天的读数。
    ///
    /// 计数一律按**日历日**，不使用小时差，避免「23:00 到次日 00:30 只差 1.5 小时
    /// 却被算成 2 天」这类错误。目标日与今天同日时返回 `.today`。
    ///
    /// - Parameters:
    ///   - milestone: 纪念事件。
    ///   - now: 参考时刻。
    ///   - calendar: 用于取日的日历。默认使用应用统一日历。
    public static func read(_ milestone: Milestone, now: Date,
                            calendar: Calendar = MilestoneCounter.calendar) -> MilestoneReading {
        let today = calendar.startOfDay(for: now)
        var target = calendar.startOfDay(for: milestone.date)

        if milestone.repeatsAnnually {
            target = annualOccurrence(of: milestone.date, relativeTo: today, calendar: calendar)
        }

        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        let state: MilestoneReading.State
        if days > 0 {
            state = .upcoming(days: days)
        } else if days == 0 {
            state = .today
        } else {
            state = .past(days: -days)
        }
        return MilestoneReading(state: state, effectiveDate: target)
    }

    /// 每年重复的事件落到哪一天。
    ///
    /// 返回「今年或明年中最近的、不早于今天」的那一次：今年的已经过去就指向明年，
    /// 于是跨年后今日页与组件自动跟随，不需要改写存储的日期。
    /// 2 月 29 日在平年落到 2 月 28 日，而不是整年跳过。
    public static func annualOccurrence(of date: Date, relativeTo today: Date,
                                        calendar: Calendar = MilestoneCounter.calendar) -> Date {
        let targetDay = calendar.startOfDay(for: today)
        let original = calendar.dateComponents([.month, .day], from: date)

        func occurrence(inYear year: Int) -> Date? {
            guard let month = original.month, let day = original.day else { return nil }
            var components = DateComponents(year: year, month: month, day: day)
            // Foundation 的日历是宽松的，2 月 29 日会被滚到 3 月 1 日；
            // 用回读的日号判断是否真的存在这一天。
            if let candidate = calendar.date(from: components),
               calendar.component(.day, from: candidate) == day {
                return calendar.startOfDay(for: candidate)
            }
            components.day = day - 1
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
        }

        let year = calendar.component(.year, from: targetDay)
        if let thisYear = occurrence(inYear: year), thisYear >= targetDay {
            return thisYear
        }
        return occurrence(inYear: year + 1) ?? targetDay
    }

    /// 是否应当在今天提醒。
    ///
    /// 只判断「提前天数是否正好命中」，不判断权限与实际投递 —— 那属于通知层。
    /// 每年重复的事件按滚动后的日期计算，因此跨年不会漏提醒、也不会提前一年误报。
    public static func shouldRemind(_ milestone: Milestone, now: Date,
                                    calendar: Calendar = MilestoneCounter.calendar) -> Bool {
        guard milestone.reminderDaysBefore > 0 else { return false }
        let reading = read(milestone, now: now, calendar: calendar)
        guard case .upcoming(let days) = reading.state else { return false }
        return days == milestone.reminderDaysBefore
    }

    /// 排序：未归档的在前，其次置顶的在前，再按距离今天的天数由近到远。
    ///
    /// 已归档的事件排到最后而不是直接丢弃，用户仍能在管理列表里看到并删除。
    public static func sorted(_ milestones: [Milestone], now: Date,
                              calendar: Calendar = MilestoneCounter.calendar) -> [Milestone] {
        milestones.sorted { lhs, rhs in
            let l = read(lhs, now: now, calendar: calendar)
            let r = read(rhs, now: now, calendar: calendar)
            let lHidden = l.isHidden(expiry: lhs.expiry)
            let rHidden = r.isHidden(expiry: rhs.expiry)
            if lHidden != rHidden { return !lHidden }
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            if l.dayCount != r.dayCount { return l.dayCount < r.dayCount }
            return lhs.title < rhs.title
        }
    }
}
