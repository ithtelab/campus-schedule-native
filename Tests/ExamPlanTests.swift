import Foundation
import Testing
@testable import ScheduleCore

struct ExamPlanTests {
    let calendar = ScheduleRules.calendar
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    func exam(_ title: String, _ day: Date, _ start: String, _ end: String, id: String? = nil) -> Exam {
        Exam(id: id ?? "exam-" + title, courseTitle: title, date: day, startTime: start, endTime: end)
    }

    // MARK: 时间

    @Test func startDateCombinesDayAndTime() throws {
        let e = exam("高数", date(2026, 12, 20), "09:00", "11:00")
        let start = try #require(ExamPlan.startDate(e))
        #expect(calendar.component(.hour, from: start) == 9)
        #expect(calendar.component(.minute, from: start) == 0)
        #expect(calendar.component(.day, from: start) == 20)
    }

    @Test func malformedTimeHasNoStartDate() {
        #expect(ExamPlan.startDate(exam("x", date(2026, 12, 20), "9:00", "11:00")) == nil)
        // 结束时间非法时开始时间仍然有效，但整场考试必须判定为无效。
        let badEnd = exam("x", date(2026, 12, 20), "09:00", "25:00")
        #expect(ExamPlan.endDate(badEnd) == nil)
        #expect(ExamPlan.validate(badEnd) == .malformedTime("25:00"))
    }

    // MARK: 未来考试

    @Test func upcomingExcludesFinishedAndSorts() {
        let now = date(2026, 12, 20, 10, 0)
        let past = exam("已结束", date(2026, 12, 19), "09:00", "11:00", id: "past")
        let later = exam("下午", date(2026, 12, 20), "14:00", "16:00", id: "later")
        let sooner = exam("上午", date(2026, 12, 20), "11:00", "13:00", id: "sooner")
        let ordered = ExamPlan.upcoming([past, later, sooner], now: now)
        #expect(ordered.map(\.id) == ["sooner", "later"])
    }

    @Test func examStartingRightNowCountsAsNotUpcoming() {
        let now = date(2026, 12, 20, 9, 0)
        let starting = exam("正在考", date(2026, 12, 20), "09:00", "11:00", id: "now")
        #expect(ExamPlan.upcoming([starting], now: now).isEmpty)
    }

    // MARK: 倒计时

    @Test func daysUntilNextCountsCalendarDays() {
        let now = date(2026, 12, 20, 23, 0)
        let e = exam("高数", date(2026, 12, 23), "09:00", "11:00")
        #expect(ExamPlan.daysUntilNext([e], now: now) == 3)
    }

    @Test func daysUntilNextIsNilWithoutUpcoming() {
        let now = date(2026, 12, 25)
        #expect(ExamPlan.daysUntilNext([exam("x", date(2026, 12, 20), "09:00", "11:00")], now: now) == nil)
    }

    @Test func daysUntilNextIsZeroOnTheSameDay() {
        let now = date(2026, 12, 20, 7, 0)
        let e = exam("高数", date(2026, 12, 20), "09:00", "11:00")
        #expect(ExamPlan.daysUntilNext([e], now: now) == 0)
    }

    // MARK: 排序与状态

    @Test func chronologicalIncludesPastAndSortsAscending() {
        let a = exam("一", date(2026, 12, 22), "09:00", "11:00", id: "a")
        let b = exam("二", date(2026, 12, 20), "09:00", "11:00", id: "b")
        #expect(ExamPlan.chronological([a, b]).map(\.id) == ["b", "a"])
    }

    @Test func finishedDetectedByEndTime() {
        let now = date(2026, 12, 20, 10, 30)
        #expect(ExamPlan.isFinished(exam("x", date(2026, 12, 20), "09:00", "11:00"), now: now) == false)
        #expect(ExamPlan.isFinished(exam("x", date(2026, 12, 20), "09:00", "10:30"), now: now) == true)
    }

    // MARK: 校验

    @Test func validExamPasses() {
        #expect(ExamPlan.validate(exam("高数", date(2026, 12, 20), "09:00", "11:00")) == .valid)
    }

    @Test func emptyTitleRejected() {
        var e = exam("x", date(2026, 12, 20), "09:00", "11:00")
        e.courseTitle = "   "
        #expect(ExamPlan.validate(e) == .missingTitle)
    }

    @Test func badTimeRejected() {
        let e = exam("x", date(2026, 12, 20), "9:00", "11:00")
        #expect(ExamPlan.validate(e) == .malformedTime("9:00"))
    }

    @Test func endBeforeStartRejected() {
        let e = exam("x", date(2026, 12, 20), "11:00", "09:00")
        #expect(ExamPlan.validate(e) == .endBeforeStart)
    }

    @Test func equalStartAndEndRejected() {
        let e = exam("x", date(2026, 12, 20), "09:00", "09:00")
        #expect(ExamPlan.validate(e) == .endBeforeStart)
    }

    @Test func validationMessagesAreReadable() {
        #expect(ExamValidation.missingTitle.errorDescription?.contains("科目") == true)
        #expect(ExamValidation.malformedTime("9:00").errorDescription?.contains("HH:mm") == true)
    }

    // MARK: 冲突

    @Test func overlappingExamsOnSameDayConflict() {
        let a = exam("一", date(2026, 12, 20), "09:00", "11:00", id: "a")
        let b = exam("二", date(2026, 12, 20), "10:00", "12:00", id: "b")
        let found = ExamPlan.conflicts(in: [a, b])
        #expect(found.count == 1)
        #expect(found[0].0 == "a" && found[0].1 == "b")
    }

    @Test func sequentialExamsDoNotConflict() {
        let a = exam("一", date(2026, 12, 20), "09:00", "11:00")
        let b = exam("二", date(2026, 12, 20), "11:00", "13:00")
        #expect(ExamPlan.conflicts(in: [a, b]).isEmpty)
    }

    @Test func differentDaysNeverConflict() {
        let a = exam("一", date(2026, 12, 20), "09:00", "11:00")
        let b = exam("二", date(2026, 12, 21), "09:00", "11:00")
        #expect(ExamPlan.conflicts(in: [a, b]).isEmpty)
    }

    @Test func noConflictInEmptyOrSingleList() {
        #expect(ExamPlan.conflicts(in: []).isEmpty)
        #expect(ExamPlan.conflicts(in: [exam("一", date(2026, 12, 20), "09:00", "11:00")]).isEmpty)
    }

    // MARK: 编解码

    @Test func examRoundTrips() throws {
        var original = exam("高等数学", date(2026, 12, 20), "09:00", "11:00")
        original.room = "A302"
        original.seatNumber = "17"
        original.notes = "带学生证"
        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(Exam.self, from: data)
        #expect(restored == original)
    }
}
