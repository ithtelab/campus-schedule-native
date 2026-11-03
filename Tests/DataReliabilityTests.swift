import Foundation
import Testing
@testable import ScheduleCore

struct DataReliabilityTests {
    let start = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))!

    func parsed(weeks: Set<Int>) -> ParsedCourse {
        .init(title: "数学", room: "A302", weekday: 0, startPeriod: 1, endPeriod: 2, weeks: weeks)
    }

    @Test func repeatedImportMatchesIdentityButDisjointWeeksDoNot() {
        let odd = parsed(weeks: [1, 3, 5]), even = parsed(weeks: [2, 4, 6])
        #expect(ImportPlanner.replacementIndex(for: odd, in: [odd], totalWeeks: 20) == 0)
        #expect(ImportPlanner.replacementIndex(for: even, in: [odd], totalWeeks: 20) == nil)
        let same = ImportPlanner.plan(.init(courses: [odd, odd]), existing: [odd], totalWeeks: 20)
        #expect(same.courses.count == 1)
        #expect(same.replacedCount == 1)
        #expect(same.conflicts.isEmpty)
        let distinct = ImportPlanner.plan(.init(courses: [odd, even]), existing: [], totalWeeks: 20)
        #expect(distinct.courses.count == 2)
    }

    @Test func explicitFullTermAndUnspecifiedWeeksShareIdentity() {
        #expect(ImportPlanner.sameIdentity(parsed(weeks: []), parsed(weeks: Set(1...20)), totalWeeks: 20))
    }

    @Test func contradictoryIncomingRecordsAreNotSilentlyOverwritten() {
        let first = parsed(weeks: [1, 3])
        var other = first; other.room = "B205"
        let plan = ImportPlanner.plan(.init(courses: [first, other]), existing: [], totalWeeks: 20)
        #expect(plan.courses.isEmpty)
        #expect(!plan.warnings.isEmpty)
    }

    @Test func termAdjustmentDoesNotMutateOriginalAndUsesNewBoundary() {
        let original = [ParsedCourse(title: "保留", weekday: 0, startPeriod: 7, endPeriod: 8, weeks: [1, 20]),
                        ParsedCourse(title: "移除", weekday: 0, startPeriod: 9, endPeriod: 10, weeks: [1])]
        let plan = ArchiveMapping.adjustCourses(original, totalWeeks: 16, periodCount: 8,
            periodsOf: { ($0.startPeriod, $0.endPeriod) }, weeksOf: { $0.weeks },
            apply: { course, weeks in var copy = course; copy.weeks = weeks; return copy })
        #expect(original.count == 2)
        #expect(original[0].weeks == [1, 20])
        #expect(plan.kept.count == 1)
        #expect(plan.kept[0].weeks == [1])
        #expect(plan.removedCount == 1)
    }

    @Test func exceptionsShiftWithSemesterAndKeepIdentity() {
        let source = CourseException(courseID: "stable", day: start, cancelled: false,
                                     start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200))
        let shifted = ArchiveMapping.shifted(source, days: 7)
        #expect(shifted.id == source.id && shifted.courseID == source.courseID)
        #expect(shifted.day == start.addingTimeInterval(7 * 86400))
        #expect(shifted.start == source.start?.addingTimeInterval(7 * 86400))
    }

    @Test func syncIgnoresExportMetadataAndOrderingButKeepsActualEdits() throws {
        let periods = [ArchivedPeriod(index: 1, start: "08:00", end: "08:45")]
        let course = ArchivedCourse(id: "a", title: "数学", room: "A302", teacher: "",
            weekday: 0, startPeriod: 1, endPeriod: 1, color: "blue", weeks: [1, 2])
        var term = ArchivedSemester(id: "term", name: "学期", startDate: start,
                                    totalWeeks: 20, periods: periods, courses: [course], exceptions: [])
        let original = try ScheduleArchive(exportedAt: start, appVersion: "1", semesters: [term]).encoded()
        term.courses[0].weeks.reverse()
        let later = try ScheduleArchive(exportedAt: start.addingTimeInterval(3600), appVersion: "2", semesters: [term]).encoded()
        #expect(CloudSyncPlan.canonicalPayload(original) == CloudSyncPlan.canonicalPayload(later))
        #expect(CloudSyncPlan.decide(local: .init(updatedAt: start, deviceID: "a", payload: later),
            remote: .init(updatedAt: start, deviceID: "b", payload: original), lastSyncedPayload: original) == .idle)
        term.courses[0].room = "B205"
        let changed = try ScheduleArchive(exportedAt: start, semesters: [term]).encoded()
        #expect(CloudSyncPlan.canonicalPayload(original) != CloudSyncPlan.canonicalPayload(changed))
    }

    @Test func componentLinkEscapesIDsAndReadsLegacyLinks() throws {
        let url = try #require(CourseDeepLink.url(courseID: "课程/1:2", termID: "学期&1"))
        #expect(CourseDeepLink.target(url) == CourseDeepLink.Target(courseID: "课程/1:2", termID: "学期&1"))
        let legacy = try #require(URL(string: "campusschedule://course/old-id"))
        let external = try #require(URL(string: "https://example.com/course/old-id"))
        #expect(CourseDeepLink.target(legacy) == CourseDeepLink.Target(courseID: "old-id", termID: nil))
        #expect(CourseDeepLink.target(external) == nil)
        #expect(CourseDeepLink.url(courseID: nil, termID: nil)?.host == "today")
    }

    @Test func mergedHeadersKeepWeekdayAndRowSpanIsOneCourse() throws {
        let html = """
        <table><tr><th colspan="2">节次</th><th>周一</th><th>周二</th><th>周三</th></tr>
        <tr><td rowspan="2">上午</td><td>第1节</td><td rowspan="2">数学<br>A302<br>1-16周</td><td></td><td></td></tr>
        <tr><td>第2节</td><td></td><td></td></tr></table>
        """
        let result = AcademicSystemProfile.parsePage(html, totalWeeks: 20)
        let course = try #require(result.courses.first)
        #expect(result.courses.count == 1)
        #expect(course.weekday == 0)
        #expect(course.startPeriod == 1 && course.endPeriod == 2)
        #expect(course.title == "数学")
    }

    @Test func nestedTablesStillExposeTheInnerTimetable() {
        let html = "<table><tr><td><table><tr><td>内部</td></tr></table></td></tr></table>"
        let tables = HTMLTableExtractor.extractTables(from: html)
        #expect(tables.contains { $0 == [["内部"]] })
    }

    @Test func nestedJSONWeeksAndBracketsInsideStringsAreNotTruncated() throws {
        let html = #"<script>var kbList = [{"courseName":"数学[进阶]","xqj":2,"startSection":1,"endSection":2,"weeks":[1,3,5]}];</script>"#
        let course = try #require(AcademicSystemProfile.parsePage(html, totalWeeks: 20).courses.first)
        #expect(course.title == "数学[进阶]")
        #expect(course.weekday == 1 && course.weeks == [1, 3, 5])
    }

    @Test func ambiguousWeekdaysRequireExplicitChoice() throws {
        let json = #"[{"courseName":"数学","weekday":2,"startSection":1,"endSection":2}]"#
        let unknown = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20, numbering: .automatic))
        #expect(unknown.courses.isEmpty && !unknown.warnings.isEmpty)
        let zero = AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20, numbering: .mondayZero)
        let one = AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20, numbering: .mondayOne)
        #expect(zero?.courses.first?.weekday == 2)
        #expect(one?.courses.first?.weekday == 1)
    }

    @Test func veryLargeWeekRangeIsBoundedBeforeIteration() {
        #expect(TimetableTextParser.parseWeeks("1-999999999周", totalWeeks: 20) == Set(1...20))
        #expect(ShareCodeParser.parseBareWeekList("1-999999999").count == 53)
    }

    @Test func explicitPeriodMetadataDoesNotConsumeCourseTitle() {
        let course = TimetableTextParser.parseCourseCell("高等数学 第1-2节\nA302\n1-16周")
        #expect(course?.title == "高等数学")
    }

    @Test func oddWeeksInEmbeddedDataStayOdd() throws {
        let json = #"[{"courseName":"数学","xqj":1,"startSection":1,"endSection":2,"zcd":"1-8周(单)"}]"#
        let outcome = try #require(AcademicSystemProfile.courses(fromEmbeddedJSON: json, totalWeeks: 20))
        #expect(outcome.courses.first?.weeks == [1, 3, 5, 7])
    }

    @Test func standaloneOddAndEvenWeeksUseTheConfiguredTerm() {
        #expect(TimetableTextParser.parseWeeks("单周", totalWeeks: 6) == [1, 3, 5])
        #expect(TimetableTextParser.parseWeeks("双周", totalWeeks: 6) == [2, 4, 6])
        #expect(TimetableTextParser.parseWeeks("每周", totalWeeks: 6) == Set(1...6))
    }
}
