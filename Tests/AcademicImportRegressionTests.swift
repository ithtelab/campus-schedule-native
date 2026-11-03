import Foundation
import Testing
@testable import ScheduleCore

struct AcademicImportRegressionTests {
    @Test func webHTTPCompatibilityDoesNotDisableGeneralATS() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("ios/CampusSchedule-Info.plist"))
        let info = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let policy = try #require(info["NSAppTransportSecurity"] as? [String: Any])
        #expect(policy["NSAllowsArbitraryLoadsInWebContent"] as? Bool == true)
        #expect(policy["NSAllowsArbitraryLoads"] as? Bool != true)
        #expect(policy["NSAllowsArbitraryLoadsForMedia"] as? Bool != true)
    }

    @Test func parsesHTMLTableInsteadOfTreatingMarkupAsPlainText() {
        let html = """
        <html><body><table><tr><th>节次</th><th>周一</th><th>周二</th></tr>
        <tr><td>第1-2节</td><td><div>高等数学</div><div>陈老师</div><div>A302</div><div>1-16周</div></td><td></td></tr>
        </table></body></html>
        """
        let outcome = AcademicSystemProfile.parsePage(html, totalWeeks: 20)
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses.first?.title == "高等数学")
        #expect(outcome.courses.first?.weekday == 0)
        #expect(outcome.courses.first?.startPeriod == 1)
        #expect(outcome.courses.first?.room == "A302")
    }

    @Test func HTMLTextFallbackOmitsScriptsAndStyles() {
        let html = """
        <html><script>周三 第3-4节 假课程</script><style>周四 第5-6节 假课程</style>
        <body><div>周一 第1-2节 高等数学 陈老师 A302 1-16周</div></body></html>
        """
        let outcome = AcademicSystemProfile.parsePage(html, totalWeeks: 20)
        #expect(outcome.courses.count == 1)
        #expect(outcome.courses.first?.title == "高等数学")
    }

    @Test func embeddedCourseDataStillParsesBeforeTextFallback() {
        let html = #"<script>var kbList = [{"courseName":"线性代数","weekday":2,"startSection":3,"endSection":4}];</script>"#
        let outcome = AcademicSystemProfile.parsePage(html, totalWeeks: 20)
        #expect(outcome.courses.first?.title == "线性代数")
        #expect(outcome.courses.first?.weekday == 1)
    }
}
