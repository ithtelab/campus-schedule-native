import Foundation

/// 特定教务系统的页面特征与提取策略。
///
/// 大部分学校能用通用表格提取处理。少数系统把课表渲染成 `<div>` 网格或用内嵌
/// JSON 传递数据，HTML 里没有 `<table>`，需要专门的提取入口。
///
/// 这里只识别**系统类型**并给出提取提示，真正的解析仍复用文本/网格解析器 ——
/// 保持一条解析路径，避免为每所学校维护解析逻辑。
public enum AcademicSystemProfile {
    public enum WeekdayNumbering: String, CaseIterable, Hashable, Sendable {
        case automatic, mondayOne, mondayZero
        public var title: String {
            switch self {
            case .automatic: "自动识别"
            case .mondayOne: "周一对应 1"
            case .mondayZero: "周一对应 0"
            }
        }
    }

    /// 网页提取与 HTML 文件导入共用，避免把原始 HTML 当作纯文本解析。
    public static func parsePage(_ html: String, totalWeeks: Int, numbering: WeekdayNumbering = .automatic) -> ParseOutcome {
        var warnings: [String] = []
        for candidate in embeddedJSON(from: html) {
            if let outcome = courses(fromEmbeddedJSON: candidate, totalWeeks: totalWeeks, numbering: numbering) {
                if !outcome.courses.isEmpty { return outcome }
                warnings.append(contentsOf: outcome.warnings)
            }
        }
        let outcomes = HTMLTableExtractor.extractTables(from: html).map {
            TimetableTextParser.parseGrid($0, totalWeeks: totalWeeks)
        }
        if let best = outcomes.max(by: { $0.courses.count < $1.courses.count }), !best.courses.isEmpty {
            return best
        }
        // 保留块之间的换行，同时去掉脚本和样式，避免误把页面代码识别为课程。
        let visibleHTML = html.replacingOccurrences(
            of: #"<(script|style)\b[^>]*>[\s\S]*?</\1\s*>"#, with: "",
            options: [.regularExpression, .caseInsensitive])
        var fallback = TimetableTextParser.parseLines(HTMLTableExtractor.cellText(visibleHTML), totalWeeks: totalWeeks)
        if fallback.courses.isEmpty { fallback.warnings = warnings + fallback.warnings }
        return fallback
    }

    /// 页面里的内嵌 JSON 候选容器。正方、URP 等把课表数据放在 `var xxx = {...}`。
    public static func embeddedJSON(from html: String) -> [String] {
        var results: [String] = []
        // 只定位赋值开头，再扫描成对括号，不能让 weeks 数组提前截断整个 JSON。
        let patterns = [
            #"(?:var|let|const)\s+\w*(?:course|kb|schedule|timetable|data)\w*\s*=\s*"#,
            #"window\.\w+\s*=\s*"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            for match in regex.matches(in: html, range: range) {
                guard let assignment = Range(match.range, in: html),
                      let candidate = balancedJSON(in: html, from: assignment.upperBound) else { continue }
                // 太短的多半不是课表数据，过滤噪音。
                if candidate.count > 40, !results.contains(candidate) { results.append(candidate) }
                if results.count == 64 { return results }
            }
        }
        return results
    }

    private static func balancedJSON(in text: String, from start: String.Index) -> String? {
        guard start < text.endIndex, text[start] == "[" || text[start] == "{" else { return nil }
        var stack: [Character] = [], quoted = false, escaped = false
        for index in text[start...].indices {
            let character = text[index]
            if quoted {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { quoted = false }
                continue
            }
            if character == "\"" { quoted = true; continue }
            if character == "[" || character == "{" { stack.append(character); if stack.count > 64 { return nil } }
            if character == "]" || character == "}" {
                guard let open = stack.popLast(), (open == "[" && character == "]") || (open == "{" && character == "}") else { return nil }
                if stack.isEmpty { return String(text[start...index]) }
            }
        }
        return nil
    }

    /// 从内嵌 JSON 里按常见字段名提取课程，覆盖正方与 URP 的命名习惯。
    public static func courses(fromEmbeddedJSON json: String, totalWeeks: Int,
                               numbering: WeekdayNumbering = .mondayOne) -> ParseOutcome? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let objects = ShareCodeParser.collectObjects(root)

        let dayKeys = ["weekday", "weekDay", "xqj", "dayOfWeek", "day"]
        let startKeys = ["startNode", "startSection", "jcs", "beginNumber", "start"]
        let endKeys = ["endNode", "endSection", "jce", "end"]
        let titleKeys = ["courseName", "kcmc", "name", "title"]
        let roomKeys = ["room", "place", "cdmc", "location", "jsmc"]
        let teacherKeys = ["teacher", "xm", "teacherName", "jsxm", "teacher_names"]
        let weekKeys = ["weeks", "week", "zcd", "weekRange"]

        func first(_ object: [String: Any], _ keys: [String]) -> Any? {
            for key in keys where object[key] != nil { return object[key] }
            return nil
        }

        let scheduleObjects = objects.filter { first($0, titleKeys) is String && first($0, startKeys) != nil }
        let days = scheduleObjects.compactMap { ShareCodeParser.intValue(first($0, dayKeys)) }
        let resolved: WeekdayNumbering
        if numbering != .automatic { resolved = numbering }
        else if days.contains(0) && days.contains(7) {
            return ParseOutcome(courses: [], warnings: ["课表混用了不同的星期格式，请核对数据后再导入。"])
        }
        else if days.contains(0) && !days.contains(7) { resolved = .mondayZero }
        else if days.contains(7) && !days.contains(0) { resolved = .mondayOne }
        else if !scheduleObjects.isEmpty && scheduleObjects.allSatisfy({ $0["xqj"] != nil }) { resolved = .mondayOne }
        else {
            return ParseOutcome(courses: [], warnings: ["无法确定课表的星期格式，请在「星期格式」中选择周一对应 0 还是 1，再重新提取。"])
        }

        var courses: [ParsedCourse] = []
        var skipped = 0
        for object in objects {
            guard let titleValue = first(object, titleKeys) as? String, !titleValue.isEmpty,
                  let dayValue = ShareCodeParser.intValue(first(object, dayKeys)),
                  let startValue = ShareCodeParser.intValue(first(object, startKeys)) else { continue }
            // 没有节次结束信息时按两节处理，这是最常见的课时长度。
            let endValue = ShareCodeParser.intValue(first(object, endKeys)) ?? (startValue + 1)
            // 正方等系统星期可能是 1…7（周一 = 1），也可能是 0…6。
            let weekday = resolved == .mondayZero ? dayValue : dayValue - 1
            guard (0...6).contains(weekday), startValue >= 1, endValue >= startValue else {
                skipped += 1; continue
            }
            let weeks: Set<Int>
            if let raw = first(object, weekKeys) {
                let parsed: [Int]
                if let array = raw as? [Any] { parsed = array.compactMap { ShareCodeParser.intValue($0) } }
                else {
                    let text = String(describing: raw)
                    if let weeks = TimetableTextParser.parseWeeks(text, totalWeeks: totalWeeks) { parsed = Array(weeks) }
                    else { parsed = ShareCodeParser.parseBareWeekList(text) }
                }
                weeks = Set(parsed.filter { $0 >= 1 && $0 <= totalWeeks })
                if weeks.isEmpty { skipped += 1; continue }
            } else {
                weeks = []
            }
            courses.append(ParsedCourse(
                title: titleValue,
                teacher: (first(object, teacherKeys) as? String) ?? "",
                room: (first(object, roomKeys) as? String) ?? "",
                weekday: weekday,
                startPeriod: startValue,
                endPeriod: endValue,
                weeks: weeks
            ))
        }
        guard !courses.isEmpty else { return nil }
        var warnings: [String] = []
        if skipped > 0 { warnings.append("有 \(skipped) 条课程数据不完整，已跳过。") }
        return ParseOutcome(courses: TimetableTextParser.deduplicate(courses), warnings: warnings)
    }

    /// 页面上是否有内嵌课表数据的迹象。
    public static func hasEmbeddedSchedule(_ html: String) -> Bool {
        let lowered = html.lowercased()
        return ["kblist", "coursename", "kcmc", "timetable", "schedule"].contains { lowered.contains($0) }
    }
}
