import Foundation

/// 课程搜索。
///
/// 一个学期有几十门课、分散在十几周里，逐周翻找不可行。搜索按课程名、教师、
/// 教室匹配，并给出每周的上课时间，结果按名字分组而不是按周次展开 ——
/// 学生找的是「那门课在哪几天」，不是「第几周有这门课」。
public enum CourseSearch {

    /// 一条搜索结果：一门课及其全部上课时段。
    public struct Variant: Equatable, Sendable, Identifiable {
        public let id: String
        public let slot: String
        public let weeksText: String
    }

    public struct Hit: Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var teacher: String
        public var room: String
        public var variants: [Variant]
        public var slots: [String] { variants.map(\.slot) }
    }

    private struct GroupKey: Hashable {
        let title: String
        let teacher: String
        let room: String
    }

    /// 搜索课程。
    ///
    /// - Parameters:
    ///   - courses: 候选课程。
    ///   - query: 查询串，空串返回全部（按名称排序）。
    ///   - totalWeeks: 学期总周数，用于生成周次说明。
    public static func search(_ courses: [SearchableCourse], query: String,
                              totalWeeks: Int, limit: Int = 40) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = trimmed.isEmpty ? courses : courses.filter { course in
            course.title.localizedCaseInsensitiveContains(trimmed)
                || course.teacher.localizedCaseInsensitiveContains(trimmed)
                || course.room.localizedCaseInsensitiveContains(trimmed)
        }

        // 同名同师同地点视为同一门课（可能分布在多个时段），合并成一条。
        let grouped = Dictionary(grouping: matched) { course in
            GroupKey(title: course.title, teacher: course.teacher, room: course.room)
        }

        let hits: [Hit] = grouped.compactMap { key, group in
            let variants = group.sorted {
                ($0.weekday, $0.startPeriod, $0.endPeriod, $0.id) < ($1.weekday, $1.startPeriod, $1.endPeriod, $1.id)
            }.map { course in
                Variant(id: course.id, slot: "\(weekdayName(course.weekday)) 第\(course.startPeriod)–\(course.endPeriod)节",
                        weeksText: weeksText(course.weeks, totalWeeks: totalWeeks))
            }
            guard let first = variants.first else { return nil }
            return Hit(id: first.id, title: key.title, teacher: key.teacher, room: key.room, variants: variants)
        }
        return Array(hits.sorted { lhs, rhs in
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            if lhs.teacher != rhs.teacher { return lhs.teacher < rhs.teacher }
            return lhs.room < rhs.room
        }.prefix(limit))
    }

    /// 周次说明。整学期不啰嗦，单双周直接说。
    public static func weeksText(_ weeks: Set<Int>, totalWeeks: Int) -> String {
        guard !weeks.isEmpty else { return "整学期" }
        if weeks.count >= totalWeeks { return "整学期" }
        let odd = Set(stride(from: 1, through: totalWeeks, by: 2))
        let even = Set(stride(from: 2, through: totalWeeks, by: 2))
        if weeks == odd { return "单周" }
        if weeks == even { return "双周" }

        let sorted = weeks.sorted()
        var parts: [String] = []
        var start = sorted[0]
        var previous = sorted[0]
        for week in sorted.dropFirst() {
            if week == previous + 1 { previous = week; continue }
            parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
            start = week; previous = week
        }
        parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
        return parts.joined(separator: ",") + " 周"
    }

    public static func weekdayName(_ weekday: Int) -> String {
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        guard weekday >= 0, weekday < names.count else { return "未知" }
        return names[weekday]
    }
}

/// 搜索只关心这几个字段，避免把整个视图模型带进 Shared。
public struct SearchableCourse: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var teacher: String
    public var room: String
    public var weekday: Int
    public var startPeriod: Int
    public var endPeriod: Int
    public var weeks: Set<Int>

    public init(id: String, title: String, teacher: String, room: String,
                weekday: Int, startPeriod: Int, endPeriod: Int, weeks: Set<Int>) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.room = room
        self.weekday = weekday
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weeks = weeks
    }
}
