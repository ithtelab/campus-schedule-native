import Foundation
import Testing
@testable import ScheduleCore

struct NowStatusTests {
    let calendar = ScheduleRules.calendar
    let day: Date

    init() {
        day = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 10, day: 28))!
    }

    func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    func occurrence(_ title: String, room: String = "A302", from: Int, to: Int) -> CourseOccurrence {
        CourseOccurrence(id: title, courseID: title, title: title, room: room,
                         start: at(from, 0), end: at(to, 0))
    }

    // MARK: 正在上课

    @Test func detectsOngoingClass() {
        let phase = NowStatus.phase(for: [occurrence("高等数学", from: 8, to: 10)], now: at(9, 0))
        #expect(phase == .inClass(title: "高等数学", room: "A302", minutesLeft: 60))
    }

    @Test func minutesLeftRoundsUp() {
        // 9:30 时距 10:00 还有 30 分钟整。
        let phase = NowStatus.phase(for: [occurrence("课", from: 8, to: 10)], now: at(9, 30))
        #expect(phase == .inClass(title: "课", room: "A302", minutesLeft: 30))
    }

    @Test func lastMinuteStillCountsAsInClass() {
        let phase = NowStatus.phase(for: [occurrence("课", from: 8, to: 10)], now: at(9, 59))
        #expect(phase == .inClass(title: "课", room: "A302", minutesLeft: 1))
    }

    @Test func classEndingExactlyNowIsNotInClass() {
        let phase = NowStatus.phase(for: [occurrence("课", from: 8, to: 10)], now: at(10, 0))
        // 10:00 时该课已结束，且没有下一节，所以是 finished。
        #expect(phase == .finished(classesToday: 1))
    }

    @Test func ongoingTakesPrecedenceOverUpcoming() {
        let items = [occurrence("正在上", from: 8, to: 10), occurrence("下一节", from: 11, to: 12)]
        let phase = NowStatus.phase(for: items, now: at(9, 0))
        #expect(NowStatus.title(phase) == "正在上")
    }

    // MARK: 下一节

    @Test func reportsNextClassWithMinutes() {
        let phase = NowStatus.phase(for: [occurrence("设计基础", room: "艺术 401", from: 14, to: 16)],
                                    now: at(13, 0))
        #expect(phase == .upcoming(title: "设计基础", room: "艺术 401",
                                   minutesUntil: 60, startsAt: "14:00"))
    }

    @Test func detailUsesMinutesWithinHalfHour() {
        let phase = NowStatus.phase(for: [occurrence("课", room: "A302", from: 14, to: 16)], now: at(13, 40))
        #expect(NowStatus.detail(phase)?.contains("20 分钟后") == true)
    }

    @Test func detailUsesClockTimeWhenFarAway() {
        let phase = NowStatus.phase(for: [occurrence("课", room: "A302", from: 18, to: 20)], now: at(9, 0))
        #expect(NowStatus.detail(phase)?.contains("18:00 开始") == true)
    }

    @Test func emptyRoomOmitsSeparator() {
        let phase = NowStatus.phase(for: [occurrence("课", room: "", from: 14, to: 16)], now: at(13, 40))
        #expect(NowStatus.detail(phase)?.hasPrefix("20 分钟后") == true)
    }

    // MARK: 结束与空

    @Test func allClassesFinished() {
        let phase = NowStatus.phase(for: [occurrence("早课", from: 8, to: 10)], now: at(12, 0))
        #expect(phase == .finished(classesToday: 1))
    }

    @Test func noClassesToday() {
        #expect(NowStatus.phase(for: [], now: at(9, 0)) == .none)
    }

    @Test func ignoresOtherDays() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let other = CourseOccurrence(id: "x", courseID: "x", title: "明天", room: "A",
                                     start: tomorrow, end: tomorrow.addingTimeInterval(3600))
        #expect(NowStatus.phase(for: [other], now: at(9, 0)) == .none)
    }

    // MARK: 文案

    @Test func finishedAndNoneHaveNoTitle() {
        #expect(NowStatus.title(.finished(classesToday: 3)) == nil)
        #expect(NowStatus.title(.none) == nil)
    }

    @Test func inClassIsUrgent() {
        #expect(NowStatus.isUrgent(.inClass(title: "x", room: "", minutesLeft: 5)))
        #expect(!NowStatus.isUrgent(.upcoming(title: "x", room: "", minutesUntil: 5, startsAt: "10:00")))
        #expect(!NowStatus.isUrgent(.none))
    }

    @Test func zeroMinutesReadsAsEndingSoon() {
        let phase = NowStatus.Phase.inClass(title: "课", room: "A302", minutesLeft: 0)
        #expect(NowStatus.detail(phase)?.contains("即将下课") == true)
    }

    @Test func clockFormatsAsHHmm() {
        #expect(NowStatus.clock(at(8, 5)) == "08:05")
    }
}
