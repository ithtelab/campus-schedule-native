import Foundation

/// 把 HTML 课表转换成二维网格文本，再交给已有的网格解析器。
///
/// 这里刻意**不**使用 CSS 选择器：每所学校的类名都不同，为几千所学校维护选择器
/// 不现实。教务课表在结构层面高度一致 —— 一个含星期表头的大表格，行是节次、
/// 列是星期。因此只识别 `<table>` 的行列结构。
public enum HTMLTableExtractor {

    /// 从 HTML 中抽取所有表格，返回每个表格的二维文本网格。
    ///
    /// 单元格内的 `<div>`/`<p>`/`<br>` 视为换行，与课表单元格的多行书写一致。
    public static func extractTables(from html: String) -> [[[String]]] {
        let normalized = normalizeEntities(html)
        var tables: [[[String]]] = []
        var cursor = normalized.startIndex

        while let tableStart = findTag("table", in: normalized, from: cursor) {
            guard let tableEnd = matchingClose("table", in: normalized, from: tableStart.openEnd) else { break }
            let body = String(normalized[tableStart.openEnd..<tableEnd])
            tables.append(extractRows(from: body))
            cursor = tableEnd
        }
        return tables.filter { !$0.isEmpty }
    }

    /// 抽取单个表格的行列。
    static func extractRows(from tableBody: String) -> [[String]] {
        var rows: [[String]] = []
        var cursor = tableBody.startIndex
        while let rowOpen = findTag("tr", in: tableBody, from: cursor) {
            guard let rowEnd = matchingClose("tr", in: tableBody, from: rowOpen.openEnd) else { break }
            let rowBody = String(tableBody[rowOpen.openEnd..<rowEnd])
            rows.append(extractCells(from: rowBody))
            cursor = rowEnd
        }
        return rows
    }

    static func extractCells(from rowBody: String) -> [String] {
        var cells: [String] = []
        var cursor = rowBody.startIndex
        while true {
            let nextTd = findTag("td", in: rowBody, from: cursor)
            let nextTh = findTag("th", in: rowBody, from: cursor)
            // 取更早出现的那个：表头可能用 th，数据用 td。
            let chosen: (tag: String, openEnd: String.Index)?
            switch (nextTd, nextTh) {
            case (nil, nil): chosen = nil
            case (let td?, nil): chosen = td
            case (nil, let th?): chosen = th
            case (let td?, let th?): chosen = td.openEnd < th.openEnd ? td : th
            }
            guard let cell = chosen,
                  let cellEnd = matchingClose(cell.tag, in: rowBody, from: cell.openEnd) else { break }
            // 行/列合并会让网格错位，这里放弃跨列，仅在文本里保留内容。
            let raw = String(rowBody[cell.openEnd..<cellEnd])
            cells.append(cellText(raw))
            cursor = cellEnd
        }
        return cells
    }

    /// 把单元格 HTML 转成纯文本，块级标签变成换行，便于后续按行分类。
    static func cellText(_ html: String) -> String {
        var text = html
        for tag in ["div", "p", "br", "li", "span"] {
            text = text.replacingOccurrences(of: "<\(tag)", with: "\n<\(tag)", options: .caseInsensitive)
        }
        text = stripTags(text)
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // 去重相邻重复行：`<div>` 嵌套常把同一段文字产出两次。
        var deduped: [String] = []
        for line in lines where deduped.last != line { deduped.append(line) }
        return deduped.joined(separator: "\n")
    }

    static func stripTags(_ html: String) -> String {
        var result = ""
        var inTag = false
        for character in html {
            if character == "<" { inTag = true; continue }
            if character == ">" { inTag = false; continue }
            if !inTag { result.append(character) }
        }
        return decodeEntities(result)
    }

    /// 数值实体与常见命名实体。教务系统大量使用 `&nbsp;` 做占位。
    static func decodeEntities(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
        // 处理 &#12345; 形式的十进制实体。
        if result.contains("&#") {
            result = replaceNumericEntities(result)
        }
        return result
    }

    static func replaceNumericEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&#([0-9]{1,6});") else { return text }
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let codeRange = Range(match.range(at: 1), in: text),
                  let code = UInt32(text[codeRange]),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceSubrange(range, with: String(Character(scalar)))
        }
        return result
    }

    private static func normalizeEntities(_ html: String) -> String { html }

    /// 定位开始标签，返回标签名结束后的位置。
    static func findTag(_ name: String, in text: String, from index: String.Index) -> (tag: String, openEnd: String.Index)? {
        var searchFrom = index
        while let open = text.range(of: "<\(name)", options: [.caseInsensitive], range: searchFrom..<text.endIndex) {
            // 排除 <tablex> 这类前缀相同的标签。
            let after = open.upperBound
            if after < text.endIndex, text[after].isLetter { searchFrom = after; continue }
            guard let close = text[after...].firstIndex(of: ">") else { return nil }
            return (name, text.index(after: close))
        }
        return nil
    }

    /// 从给定位置起找到最近的同名结束标签，返回 `</name>` 之后的位置。
    static func matchingClose(_ name: String, in text: String, from index: String.Index) -> String.Index? {
        guard let range = text.range(of: "</\(name)", options: [.caseInsensitive], range: index..<text.endIndex),
              let close = text[range.upperBound...].firstIndex(of: ">") else { return nil }
        return text.index(after: close)
    }
}
