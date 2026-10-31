import Foundation

/// 特定教务系统的页面特征与提取策略。
///
/// 大部分学校能用通用表格提取处理。少数系统把课表渲染成 `<div>` 网格或用内嵌
/// JSON 传递数据，HTML 里没有 `<table>`，需要专门的提取入口。
///
/// 这里只识别**系统类型**并给出提取提示，真正的解析仍复用文本/网格解析器 ——
/// 保持一条解析路径，避免为每所学校维护解析逻辑。
public enum AcademicSystemProfile {

    /// 页面里的内嵌 JSON 候选容器。正方、URP 等把课表数据放在 `var xxx = {...}`。
    public static func embeddedJSON(from html: String) -> [String] {
        var results: [String] = []
        // 匹配 `var kbList = [...]`、`courseJson = {...}`、`data = {...}]` 等赋值。
        let patterns = [
            #"(?:var|let|const)\s+\w*(?:course|kb|schedule|timetable|data)\w*\s*=\s*(\[[\s\S]*?\]|\{[\s\S]*?\})\s*;"#,
            #"window\.\w+\s*=\s*(\[[\s\S]*?\]|\{[\s\S]*?\})"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            for match in regex.matches(in: html, range: range) {
                guard match.numberOfRanges > 1,
                      let captured = Range(match.range(at: 1), in: html) else { continue }
                let candidate = String(html[captured])
                // 太短的多半不是课表数据，过滤噪音。
                if candidate.count > 40 { results.append(candidate) }
            }
        }
        return results
    }

    /// 从内嵌 JSON 里按常见字段名提取课程，覆盖正方与 URP 的命名习惯。
    public static func courses(fromEmbeddedJSON json: String, totalWeeks: Int) -> ParseOutcome? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let objects = ShareCodeParser.collectObjects(root)

        let dayKeys = ["weekday", "weekDay", "xqj", "dayOfWeek", "day"]
        let startKeys = ["startNode", "startSection", "jcs", "beginNumber", "start"]
        let endKeys = ["endNode", "endSection", "jce", "end"]
        let titleKeys = ["courseName", "kcmc", "name", "title"]
        let roomKeys = ["room", "place", "cdmc", "location"]
        let teacherKeys = ["teacher", "xm", "teacherName", "jsxm"]
        let weekKeys = ["weeks", "week", "zcd", "weekRange"]

        func first(_ object: [String: Any], _ keys: [String]) -> Any? {
            for key in keys where object[key] != nil { return object[key] }
            return nil
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
            let weekday = dayValue >= 1 && dayValue <= 7 ? dayValue - 1 : dayValue
            guard (0...6).contains(weekday), startValue >= 1, endValue >= startValue else {
                skipped += 1; continue
            }
            let weeks: Set<Int>
            if let raw = first(object, weekKeys) {
                let parsed = ShareCodeParser.parseBareWeekList(String(describing: raw))
                weeks = Set(parsed.filter { $0 >= 1 && $0 <= totalWeeks })
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
