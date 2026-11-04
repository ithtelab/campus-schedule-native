import Foundation

/// 把解析出的课程落到学期模型上。
///
/// 导入前必须让用户看到将要发生什么，因此这里只做纯转换与冲突检测，
/// 不直接改状态。
public enum ImportPlanner {

    /// 一次导入将产生的结果。
    public struct Plan: Equatable, Sendable {
        public var courses: [ParsedCourse]
        /// 与现有课程时间冲突的条目（导入后会重叠）。
        public var conflicts: [Conflict]
        /// 导入后会被替换掉的现有课程数量。
        public var replacedCount: Int
        /// 解析阶段的提示。
        public var warnings: [String]
        public var targetTermID: String? = nil

        public init(courses: [ParsedCourse], conflicts: [Conflict],
                    replacedCount: Int, warnings: [String]) {
            self.courses = courses
            self.conflicts = conflicts
            self.replacedCount = replacedCount
            self.warnings = warnings
        }

        public var summary: String {
            var parts = ["\(courses.count) 门课程"]
            if replacedCount > 0 { parts.append("替换现有 \(replacedCount) 门") }
            if !conflicts.isEmpty { parts.append("\(conflicts.count) 处时间重叠") }
            return parts.joined(separator: " · ")
        }

        public var isApplicable: Bool { !courses.isEmpty }
    }

    /// 两条课程在时间上重叠。
    public struct Conflict: Equatable, Sendable {
        public var incoming: ParsedCourse
        public var existingTitle: String
        public var weekday: Int
        public var detail: String
    }

    /// 生成导入方案。
    ///
    /// - Parameters:
    ///   - parsed: 解析结果。
    ///   - existing: 当前学期的课程，用于冲突检测与替换计数。
    ///   - totalWeeks: 学期总周数，用于校验周次。
    /// - Parameter periodCount: 当前学期配置的节次数。超过它的课程无法落到课表上，
    ///   必须在这里就排除并告知用户，而不是等到写入时静默丢弃。
    public static func plan(_ parsed: ParseOutcome, existing: [ParsedCourse],
                            totalWeeks: Int, periodCount: Int = 10) -> Plan {
        var normalized: [ParsedCourse] = []
        var warnings = parsed.warnings
        var dropped = 0
        var outOfRange = 0

        for course in parsed.courses {
            // 周次为空表示整学期；超出学期范围的周次裁剪掉。
            var weeks = course.weeks
            if !weeks.isEmpty {
                let clamped = weeks.filter { $0 >= 1 && $0 <= totalWeeks }
                if clamped.isEmpty {
                    // 所有周次都超出范围，说明这门课不属于当前学期。
                    dropped += 1
                    continue
                }
                if clamped.count != weeks.count { weeks = clamped }
            }
            guard course.weekday >= 0, course.weekday <= 6,
                  course.startPeriod >= 1, course.endPeriod >= course.startPeriod else {
                dropped += 1
                continue
            }
            // 节次超出本学期作息表的课程无法排进网格，先在预览阶段剔除。
            guard course.endPeriod <= periodCount else {
                outOfRange += 1
                continue
            }
            var fixed = course
            fixed.weeks = weeks
            normalized.append(fixed)
        }
        if dropped > 0 { warnings.append("有 \(dropped) 门课程的时间或周次不在本学期内，已忽略。") }
        if outOfRange > 0 {
            warnings.append("有 \(outOfRange) 门课程超出本学期的 \(periodCount) 节作息，已忽略。可在「学期与作息」里增加节次后重新导入。")
        }

        var seen: Set<ParsedCourse> = []
        normalized = normalized.filter { seen.insert($0).inserted }
        // 同一身份但信息矛盾时，不以数组顺序偷偷决定保留哪一份。
        let grouped = Dictionary(grouping: normalized) { course in
            let weeks = course.weeks.isEmpty ? Set(1...max(1, totalWeeks)) : course.weeks
            return key(course) + "|" + weeks.sorted().map(String.init).joined(separator: ",")
        }
        let ambiguous = Set(grouped.filter { $0.value.count > 1 }.values.flatMap { $0 })
        if !ambiguous.isEmpty {
            warnings.append("同一课程时段存在不同的教师或教室信息，已跳过冲突条目，请核对原始课表。")
            normalized.removeAll { ambiguous.contains($0) }
        }
        var conflicts: [Conflict] = []
        for incoming in normalized {
            for other in existing {
                guard other.weekday == incoming.weekday else { continue }
                if sameIdentity(incoming, other, totalWeeks: totalWeeks) { continue }
                guard overlaps(incoming, other) else { continue }
                // 周次不相交时不算冲突：单双周分开的课程本就是设计如此。
                if !incoming.weeks.isEmpty, !other.weeks.isEmpty,
                   incoming.weeks.isDisjoint(with: other.weeks) { continue }
                conflicts.append(Conflict(
                    incoming: incoming,
                    existingTitle: other.title,
                    weekday: incoming.weekday,
                    detail: "周\(weekdayName(incoming.weekday)) 第\(incoming.startPeriod)-\(incoming.endPeriod)节"
                ))
            }
        }

        // 同名同时间视为同一门课，导入时覆盖而不是新增。
        let replaced = normalized.filter { replacementIndex(for: $0, in: existing, totalWeeks: totalWeeks) != nil }.count
        return Plan(courses: normalized, conflicts: conflicts,
                    replacedCount: replaced, warnings: warnings)
    }

    /// 课程的身份键。
    ///
    /// 教学班必须参与：教师端同一门课、同一时段、同一教室但教学班不同，是两门课。
    /// 不带教学班会让后导入的条目覆盖前一条，任课统计因此少算。
    static func key(_ course: ParsedCourse) -> String {
        "\(course.title)|\(course.weekday)|\(course.startPeriod)|\(course.endPeriod)|\(course.teachingClass)"
    }

    /// 周次不同的记录不自动覆盖；避免单双周后写的条目吃掉先写的条目。
    public static func sameIdentity(_ lhs: ParsedCourse, _ rhs: ParsedCourse, totalWeeks: Int) -> Bool {
        func weeks(_ value: ParsedCourse) -> Set<Int> {
            value.weeks.isEmpty ? Set(1...max(1, totalWeeks)) : value.weeks
        }
        return key(lhs) == key(rhs) && weeks(lhs) == weeks(rhs)
    }

    public static func replacementIndex(for course: ParsedCourse, in existing: [ParsedCourse], totalWeeks: Int) -> Int? {
        existing.firstIndex { sameIdentity(course, $0, totalWeeks: totalWeeks) }
    }

    static func overlaps(_ lhs: ParsedCourse, _ rhs: ParsedCourse) -> Bool {
        lhs.startPeriod <= rhs.endPeriod && rhs.startPeriod <= lhs.endPeriod
    }

    public static func weekdayName(_ weekday: Int) -> String {
        ["一", "二", "三", "四", "五", "六", "日"][safe: weekday] ?? "?"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
