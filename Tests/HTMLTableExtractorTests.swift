import Foundation
import Testing
@testable import ScheduleCore

struct HTMLTableExtractorTests {

    @Test func extractsSimpleTable() {
        let html = """
        <table><tr><th>节次</th><th>周一</th><th>周二</th><th>周三</th></tr>
        <tr><td>第1-2节</td><td>高等数学</td><td></td><td>线性代数</td></tr></table>
        """
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables.count == 1)
        #expect(tables[0].count == 2)
        #expect(tables[0][0][1] == "周一")
        #expect(tables[0][1][2] == "高等数学")
    }

    @Test func handlesMultipleTables() {
        let html = """
        <table><tr><td>a</td></tr></table>
        <table><tr><td>b</td></tr></table>
        """
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables.count == 2)
        #expect(tables[0][0][0] == "a")
        #expect(tables[1][0][0] == "b")
    }

    @Test func convertsBlockTagsToLines() {
        let html = "<table><tr><td><div>高等数学</div><div>陈老师</div><div>A302</div></td></tr></table>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables[0][0][0] == "高等数学\n陈老师\nA302")
    }

    @Test func breaksOnBrTags() {
        let html = "<table><tr><td>数学<br>张老师</td></tr></table>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables[0][0][0].contains("\n"))
    }

    @Test func decodesEntities() {
        let html = "带有 &amp; 符与&nbsp;空格"
        let text = HTMLTableExtractor.decodeEntities(html)
        #expect(text.contains("&"))
        #expect(text.contains(" "))
    }

    @Test func decodesNumericEntities() {
        let text = HTMLTableExtractor.decodeEntities("&#20013;&#25991;")
        #expect(text == "中文")
    }

    @Test func nestedDivsDoNotDuplicateText() {
        // 嵌套结构常把同一段文字输出两次，去重后应只剩一行。
        let html = "<table><tr><td><div><span>高等数学</span></div></td></tr></table>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables[0][0][0] == "高等数学")
    }

    @Test func emptyTableProducesNoRows() {
        let tables = HTMLTableExtractor.extractTables(from: "<table></table>")
        #expect(tables.isEmpty)
    }

    @Test func ignoresPrefixTagNames() {
        // <tablex> 不应被当成 <table>。
        let html = "<tablex><tr><td>a</td></tr></tablex>"
        #expect(HTMLTableExtractor.extractTables(from: html).isEmpty)
    }

    @Test func ignoresTextOutsideTable() {
        let html = "<p>课表如下</p><table><tr><td>数学</td></tr></table><p>结束</p>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables.count == 1)
        #expect(tables[0][0][0] == "数学")
    }

    @Test func handlesUpperCaseTags() {
        let html = "<TABLE><TR><TD>数学</TD></TR></TABLE>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables.count == 1)
        #expect(tables[0][0][0] == "数学")
    }

    @Test func stripsInlineStylesAndAttributes() {
        let html = "<table><tr><td class=\"x\" style=\"color:red\">数学</td></tr></table>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables[0][0][0] == "数学")
    }

    @Test func producesGridUsableByParser() {
        // 端到端：HTML → 网格 → 课程。
        let html = """
        <table>
        <tr><th>节次</th><th>周一</th><th>周二</th><th>周三</th></tr>
        <tr><td>第1-2节</td>
            <td><div>高等数学</div><div>陈老师</div><div>A302</div><div>1-16周</div></td>
            <td></td><td></td></tr>
        </table>
        """
        let tables = HTMLTableExtractor.extractTables(from: html)
        let outcome = TimetableTextParser.parseGrid(tables[0], totalWeeks: 20)
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses[0].title == "高等数学")
        #expect(outcome.courses[0].weekday == 0)
        #expect(outcome.courses[0].room == "A302")
        #expect(outcome.courses[0].weeks == Set(1...16))
    }
}
