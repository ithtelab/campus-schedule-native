import Foundation
import Testing
@testable import ScheduleCore

struct MilestoneReminderPlanTests {
    var calendar: Calendar { MilestoneCounter.calendar }

    func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func milestone(_ title: String = "毕业", date: Date, remind: Int,
                   yearly: Bool = false) -> Milestone {
        Milestone(title: title, date: date, reminderDaysBefore: remind, repeatsAnnually: yearly)
    }

    // MARK: 生成

    @Test func reminderIsNineAMOnLeadDay() {
        let item = milestone(date: day(2027, 6, 20), remind: 3)
        let events = MilestoneReminderPlan.make([item], now: day(2027, 6, 1))
        let lead = events.first { $0.id.hasSuffix(".lead") }
        #expect(lead != nil)
        let parts = calendar.dateComponents([.month, .day, .hour], from: lead!.date)
        #expect(parts.month == 6 && parts.day == 17 && parts.hour == MilestoneReminderPlan.hour)
    }

    @Test func alsoRemindsOnTheDayItself() {
        let item = milestone(date: day(2027, 6, 20), remind: 3)
        let events = MilestoneReminderPlan.make([item], now: day(2027, 6, 1))
        let today = events.first { $0.id.hasSuffix(".today") }
        #expect(today != nil)
        #expect(today?.title.contains("就是今天") == true)
        let parts = calendar.dateComponents([.month, .day], from: today!.date)
        #expect(parts.month == 6 && parts.day == 20)
    }

    @Test func noReminderWhenDisabled() {
        let item = milestone(date: day(2027, 6, 20), remind: 0)
        #expect(MilestoneReminderPlan.make([item], now: day(2027, 6, 1)).isEmpty)
    }

    @Test func skipsPastDates() {
        let item = milestone("旧事", date: day(2026, 1, 1), remind: 3)
        #expect(MilestoneReminderPlan.make([item], now: day(2027, 6, 1)).isEmpty)
    }

    @Test func skipsReminderAlreadyPassedButKeepsTodayReminder() {
        // 现在是到期日前两天，提前 7 天的提醒已经错过了。
        let item = milestone(date: day(2027, 6, 20), remind: 7)
        let events = MilestoneReminderPlan.make([item], now: day(2027, 6, 18))
        #expect(events.filter { $0.id.hasSuffix(".lead") }.isEmpty)
        #expect(events.contains { $0.id.hasSuffix(".today") })
    }

    @Test func annualEventRemindsForRolledDate() {
        // 2027 年已过去，滚到 2028 年 3 月 15 日；提前一天应在 2028-03-14 提醒。
        let item = milestone(date: day(2006, 3, 15), remind: 1, yearly: true)
        let events = MilestoneReminderPlan.make([item], now: day(2027, 6, 1))
        let lead = events.first { $0.id.hasSuffix(".lead") }
        #expect(lead != nil)
        let parts = calendar.dateComponents([.year, .month, .day], from: lead!.date)
        #expect(parts.year == 2028 && parts.month == 3 && parts.day == 14)
        // 一年前不应该提前产生下一次的提醒。
        #expect(events.count == 2)
    }

    @Test func sortedByDateThenIdentifier() {
        let a = milestone("甲", date: day(2027, 6, 5), remind: 1)
        let b = milestone("乙", date: day(2027, 6, 3), remind: 1)
        let events = MilestoneReminderPlan.make([a, b], now: day(2027, 6, 1))
        #expect(events.map(\.date) == events.map(\.date).sorted())
    }

    @Test func respectsLimit() {
        let items = (1...30).map { index in
            milestone("事件\(index)", date: day(2027, 7, 1).addingTimeInterval(Double(index) * 86400), remind: 1)
        }
        #expect(MilestoneReminderPlan.make(items, now: day(2027, 6, 1), limit: 5).count == 5)
    }

    @Test func identifierPrefixIsStable() {
        // 通知清理依赖 milestone. 前缀，改前缀会留下删不掉的旧通知。
        let item = milestone(date: day(2027, 6, 20), remind: 1)
        let events = MilestoneReminderPlan.make([item], now: day(2027, 6, 1))
        #expect(events.allSatisfy { $0.id.hasPrefix("milestone.") })
    }
}

struct MilestoneDeepLinkTests {
    @Test func buildsSpecificEventLink() {
        let url = MilestoneDeepLink.url(milestoneID: "abc")
        #expect(url?.absoluteString == "campusschedule://milestone?id=abc")
    }

    @Test func emptyIdentifierFallsBackToTheList() throws {
        let url = try #require(MilestoneDeepLink.url(milestoneID: nil))
        #expect(url.absoluteString == "campusschedule://milestones")
        #expect(MilestoneDeepLink.target(url) == MilestoneDeepLink.Target(milestoneID: nil))
    }

    @Test func parsesEventLink() throws {
        let url = try #require(URL(string: "campusschedule://milestone?id=abc"))
        #expect(MilestoneDeepLink.target(url)?.milestoneID == "abc")
    }

    @Test func rejectsOtherHosts() {
        #expect(MilestoneDeepLink.target(URL(string: "campusschedule://course?id=1")!) == nil)
        #expect(MilestoneDeepLink.target(URL(string: "https://example.com/milestone")!) == nil)
    }
}

struct MilestoneArchiveTests {
    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    func archive(milestones: [Milestone]) -> ScheduleArchive {
        ScheduleArchive(semesters: [
            ArchivedSemester(id: "t1", name: "学期", startDate: day(2027, 2, 22), totalWeeks: 20,
                             periods: [ArchivedPeriod(index: 1, start: "08:00", end: "08:45")],
                             courses: [], exceptions: []),
        ], milestones: milestones)
    }

    @Test func milestonesRoundTripThroughArchive() throws {
        let item = Milestone(id: "m1", title: "毕业", date: day(2027, 6, 20),
                             direction: .countdown, category: .graduation,
                             pinned: true, reminderDaysBefore: 7)
        let data = try archive(milestones: [item]).encoded()
        let decoded = try ScheduleArchive.decoded(from: data)
        #expect(decoded.milestones == [item])
    }

    @Test func oldArchiveWithoutMilestonesStillDecodes() throws {
        // 模拟旧版备份：JSON 里根本没有 milestones 键。
        let json = """
        {"schema":1,"exportedAt":"2027-01-01T00:00:00.000Z","semesters":[{
          "id":"t1","name":"学期","startDate":"2027-02-22T01:00:00.000Z","totalWeeks":20,
          "periods":[{"index":1,"start":"08:00","end":"08:45"}],
          "courses":[],"exceptions":[]}]}
        """
        let decoded = try ScheduleArchive.decoded(from: Data(json.utf8))
        #expect(decoded.milestones.isEmpty)
    }

    @Test func duplicateMilestoneIDIsRejected() {
        let a = Milestone(id: "dup", title: "甲", date: day(2027, 6, 20))
        let b = Milestone(id: "dup", title: "乙", date: day(2027, 7, 1))
        #expect(throws: ArchiveError.duplicateMilestoneID("dup")) {
            try archive(milestones: [a, b]).validated()
        }
    }

    @Test func blankTitleIsRejected() {
        let item = Milestone(id: "m1", title: "   ", date: day(2027, 6, 20))
        #expect(throws: ArchiveError.invalidMilestone("m1", "缺少名称")) {
            try archive(milestones: [item]).validated()
        }
    }

    @Test func outOfRangeReminderLeadIsRejected() {
        let item = Milestone(id: "m1", title: "毕业", date: day(2027, 6, 20), reminderDaysBefore: 400)
        #expect(throws: ArchiveError.invalidMilestone("m1", "提前提醒天数超出范围")) {
            try archive(milestones: [item]).validated()
        }
    }

    @Test func summaryMentionsMilestones() {
        let item = Milestone(id: "m1", title: "毕业", date: day(2027, 6, 20))
        #expect(archive(milestones: [item]).summary.contains("1 个纪念事件"))
        // 没有纪念事件时摘要保持原样，不追加空段。
        #expect(!archive(milestones: []).summary.contains("纪念事件"))
    }
}
