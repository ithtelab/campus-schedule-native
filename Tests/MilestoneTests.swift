import Foundation
import Testing
@testable import ScheduleCore

struct MilestoneTests {
    /// 固定时区构造日期，避免测试机时区影响结果。
    func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                  hour: hour, minute: minute))!
    }

    func milestone(_ title: String = "毕业", date: Date, direction: Milestone.Direction = .countdown,
                   pinned: Bool = false, remind: Int = 0, yearly: Bool = false,
                   expiry: Milestone.Expiry = .continueCounting) -> Milestone {
        Milestone(title: title, date: date, direction: direction, category: .personal,
                  pinned: pinned, reminderDaysBefore: remind,
                  repeatsAnnually: yearly, expiry: expiry)
    }

    // MARK: 倒数

    @Test func futureDateCountsDown() {
        let item = milestone(date: day(2027, 6, 20))
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 10))
        #expect(reading.state == .upcoming(days: 10))
        #expect(reading.dayCount == 10)
    }

    @Test func sameDayIsToday() {
        let item = milestone(date: day(2027, 6, 20))
        #expect(MilestoneCounter.read(item, now: day(2027, 6, 20)).state == .today)
    }

    @Test func pastDateCountsUp() {
        let item = milestone(date: day(2027, 6, 1))
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 11))
        #expect(reading.state == .past(days: 10))
    }

    // MARK: 日历日规则

    @Test func midnightRolloverCountsOneDay() {
        // 23:00 到次日 00:30 只跨了一天，不能因为不足 24 小时算成 0 天。
        let item = milestone(date: day(2027, 6, 21, hour: 9))
        let lateNight = day(2027, 6, 20, hour: 23, minute: 0)
        #expect(MilestoneCounter.read(item, now: lateNight).state == .upcoming(days: 1))
        let afterMidnight = day(2027, 6, 21, hour: 0, minute: 30)
        #expect(MilestoneCounter.read(item, now: afterMidnight).state == .today)
    }

    @Test func ignoresTimeOfDayOfTarget() {
        // 目标日填的是当天上午 9 点，但 20 点查询仍应算「今天」。
        let item = milestone(date: day(2027, 6, 20, hour: 9))
        #expect(MilestoneCounter.read(item, now: day(2027, 6, 20, hour: 20)).state == .today)
    }

    // MARK: 每年重复

    @Test func annualRepeatRollsToNextYear() {
        let item = milestone(date: day(2006, 3, 15), yearly: true)
        // 2027 年 3 月 15 日已过，应指向 2028 年。
        let reading = MilestoneCounter.read(item, now: day(2027, 12, 1))
        #expect(reading.state == .upcoming(days: 105))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(calendar.component(.year, from: reading.effectiveDate) == 2028)
        #expect(calendar.component(.month, from: reading.effectiveDate) == 3)
        #expect(calendar.component(.day, from: reading.effectiveDate) == 15)
    }

    @Test func annualRepeatKeepsThisYearWhenAhead() {
        let item = milestone(date: day(2006, 12, 25), yearly: true)
        let reading = MilestoneCounter.read(item, now: day(2027, 12, 20))
        #expect(reading.state == .upcoming(days: 5))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(calendar.component(.year, from: reading.effectiveDate) == 2027)
    }

    @Test func annualRepeatOnTheDayIsToday() {
        let item = milestone(date: day(2006, 3, 15), yearly: true)
        #expect(MilestoneCounter.read(item, now: day(2027, 3, 15)).state == .today)
    }

    @Test func annualRepeatNeverGoesBackwards() {
        // 跨年组合：12 月 31 日查询 1 月 1 日的事件，必须指向明年而不是今年已过去的。
        let item = milestone(date: day(2000, 1, 1), yearly: true)
        let reading = MilestoneCounter.read(item, now: day(2027, 12, 31))
        #expect(reading.state == .upcoming(days: 1))
    }

    // MARK: 闰日

    @Test func leapDayFallsBackToFebruary28() {
        let item = milestone(date: day(2024, 2, 29), yearly: true)
        // 2027 不是闰年。
        let reading = MilestoneCounter.read(item, now: day(2027, 2, 1))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(calendar.component(.month, from: reading.effectiveDate) == 2)
        #expect(calendar.component(.day, from: reading.effectiveDate) == 28)
        #expect(reading.state == .upcoming(days: 27))
    }

    @Test func leapDayStaysOnLeapYear() {
        let item = milestone(date: day(2024, 2, 29), yearly: true)
        let reading = MilestoneCounter.read(item, now: day(2028, 2, 1))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(calendar.component(.day, from: reading.effectiveDate) == 29)
    }

    // MARK: 归档

    @Test func archiveHidesPastEventsOnly() {
        let item = milestone(date: day(2027, 6, 1), expiry: .archive)
        #expect(MilestoneCounter.read(item, now: day(2027, 6, 2)).isHidden(expiry: item.expiry))
        // 到期当天还没过去，仍要显示。
        #expect(!MilestoneCounter.read(item, now: day(2027, 6, 1)).isHidden(expiry: item.expiry))
        // 未到期当然显示。
        #expect(!MilestoneCounter.read(item, now: day(2027, 5, 1)).isHidden(expiry: item.expiry))
    }

    @Test func continueCountingKeepsPastEventsVisible() {
        let item = milestone(date: day(2027, 6, 1), expiry: .continueCounting)
        #expect(!MilestoneCounter.read(item, now: day(2028, 1, 1)).isHidden(expiry: item.expiry))
    }

    // MARK: 提醒

    @Test func reminderFiresOnExactLeadDay() {
        let item = milestone(date: day(2027, 6, 20), remind: 3)
        #expect(MilestoneCounter.shouldRemind(item, now: day(2027, 6, 17)))
        #expect(!MilestoneCounter.shouldRemind(item, now: day(2027, 6, 16)))
        #expect(!MilestoneCounter.shouldRemind(item, now: day(2027, 6, 20)))
    }

    @Test func noReminderWhenDisabled() {
        let item = milestone(date: day(2027, 6, 20), remind: 0)
        #expect(!MilestoneCounter.shouldRemind(item, now: day(2027, 6, 20)))
    }

    @Test func annualReminderUsesRolledDate() {
        // 事件已过去，但每年重复滚到明年，提醒不应误触发。
        let item = milestone(date: day(2006, 3, 15), remind: 1, yearly: true)
        #expect(!MilestoneCounter.shouldRemind(item, now: day(2027, 3, 16)))
        #expect(MilestoneCounter.shouldRemind(item, now: day(2028, 3, 14)))
    }

    // MARK: 排序

    @Test func pinnedComesFirstThenNearest() {
        let soon = milestone("答辩", date: day(2027, 6, 5))
        let later = milestone("毕业", date: day(2027, 6, 30))
        let pinned = milestone("校庆", date: day(2027, 12, 1), pinned: true)
        let order = MilestoneCounter.sorted([later, soon, pinned], now: day(2027, 6, 1))
        #expect(order.map(\.title) == ["校庆", "答辩", "毕业"])
    }

    @Test func archivedSortsLast() {
        let active = milestone("在读", date: day(2027, 6, 30))
        let archived = milestone("旧事", date: day(2026, 1, 1), pinned: true, expiry: .archive)
        let order = MilestoneCounter.sorted([archived, active], now: day(2027, 6, 1))
        #expect(order.map(\.title) == ["在读", "旧事"])
    }

    // MARK: 编解码

    @Test func roundTripsThroughJSON() throws {
        let item = Milestone(title: "毕业", date: day(2027, 6, 20), direction: .countUp,
                             category: .graduation, pinned: true, reminderDaysBefore: 7,
                             repeatsAnnually: false, expiry: .archive)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(Milestone.self, from: data)
        #expect(decoded == item)
    }

    @Test func categorySymbolsAreDistinct() {
        let symbols = Set(Milestone.Category.allCases.map(\.symbol))
        #expect(symbols.count == Milestone.Category.allCases.count)
    }
}
