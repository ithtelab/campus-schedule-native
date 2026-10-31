import Foundation

/// 一门被解析出来的课程，尚未绑定到具体学期。
public struct ParsedCourse: Equatable, Sendable {
    public var title: String
    public var teacher: String
    public var room: String
    /// 0 = 周一。
    public var weekday: Int
    public var startPeriod: Int
    public var endPeriod: Int
    /// 周次集合；空表示未指定，调用方按整学期处理。
    public var weeks: Set<Int>

    public init(title: String, teacher: String = "", room: String = "",
                weekday: Int, startPeriod: Int, endPeriod: Int, weeks: Set<Int> = []) {
        self.title = title
        self.teacher = teacher
        self.room = room
        self.weekday = weekday
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.weeks = weeks
    }
}

/// 一次解析的结果，包含失败原因，便于告诉用户「哪里看不出来」而不是笼统失败。
public struct ParseOutcome: Equatable, Sendable {
    public var courses: [ParsedCourse]
    public var warnings: [String]

    public init(courses: [ParsedCourse], warnings: [String] = []) {
        self.courses = courses
        self.warnings = warnings
    }

    public static let empty = ParseOutcome(courses: [], warnings: [])
}

public enum ParseFailure: LocalizedError, Equatable {
    case noTimetableFound
    case noCoursesRecognised
    case allRowsUnparseable(Int)

    public var errorDescription: String? {
        switch self {
        case .noTimetableFound:
            "没有在当前页面找到课表结构。请确认复制的是课表页面，而不是登录页或首页。"
        case .noCoursesRecognised:
            "找到了表格，但没有识别出任何课程。可能是页面需要先登录，或课表用了图片渲染。"
        case .allRowsUnparseable(let count):
            "识别到 \(count) 个单元格，但没有一个能确定星期和节次。请换一种导入方式。"
        }
    }
}

/// 与界面无关的课表文本解析。
///
/// 设计目标是覆盖尽可能多的教务系统而不为每所学校写选择器：
/// 教务课表在结构上高度相似 —— 行是节次、列是星期、单元格里是「课程名/教师/教室/周次」。
/// 因此这里识别**结构**而不是识别具体的 HTML 类名。
///
/// 所有解析都是纯函数，可以脱离网络与界面单独测试。
public enum TimetableTextParser {

    // MARK: - 周次

    /// 解析「1-16周」「1-8周(单)」「第1-16周」「1,3,5-7周」「单周」「1~16」等写法。
    ///
    /// 返回 nil 表示文本里没有周次信息（不是错误）；返回空集合表示写了周次但无法理解。
    public static func parseWeeks(_ text: String, totalWeeks: Int = 20) -> Set<Int>? {
        guard !text.isEmpty else { return nil }
        let normalized = text
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "～", with: "-")
            .replacingOccurrences(of: "~", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "至", with: "-")
            .replacingOccurrences(of: " ", with: "")

        // 只在确实出现「周」或范围/单双周标记时才认为有周次信息，
        // 否则教室号里的数字会被误当成周次。
        let mentionsWeeks = normalized.contains("周")
            || normalized.contains("单") || normalized.contains("双")
        guard mentionsWeeks else { return nil }

        // 去掉「周」字后按逗号分段，逐段处理。
        let body = normalized
            .replacingOccurrences(of: "第", with: "")
            .replacingOccurrences(of: "周", with: "")
        let upperBound = min(max(totalWeeks, 1), 53)
        var result: Set<Int> = []
        // 单双周标记作用于整段，例如「1-16单」或「(单)」。
        let isOddOnly = body.contains("单")
        let isEvenOnly = body.contains("双")
        let cleaned = body
            .replacingOccurrences(of: "(单)", with: "")
            .replacingOccurrences(of: "(双)", with: "")
            .replacingOccurrences(of: "单", with: "")
            .replacingOccurrences(of: "双", with: "")

        for segment in cleaned.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "、" }) {
            let piece = String(segment)
            guard !piece.isEmpty else { continue }
            if let range = parseRange(piece) {
                // 严格限制在学期范围内，越界周次丢弃而不是保留。
                for week in range where week >= 1 && week <= upperBound {
                    if isOddOnly && week % 2 == 0 { continue }
                    if isEvenOnly && week % 2 == 1 { continue }
                    result.insert(week)
                }
            }
        }
        return result.isEmpty ? [] : result
    }

    /// 「1-16」或「3」这样的片段。
    private static func parseRange(_ piece: String) -> ClosedRange<Int>? {
        let parts = piece.split(separator: "-", omittingEmptySubsequences: false)
        if parts.count == 2, let lower = Int(parts[0]), let upper = Int(parts[1]), lower <= upper {
            return lower...upper
        }
        if parts.count == 1, let single = Int(piece), single > 0 {
            return single...single
        }
        return nil
    }

    // MARK: - 节次

    /// 解析「第1-2节」「1-2节」「1,2节」「3节」。
    ///
    /// 只在文本中定位节次片段本身，而不是把整行数字都当候选：
    /// 整行里还含周次和房间号，直接分词会把它们算进来。
    public static func parsePeriods(_ text: String) -> (start: Int, end: Int)? {
        let normalized = text
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "～", with: "-")
            .replacingOccurrences(of: "~", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        // 优先匹配带「节」的明确写法。
        let explicit = "第?([0-9]{1,2})(?:[-–,]([0-9]{1,2}))?节"
        if let match = firstMatch(explicit, in: normalized) {
            let start = match.0
            let end = match.1 ?? start
            guard start > 0, end >= start, end <= 20 else { return nil }
            return (start, end)
        }
        // 没有「节」字时，只有整段就是一个纯节次表达式才接受，
        // 否则整行文本会被误判（例如「周一 高等数学 A302」）。
        let trimmed = normalized.trimmingCharacters(in: .whitespaces)
        let bare = "^第?([0-9]{1,2})(?:[-–]([0-9]{1,2}))?$"
        if let match = firstMatch(bare, in: trimmed) {
            let start = match.0
            let end = match.1 ?? start
            guard start > 0, end >= start, end <= 20 else { return nil }
            return (start, end)
        }
        return nil
    }

    /// 用 NSRegularExpression 取出第一个匹配的前两个捕获组。
    private static func firstMatch(_ pattern: String, in text: String) -> (Int, Int?)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        func group(_ index: Int) -> Int? {
            guard index < match.numberOfRanges,
                  let captured = Range(match.range(at: index), in: text) else { return nil }
            return Int(text[captured])
        }
        guard let first = group(1) else { return nil }
        return (first, group(2))
    }

    // MARK: - 星期

    private static let weekdayMarkers: [(String, Int)] = [
        ("星期一", 0), ("周一", 0), ("礼拜一", 0), ("mon", 0),
        ("星期二", 1), ("周二", 1), ("礼拜二", 1), ("tue", 1),
        ("星期三", 2), ("周三", 2), ("礼拜三", 2), ("wed", 2),
        ("星期四", 3), ("周四", 3), ("礼拜四", 3), ("thu", 3),
        ("星期五", 4), ("周五", 4), ("礼拜五", 4), ("fri", 4),
        ("星期六", 5), ("周六", 5), ("礼拜六", 5), ("sat", 5),
        ("星期日", 6), ("星期天", 6), ("周日", 6), ("周天", 6), ("sun", 6),
    ]

    public static func parseWeekday(_ text: String) -> Int? {
        let lowered = text.lowercased()
        return weekdayMarkers.first { lowered.contains($0.0) }?.1
    }

    // MARK: - 课程单元格

    /// 从一段单元格文本中拆出课程、教师、教室与周次。
    ///
    /// 教务系统通常用换行或空格分隔这几项，但顺序不固定，所以用启发式：
    /// 含「周」的行是周次，含「楼/室/馆/教室」或数字+字母组合的是教室，
    /// 含「老师/教授/讲师」或 2–4 个汉字且不像课程名的是教师，剩下的第一行是课程名。
    public static func parseCourseCell(_ raw: String, totalWeeks: Int = 20) -> ParsedCourse? {
        // 单元格既可能换行分隔，也可能用空格分隔（例如从整行复制的文本）。
        // 统一按行和多余空白切开，再逐片分类。
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        // 每行再切成词：含周次的词、含房间特征的词可以独立成片，
        // 其余合并回一个「标题片段」，避免把带空格的课程名拆碎。
        var tokens: [String] = []
        for line in lines {
            let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.count < 2 { tokens.append(line); continue }
            var pending: [String] = []
            var sawTitle = false
            for word in words {
                // 教师判定只在已经出现过课程名之后才可信：
                // 「线性代数」与「张老师」都是汉字，靠位置区分而不是靠字形。
                let standalone = parseWeeks(word, totalWeeks: totalWeeks) != nil
                    || (sawTitle && looksLikeRoom(word))
                    || (sawTitle && isTeacherName(word))
                if standalone {
                    if !pending.isEmpty { tokens.append(pending.joined(separator: " ")); pending = [] }
                    tokens.append(word)
                    sawTitle = true
                } else {
                    pending.append(word)
                }
            }
            if !pending.isEmpty { tokens.append(pending.joined(separator: " ")) }
        }
        guard !tokens.isEmpty else { return nil }

        var weeks: Set<Int> = []
        var hasWeeks = false
        var room = ""
        var teacher = ""
        var titleParts: [String] = []
        var remainder: [String] = []

        // 先分离周次；周次片段可能同时包含节次信息（如「1-16周(单)」）。
        for token in tokens {
            if let parsed = parseWeeks(token, totalWeeks: totalWeeks) {
                if !parsed.isEmpty {
                    // 同一门课可能有多段周次（单双周分开写），合并而不是覆盖。
                    if hasWeeks { weeks.formUnion(parsed) } else { weeks = parsed; hasWeeks = true }
                }
                continue
            }
            remainder.append(token)
        }

        for token in remainder {
            if room.isEmpty, looksLikeRoom(token) { room = token; continue }
            titleParts.append(token)
        }
        guard !titleParts.isEmpty else { return nil }
        // 第一片一定是课程名：教务系统总是先写课程，再写教师和教室。
        // 教师只从后续片段里取，避免「线性代数」这种四字课程名被当成教师。
        let title = titleParts[0]
        if room.isEmpty, titleParts.count > 1, looksLikeRoom(titleParts[1]) { room = titleParts[1] }
        if teacher.isEmpty {
            teacher = titleParts.dropFirst().first(where: isTeacherName) ?? ""
        }
        guard !title.isEmpty else { return nil }
        return ParsedCourse(title: title, teacher: teacher, room: room,
                            weekday: 0, startPeriod: 1, endPeriod: 1,
                            weeks: hasWeeks ? weeks : [])
    }

    /// 教师名的常见形态：「X老师」「X教授」，或 2–4 个汉字且不含课程常见词。
    static func isTeacherName(_ text: String) -> Bool {
        if text.hasSuffix("老师") || text.hasSuffix("教师") || text.hasSuffix("教授") || text.hasSuffix("讲师") {
            return true
        }
        // 用 Unicode 标量区间判断是否全为汉字，避免依赖可能不存在的字符属性。
        let allHan = text.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
        guard allHan, (2...4).contains(text.count) else { return false }
        // 「数学」「英语」这类也由 2 个汉字组成，但它们通常作为课程名出现。
        let courseHints = ["数学", "英语", "物理", "化学", "体育", "思政", "历史", "地理", "生物",
                           "程序", "设计", "写作", "导论", "实验", "原理", "分析", "概论"]
        return !courseHints.contains { text.contains($0) }
    }

    static func looksLikeRoom(_ text: String) -> Bool {
        if text.contains("楼") || text.contains("室") || text.contains("馆") || text.contains("教室")
            || text.contains("实验") || text.contains("机房") || text.contains("操场") {
            return true
        }
        // 「A302」「B-205」「1-201」这类编号。
        let pattern = "^[A-Za-z]?[-]?[0-9]{2,4}[A-Za-z]?$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - 表格式课表

    /// 从二维网格解析课表。
    ///
    /// 输入是已经按行列切好的单元格文本，因此不依赖 HTML 解析库即可测试与复用。
    /// 表头行（含星期名）用于确定每一列对应周几；首列用于确定每一行对应第几节。
    public static func parseGrid(_ rows: [[String]], totalWeeks: Int = 20) -> ParseOutcome {
        var courses: [ParsedCourse] = []
        var warnings: [String] = []

        // 找出表头行：含至少 3 个不同星期名的行。
        var headerRowIndex: Int?
        var columnWeekdays: [Int: Int] = [:]
        for (index, row) in rows.enumerated() {
            let mapped = row.enumerated().compactMap { offset, cell -> (Int, Int)? in
                guard let day = parseWeekday(cell) else { return nil }
                return (offset, day)
            }
            let uniqueDays = Set(mapped.map(\.1))
            if uniqueDays.count >= 3 {
                headerRowIndex = index
                for (column, day) in mapped { columnWeekdays[column] = day }
                break
            }
        }

        let dataStart = (headerRowIndex ?? -1) + 1
        guard dataStart < rows.count else { return ParseOutcome(courses: [], warnings: ["只找到表头，没有课程数据。"]) }

        var skipped = 0
        for row in rows[dataStart...] {
            // 行首通常写着节次，例如「1-2节」「第3节」或纯数字。
            let rowPeriod = row.first.flatMap { parsePeriods($0) }
            for (column, cell) in row.enumerated() {
                guard !cell.isEmpty else { continue }
                // 表头列没有对应星期就跳过（例如首列是节次）。
                guard let weekday = columnWeekdays[column] else { continue }
                // 单元格里若自带星期与节次，优先采用单元格自己的信息。
                let cellDay = parseWeekday(cell) ?? weekday
                // 只接受带「节」字的节次说明，否则「1-16周」里的数字会被当成节次。
                let cellPeriod = cellContainsPeriod(cell) ? parsePeriods(cell) : nil
                let period = cellPeriod ?? rowPeriod
                guard let period, let course = parseCourseCell(cell, totalWeeks: totalWeeks) else {
                    skipped += 1
                    continue
                }
                var resolved = course
                resolved.weekday = cellDay
                resolved.startPeriod = period.start
                resolved.endPeriod = period.end
                courses.append(resolved)
            }
        }

        if courses.isEmpty {
            return ParseOutcome(courses: [], warnings: [
                skipped > 0 ? "识别到 \(skipped) 个单元格，但都没能确定星期与节次。" : "表格里没有课程内容。"
            ])
        }
        if skipped > 0 { warnings.append("有 \(skipped) 个单元格无法识别，已跳过。") }
        return ParseOutcome(courses: deduplicate(courses), warnings: warnings)
    }

    /// 单元格里是否明确写了节次。用于区分「第3-4节」与周次「3-4周」。
    static func cellContainsPeriod(_ cell: String) -> Bool {
        cell.contains("节")
    }

    /// 同一门课可能出现在多个单元格（如单双周分开写），合并完全相同的条目。
    static func deduplicate(_ courses: [ParsedCourse]) -> [ParsedCourse] {
        var seen = Set<String>()
        var result: [ParsedCourse] = []
        for course in courses {
            let key = "\(course.title)|\(course.weekday)|\(course.startPeriod)|\(course.endPeriod)|\(course.room)|\(course.weeks.sorted())"
            if seen.insert(key).inserted { result.append(course) }
        }
        return result
    }

    // MARK: - 自由文本

    /// 从整页复制的文本里逐行抽取课程。
    ///
    /// 这是最后一道兜底：即使拿不到表格结构，只要每行包含「星期 + 节次 + 课程名」就能导入。
    public static func parseLines(_ text: String, totalWeeks: Int = 20) -> ParseOutcome {
        var courses: [ParsedCourse] = []
        var skipped = 0
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let day = parseWeekday(line), let period = parsePeriods(line) else { continue }
            // 先整段去掉节次写法，再移除星期名，避免「第1-2节」被拆散后残留数字。
            var remainder = line
            if let range = remainder.range(of: "第?[0-9]{1,2}([-–,][0-9]{1,2})?节", options: .regularExpression) {
                remainder.replaceSubrange(range, with: " ")
            }
            for (marker, _) in weekdayMarkers {
                remainder = remainder.replacingOccurrences(of: marker, with: " ")
            }
            guard let course = parseCourseCell(remainder, totalWeeks: totalWeeks) else {
                skipped += 1; continue
            }
            var resolved = course
            resolved.weekday = day
            resolved.startPeriod = period.start
            resolved.endPeriod = period.end
            courses.append(resolved)
        }
        if courses.isEmpty {
            return ParseOutcome(courses: [], warnings: [
                skipped > 0 ? "有 \(skipped) 行包含星期与节次，但没解析出课程名。" : "没有找到同时包含星期和节次的行。"
            ])
        }
        var warnings: [String] = []
        if skipped > 0 { warnings.append("有 \(skipped) 行无法识别，已跳过。") }
        return ParseOutcome(courses: deduplicate(courses), warnings: warnings)
    }
}
