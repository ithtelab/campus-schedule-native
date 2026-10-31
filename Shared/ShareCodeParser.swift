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
        // 先按「看起来像课程」筛选出候选，再逐条校验：这样缺字段的行能被计入警告，
        // 而不是在过滤阶段悄悄消失。
        let candidates = objects.filter { $0["name"] != nil && $0["dayOfWeek"] != nil }
        guard !candidates.isEmpty else { return nil }

        var courses: [ParsedCourse] = []
        var skipped = 0
        for row in candidates {
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
    ///
    /// 这里不能直接用 `TimetableTextParser.parseWeeks`：那个函数要求文本里出现
    /// 「周」字才认为有周次，而分享码里就是裸的「1-16」。字段本身已经声明是周次，
    /// 因此直接按数值解析。
    private static func parseShareWeeks(_ value: Any?, totalWeeks: Int) -> Set<Int> {
        if let array = value as? [Int] {
            return Set(array.filter { $0 >= 1 && $0 <= totalWeeks })
        }
        if let numbers = value as? [Any] {
            return Set(numbers.compactMap(intValue).filter { $0 >= 1 && $0 <= totalWeeks })
        }
        if let text = value as? String {
            // 允许带「周」和单双周标记，也允许裸范围。
            if let parsed = TimetableTextParser.parseWeeks(text, totalWeeks: totalWeeks), !parsed.isEmpty {
                return parsed
            }
            return Set(parseBareWeekList(text).filter { $0 >= 1 && $0 <= totalWeeks })
        }
        if let number = intValue(value) {
            return number >= 1 && number <= totalWeeks ? [number] : []
        }
        return []
    }

    /// 解析「1-16」「1,3,5」「1-8,10-16」这类不含「周」字的周次列表。
    static func parseBareWeekList(_ text: String) -> [Int] {
        let normalized = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "～", with: "-")
            .replacingOccurrences(of: "~", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "周", with: "")
        var result: [Int] = []
        for piece in normalized.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "、" }) {
            let parts = piece.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 2, let lower = Int(parts[0]), let upper = Int(parts[1]), lower <= upper {
                result.append(contentsOf: lower...upper)
            } else if parts.count == 1, let single = Int(piece), single > 0 {
                result.append(single)
            }
        }
        return result
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
