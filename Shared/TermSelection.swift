import Foundation

/// 学期的元信息。课程与调课记录体积随学期增长，放在存储层按学期分开保存，
/// 这里只保留判断「当前学期是哪个」所需的字段。
public struct TermSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var startDate: Date
    public var totalWeeks: Int

    public init(id: String, name: String, startDate: Date, totalWeeks: Int) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
    }

    /// 学期最后一天的结束时刻。第 n 周的最后一天是开学后 n*7-1 天。
    public var endDate: Date {
        let calendar = ScheduleRules.calendar
        let lastDay = calendar.date(byAdding: .day, value: max(0, totalWeeks * 7 - 1),
                                    to: calendar.startOfDay(for: startDate)) ?? startDate
        return calendar.date(byAdding: .second, value: 86_399, to: lastDay) ?? lastDay
    }

    public func contains(_ date: Date) -> Bool {
        let day = ScheduleRules.calendar.startOfDay(for: date)
        return day >= ScheduleRules.calendar.startOfDay(for: startDate) && date <= endDate
    }
}

public enum TermSelection {
    /// 按开学日期从新到旧排序，界面列表使用这个顺序。
    public static func sorted(_ terms: [TermSummary]) -> [TermSummary] {
        terms.sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate { return lhs.name < rhs.name }
            return lhs.startDate > rhs.startDate
        }
    }

    /// 在给定日期时处于进行中的学期。
    ///
    /// 学期之间可以有假期空档，也可能因为排错而重叠；重叠时取开学最晚的那个，
    /// 因为学生通常刚切换到新学期，旧学期数据不该抢占当前视图。
    public static func current(in terms: [TermSummary], on date: Date) -> TermSummary? {
        terms.filter { $0.contains(date) }
            .max { $0.startDate < $1.startDate }
    }

    /// 没有进行中的学期时应当显示哪个：优先最近的未来学期，其次最近的过去学期。
    /// 假期里打开 App 需要看到即将开学或刚结束的课表，而不是空白。
    public static func fallback(in terms: [TermSummary], on date: Date) -> TermSummary? {
        if let upcoming = terms.filter({ $0.startDate > date }).min(by: { $0.startDate < $1.startDate }) {
            return upcoming
        }
        return terms.filter { $0.endDate < date }.max { $0.startDate < $1.startDate }
    }

    /// 界面打开时应当显示的学期。
    public static func preferred(in terms: [TermSummary], on date: Date) -> TermSummary? {
        current(in: terms, on: date) ?? fallback(in: terms, on: date)
    }

    /// 生成一个不与现有学期冲突的默认名称，例如「2027 春季学期 2」。
    public static func uniqueName(_ base: String, existing: [TermSummary]) -> String {
        let taken = Set(existing.map(\.name))
        guard taken.contains(base) else { return base }
        var index = 2
        while taken.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }

    /// 新学期的默认开学日期：延续上一个学期结束后的第一个周一。
    public static func suggestedStart(after terms: [TermSummary]) -> Date {
        let calendar = ScheduleRules.calendar
        guard let latest = sorted(terms).first else {
            // 没有历史时，用距离今天最近的周一。
            let today = calendar.startOfDay(for: Date())
            let weekday = calendar.component(.weekday, from: today)
            let offset = (3 - weekday + 7) % 7  // 周一是 weekday 2
            return calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        let after = calendar.date(byAdding: .day, value: 7, to: latest.endDate) ?? latest.endDate
        let weekday = calendar.component(.weekday, from: after)
        let offset = (3 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: after)) ?? after
    }

    /// 删除某学期后该选中谁。
    public static func afterRemoving(_ id: String, from terms: [TermSummary], on date: Date) -> TermSummary? {
        preferred(in: terms.filter { $0.id != id }, on: date)
    }
}
