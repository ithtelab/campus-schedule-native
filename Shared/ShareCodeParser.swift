import Foundation

/// 第三方课表 App 导出的分享码。
///
/// 支持超星分享课表与 WakeUp 的备份片段。分享码是 JSON，字段名固定，
/// 因此这里按结构解析而不是靠文本启发式 —— 比抓网页稳定得多。
public enum ShareCodeParser {

    /// 尝试解析分享码。不是分享码时返回 nil，让调用方回退到文本解析。
    public static func parse(_ raw: String, totalWeeks: Int = 20) -> ParseOutcome? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 分享码可能是纯 JSON，也可能包在 URL 或前缀里，截取第一个 { 到最后一个 }。
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"), start < end else { return nil }
        let json = String(trimmed[start...end])
        guard let data = json.data(using: .utf8) else { return nil }

        if let outcome = parseChaoxing(data, totalWeeks: totalWeeks) { return outcome }
        if let outcome = parseWakeUp(data, totalWeeks: totalWeeks) { return outcome }
        return nil
    }

    // MARK: 超星

    /// 超星分享课表：每门课是 `{name, teacherName, location, dayOfWeek, beginNumber, length, weeks}`。
    private static func parseChaoxing(_ data: Data, totalWeeks: Int) -> ParseOutcome? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let objects = collectObjects(root)
        let rows = objects.filter {
            $0["name"] != nil && $0["dayOfWeek"] != nil && $0["beginNumber"] != nil
                && $0["length"] != nil && $0["weeks"] != nil
        }
        guard !rows.isEmpty else { return nil }

        var courses: [ParsedCourse] = []
        var skipped = 0
        for row in rows {
            guard let name = row["name"] as? String, !name.isEmpty,
                  let day = intValue(row["dayOfWeek"]),
                  let begin = intValue(row["beginNumber"]),
                  let length = intValue(row["length"]), length >= 1 else {
                skipped += 1
                continue
            }
            // 超星里星期是 1…7（周一 = 1），内部用 0 起。
            let weekday = day - 1
            guard (0...6).contains(weekday), begin >= 1 else { skipped += 1; continue }

            let teacher = (row["teacherName"] as? String) ?? ""
            let room = ((row["location"] as? String) ?? "")
                + ((row["onlineLocation"] as? String) ?? "")
            let weeks = parseShareWeeks(row["weeks"], totalWeeks: totalWeeks)

            courses.append(ParsedCourse(
                title: name, teacher: teacher, room: room,
                weekday: weekday, startPeriod: begin, endPeriod: begin + length - 1,
                weeks: weeks
            ))
        }
        guard !courses.isEmpty else { return nil }
        var warnings: [String] = []
        if skipped > 0 { warnings.append("有 \(skipped) 门课程字段缺失，已跳过。") }
        return ParseOutcome(courses: TimetableTextParser.deduplicate(courses), warnings: warnings)
    }

    /// 超星的 `weeks` 字段可能是「1-16」这样的字符串，也可能是数组。
    private static func parseShareWeeks(_ value: Any?, totalWeeks: Int) -> Set<Int> {
        if let array = value as? [Int] {
            return Set(array.filter { $0 >= 1 && $0 <= totalWeeks })
        }
        if let text = value as? String {
            return TimetableTextParser.parseWeeks(text, totalWeeks: totalWeeks) ?? []
        }
        if let number = intValue(value) {
            return number >= 1 && number <= totalWeeks ? [number] : []
        }
        return []
    }

    // MARK: WakeUp

    /// WakeUp 备份片段：课程含 `courseName`、`day`（1=周一）、
    /// `startNode`（0 起）与 `step`。
    private static func parseWakeUp(_ data: Data, totalWeeks: Int) -> ParseOutcome? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let objects = collectObjects(root)
        let rows = objects.filter { $0["courseName"] != nil && $0["day"] != nil && $0["startNode"] != nil }
        guard !rows.isEmpty else { return nil }

        var courses: [ParsedCourse] = []
        var skipped = 0
        for row in rows {
            guard let name = row["courseName"] as? String, !name.isEmpty,
                  let day = intValue(row["day"]),
                  let startNode = intValue(row["startNode"]) else {
                skipped += 1; continue
            }
            let step = intValue(row["step"]) ?? 2
            // WakeUp 的 day 是 1…7 且周一为 1，与内部 0 起不同。
            let weekday = day - 1
            guard (0...6).contains(weekday), startNode >= 0 else { skipped += 1; continue }

            let weeks = parseShareWeeks(row["week"] ?? row["weeks"], totalWeeks: totalWeeks)
            courses.append(ParsedCourse(
                title: name,
                teacher: (row["teacher"] as? String) ?? "",
                room: (row["room"] as? String) ?? "",
                weekday: weekday,
                startPeriod: startNode + 1,   // 内部节次从 1 开始
                endPeriod: startNode + max(1, step),
                weeks: weeks
            ))
        }
        guard !courses.isEmpty else { return nil }
        var warnings: [String] = []
        if skipped > 0 { warnings.append("有 \(skipped) 门课程字段缺失，已跳过。") }
        return ParseOutcome(courses: TimetableTextParser.deduplicate(courses), warnings: warnings)
    }

    // MARK: 工具

    /// 递归收集所有 JSON 对象，兼容课程数组套在任意层级的包装里。
    static func collectObjects(_ value: Any) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if let dictionary = value as? [String: Any] {
            result.append(dictionary)
            for nested in dictionary.values { result.append(contentsOf: collectObjects(nested)) }
        } else if let array = value as? [Any] {
            for nested in array { result.append(contentsOf: collectObjects(nested)) }
        }
        return result
    }

    /// JSON 数字可能解码成 Int、Double 或 String，统一取整数。
    static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: number
        case let number as Double: Int(number)
        case let text as String: Int(text)
        default: nil
        }
    }
}
