import Foundation
import Testing
@testable import ScheduleCore

struct SmartAgendaTests {
    var calendar: Calendar { ScheduleRules.calendar }

    /// 以某个固定日期为基准构造时刻，避免测试受运行时间影响。
    func at(_ hour: Int, _ minute: Int, day: Int = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2027, month: 3, day: 8, hour: 0, minute: 0))!
        let shifted = calendar.date(byAdding: .day, value: day, to: base)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shifted)!
    }

    func course(id: String = "c1", title: String = "大学英语", room: String = "B205",
                start: Date, end: Date) -> CourseOccurrence {
        CourseOccurrence(id: id, courseID: id, title: title, room: room,
                         start: start, end: end)
    }

    /// 用真实的 `Exam` 构造考试实例：`ExamSession` 只暴露这个失败初始化器，
    /// 测试就该走应用实际使用的同一条路径，而不是另造一个入口。
    func exam(id: String = "e1", title: String = "高等数学", start: Date, end: Date,
              room: String = "A302", seat: String = "17") -> ExamSession {
        let exam = Exam(id: id, courseTitle: title, date: start,
                        startTime: clock(start), endTime: clock(end),
                        room: room, seatNumber: seat)
        return ExamSession(exam: exam, termID: "t1")!
    }

    func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    func task(id: String = "t1", title: String = "交实验报告", courseTitle: String = "物理实验",
              due: Date, termID: String? = nil) -> AgendaTask {
        AgendaTask(id: id, courseID: "c9", courseTitle: courseTitle, title: title, due: due, termID: termID)
    }

    func milestone(id: String = "m1", title: String = "回家", date: Date,
                   direction: Milestone.Direction = .countdown,
                   pinned: Bool = false, category: Milestone.Category = .personal) -> Milestone {
        Milestone(id: id, title: title, date: date, direction: direction, category: category, pinned: pinned)
    }

    var allOn: SmartAgendaOptions { SmartAgendaOptions(allowTasks: true, allowMilestones: true) }

    func select(now: Date, courses: [CourseOccurrence] = [], exams: [ExamSession] = [],
                tasks: [AgendaTask] = [], milestones: [Milestone] = [],
                lead: Int = 10, options: SmartAgendaOptions? = nil) -> SmartAgendaSelection {
        SmartAgenda.select(courses: courses, exams: exams, tasks: tasks, milestones: milestones,
                           now: now, leadMinutes: lead, options: options ?? allOn, calendar: calendar)
    }

    // MARK: 第 1 档：考试

    @Test func examInProgressBeatsEverything() {
        let now = at(9, 30)
        let selection = select(
            now: now,
            courses: [course(start: at(9, 0), end: at(10, 0))],
            exams: [exam(start: at(9, 0), end: at(11, 0))])
        #expect(selection.primary?.kind == .exam)
        #expect(selection.primary?.status.contains("考试中") == true)
    }

    @Test func examWithinOneHourShowsExam() {
        let now = at(8, 10)
        let selection = select(now: now, exams: [exam(start: at(9, 0), end: at(11, 0))])
        #expect(selection.primary?.kind == .exam)
        #expect(selection.primary?.status == "09:00 开考")
    }

    @Test func examBeyondOneHourDoesNotTakePrimary() {
        let now = at(6, 0)
        let selection = select(now: now, exams: [exam(start: at(9, 0), end: at(11, 0))])
        // 距开考三小时，不应占据主位。
        #expect(selection.primary == nil)
    }

    @Test func examKeepsRoomAndSeat() {
        let now = at(8, 10)
        let selection = select(now: now, exams: [exam(start: at(9, 0), end: at(11, 0))])
        #expect(selection.primary?.detail == "A302 · 17 号座")
    }

    // MARK: 第 2 档：上课

    @Test func ongoingClassShowsWhenNoExamSoon() {
        let now = at(10, 15)
        let selection = select(now: now, courses: [course(start: at(10, 0), end: at(11, 35))])
        #expect(selection.primary?.kind == .course)
        #expect(selection.primary?.status.contains("正在上课") == true)
        // 上课中主数值是下课时间。
        #expect(selection.primary?.value == "11:35")
    }

    @Test func nextClassInsideLeadWindowShows() {
        let now = at(9, 55)
        let selection = select(now: now, courses: [course(start: at(10, 0), end: at(11, 35))], lead: 10)
        #expect(selection.primary?.kind == .course)
        #expect(selection.primary?.status == "今天 10:00")
    }

    @Test func nextClassOutsideLeadWindowFallsToTierFive() {
        let now = at(8, 0)
        let selection = select(now: now, courses: [course(start: at(10, 0), end: at(11, 35))], lead: 10)
        // 仍在兜底档显示，但状态不是「即将开始」的紧迫表达。
        #expect(selection.primary?.kind == .course)
        #expect(selection.primary?.urgency == .upcoming)
    }

    @Test func roomChangeKeepsTheRoomOfTheDisplayedCourse() {
        let now = at(9, 55)
        let courses = [
            course(id: "c1", title: "大学英语", room: "B205", start: at(10, 0), end: at(11, 0)),
            course(id: "c2", title: "设计基础", room: "艺术楼 401", start: at(11, 10), end: at(12, 0)),
        ]
        let before = select(now: now, courses: courses, lead: 10)
        #expect(before.primary?.title == "大学英语")
        #expect(before.primary?.detail == "B205")
        let during = select(now: at(10, 30), courses: courses, lead: 10)
        #expect(during.primary?.detail.hasPrefix("B205 · 下节去") == true)
    }

    @Test func sameRoomDoesNotAnnounceMove() {
        let now = at(10, 30)
        let selection = select(now: now, courses: [
            course(id: "c1", room: "B205", start: at(10, 0), end: at(11, 0)),
            course(id: "c2", room: "B 205", start: at(11, 10), end: at(12, 0)),
        ], lead: 10)
        #expect(selection.primary?.detail.contains("下节去") == false)
    }

    // MARK: 第 3 档：待办

    @Test func taskWithinTwoHoursShows() {
        let now = at(20, 30)
        let selection = select(now: now, tasks: [task(due: at(22, 0))])
        #expect(selection.primary?.kind == .task)
        #expect(selection.primary?.status == "22:00 截止")
    }

    @Test func taskBeyondTwoHoursDoesNotTakePrimary() {
        let now = at(18, 0)
        let selection = select(now: now, tasks: [task(due: at(22, 0))])
        #expect(selection.primary == nil)
    }

    @Test func overdueTaskNeverTakesPrimary() {
        let now = at(23, 0)
        let selection = select(now: now, tasks: [task(due: at(22, 0))])
        #expect(selection.primary == nil)
        // 但必须提示，不能静默藏起来。
        #expect(selection.overdueCount == 1)
    }

    @Test func tasksRespectToggle() {
        let now = at(20, 30)
        let selection = select(now: now, tasks: [task(due: at(22, 0)), task(id: "overdue", due: at(20, 0))],
                              options: SmartAgendaOptions(allowTasks: false, allowMilestones: true))
        #expect(selection.primary == nil)
        #expect(selection.overdueCount == 0)
    }

    @Test func taskChangesToOverdueAtTheExactTimelineBoundaryAndKeepsItsTerm() throws {
        let item = task(due: at(22, 0), termID: "previous term")
        let before = select(now: at(21, 59), tasks: [item])
        #expect(before.primary?.target == .task(courseID: "c9", termID: "previous term"))
        let boundary = select(now: item.due, tasks: [item])
        #expect(boundary.primary == nil)
        #expect(boundary.overdueCount == 1)
        let url = try #require(CourseDeepLink.tasksURL(courseID: "c9", termID: item.termID))
        #expect(CourseDeepLink.target(url) == .init(courseID: "c9", termID: "previous term", opensTasks: true))
    }

    // MARK: 第 4 档：纪念事件

    @Test func milestoneTodayShows() {
        let now = at(12, 0)
        let selection = select(now: now, milestones: [milestone(date: at(0, 0), pinned: true)])
        #expect(selection.primary?.kind == .milestone)
        #expect(selection.primary?.status == "就是今天")
    }

    @Test func milestoneWithinThreeDaysShows() {
        let now = at(12, 0)
        let selection = select(now: now, milestones: [milestone(date: at(12, 0, day: 2), pinned: true)])
        #expect(selection.primary?.kind == .milestone)
        #expect(selection.primary?.value == "2")
        #expect(selection.primary?.unit == "天")
    }

    @Test func milestoneBeyondThreeDaysDoesNotShow() {
        let now = at(12, 0)
        let selection = select(now: now, milestones: [milestone(date: at(12, 0, day: 10), pinned: true)])
        #expect(selection.primary == nil)
    }

    @Test func unpinnedMilestoneIgnoredByDefault() {
        let now = at(12, 0)
        let selection = select(now: now, milestones: [milestone(date: at(0, 0), pinned: false)])
        #expect(selection.primary == nil)
    }

    @Test func selectedMilestoneWorksEvenWhenNotPinned() {
        let now = at(12, 0)
        let item = milestone(id: "m7", title: "恋爱纪念日", date: at(0, 0), pinned: false)
        let options = SmartAgendaOptions(allowTasks: true, allowMilestones: true, milestoneID: "m7")
        let selection = select(now: now, milestones: [item], options: options)
        #expect(selection.primary?.title == "恋爱纪念日")
        #expect(selection.primary?.id == "milestone:m7")
    }

    @Test func milestonesRespectToggle() {
        let now = at(12, 0)
        let selection = select(now: now, milestones: [milestone(date: at(0, 0), pinned: true)],
                              options: SmartAgendaOptions(allowTasks: true, allowMilestones: false))
        #expect(selection.primary == nil)
    }

    @Test func ordinaryCountUpStaysSecondaryAndKeepsItsUnit() {
        let now = at(12, 0)
        let item = milestone(title: "相识", date: at(12, 0, day: -100),
                             direction: .countUp, pinned: true, category: .relationship)
        let plainDay = milestone(title: item.title, date: at(12, 0, day: -99), direction: .countUp,
                                 pinned: true, category: .relationship)
        let laterCourse = course(start: at(16, 0), end: at(17, 0))
        let selection = select(now: now, courses: [laterCourse], milestones: [plainDay])
        #expect(selection.primary?.kind == .course)
        #expect(selection.secondary?.statusWithQuantity == "一起走过 99 天")
        #expect(select(now: now, milestones: [plainDay]).primary == nil)
        #expect(select(now: now, courses: [laterCourse], milestones: [item]).primary?.statusWithQuantity == "一起走过 100 天")
    }

    @Test func pastCountdownMilestoneDoesNotShow() {
        // 倒数型已经过去，按产品定义不抢占主位（有归档设置时另行判断）。
        let now = at(12, 0)
        let item = milestone(title: "旧事", date: at(12, 0, day: -30),
                             direction: .countdown, pinned: true)
        let selection = select(now: now, milestones: [item])
        #expect(selection.primary == nil)
    }

    @Test func todayMilestoneBeatsLongRunningCountUp() {
        // 今天的期限事项比已经持续了几百天的计数器更该被看到。
        let now = at(12, 0)
        let counter = milestone(id: "m-long", title: "相识", date: at(12, 0, day: -365),
                                direction: .countUp, pinned: true)
        let today = milestone(id: "m-today", title: "回家", date: at(0, 0), pinned: true)
        let selection = select(now: now, milestones: [counter, today])
        #expect(selection.primary?.title == "回家")
    }

    // MARK: 优先级之间

    @Test func examBeatsOngoingClass() {
        let now = at(10, 15)
        let selection = select(
            now: now,
            courses: [course(start: at(10, 0), end: at(11, 35))],
            exams: [exam(start: at(10, 30), end: at(12, 0))])
        #expect(selection.primary?.kind == .exam)
    }

    @Test func ongoingClassBeatsDueTask() {
        let now = at(20, 30)
        let selection = select(
            now: now,
            courses: [course(start: at(20, 0), end: at(21, 0))],
            tasks: [task(due: at(22, 0))])
        #expect(selection.primary?.kind == .course)
    }

    @Test func dueTaskBeatsMilestone() {
        let now = at(20, 30)
        let selection = select(
            now: now,
            tasks: [task(due: at(22, 0))],
            milestones: [milestone(date: at(0, 0, day: 1), pinned: true)])
        #expect(selection.primary?.kind == .task)
    }

    @Test func secondaryHasDifferentKind() {
        let now = at(20, 30)
        let selection = select(
            now: now,
            courses: [course(start: at(20, 0), end: at(21, 0))],
            tasks: [task(due: at(22, 0))])
        #expect(selection.primary?.kind == .course)
        #expect(selection.secondary?.kind == .task)
    }

    @Test func noSecondaryOfSameKind() {
        let now = at(9, 55)
        let selection = select(now: now, courses: [
            course(id: "c1", start: at(10, 0), end: at(11, 0)),
            course(id: "c2", start: at(11, 10), end: at(12, 0)),
        ], lead: 10)
        #expect(selection.primary?.kind == .course)
        #expect(selection.secondary == nil)
    }

    // MARK: 空与稳定性

    @Test func emptySelectionWhenNothingApplies() {
        let selection = select(now: at(3, 0))
        #expect(selection.isEmpty)
        #expect(selection.secondary == nil)
    }

    @Test func selectionIsStableAcrossRepeatedCalls() {
        let now = at(20, 30)
        let courses = [course(start: at(20, 0), end: at(21, 0))]
        let tasks = [task(due: at(22, 0))]
        let first = select(now: now, courses: courses, tasks: tasks)
        let second = select(now: now, courses: courses, tasks: tasks)
        #expect(first == second)
    }

    @Test func simultaneousCoursesDoNotDependOnInputOrder() {
        let first = course(id: "a", start: at(10, 0), end: at(11, 0))
        let second = course(id: "b", start: at(10, 0), end: at(11, 0))
        let forward = select(now: at(10, 15), courses: [first, second])
        let reverse = select(now: at(10, 15), courses: [second, first])
        #expect(forward == reverse)
        #expect(forward.primary?.id == "course:a")
    }

    @Test func soonerMomentWinsWithinSameTier() {
        let now = at(8, 0)
        let selection = select(now: now, exams: [
            exam(id: "e1", title: "晚一点", start: at(8, 50), end: at(10, 0)),
            exam(id: "e2", title: "早一点", start: at(8, 20), end: at(9, 0)),
        ])
        #expect(selection.primary?.title == "早一点")
    }

    // MARK: 时间线

    @Test func switchDatesIncludeCourseAndExamTransitions() {
        let now = at(8, 0)
        let dates = SmartAgenda.switchDates(
            courses: [course(start: at(10, 0), end: at(11, 0))],
            exams: [exam(start: at(14, 0), end: at(16, 0))],
            tasks: [], milestones: [], now: now, leadMinutes: 10,
            options: allOn, calendar: calendar)
        #expect(dates.contains(at(10, 0)))
        #expect(dates.contains(at(11, 0)))
        #expect(dates.contains(at(14, 0)))
        #expect(dates.contains(at(16, 0)))
        // 课前十分钟提醒阈值也要重算，否则「即将开始」不会及时出现。
        #expect(dates.contains(at(9, 50)))
    }

    @Test func switchDatesIncludeTaskThresholdsOnlyWhenAllowed() {
        let now = at(18, 0)
        let withTasks = SmartAgenda.switchDates(
            courses: [], exams: [], tasks: [task(due: at(22, 0))], milestones: [],
            now: now, leadMinutes: 10, options: allOn, calendar: calendar)
        #expect(withTasks.contains(at(22, 0)))
        #expect(withTasks.contains(at(20, 0)))

        let withoutTasks = SmartAgenda.switchDates(
            courses: [], exams: [], tasks: [task(due: at(22, 0))], milestones: [],
            now: now, leadMinutes: 10,
            options: SmartAgendaOptions(allowTasks: false, allowMilestones: false), calendar: calendar)
        #expect(!withoutTasks.contains(at(20, 0)))
    }

    @Test func switchDatesAlwaysIncludeMidnight() {
        let now = at(8, 0)
        let dates = SmartAgenda.switchDates(courses: [], exams: [], tasks: [], milestones: [],
                                            now: now, leadMinutes: 10, options: allOn,
                                            calendar: calendar)
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        #expect(dates.contains(midnight))
    }

    @Test func switchDatesAreSortedAndBounded() {
        let now = at(8, 0)
        let many = (0..<40).map { index in
            course(id: "c\(index)", start: at(9, 0, day: index % 3), end: at(10, 0, day: index % 3))
        }
        let dates = SmartAgenda.switchDates(courses: many, exams: [], tasks: [], milestones: [],
                                            now: now, leadMinutes: 10, options: allOn,
                                            limit: 20, calendar: calendar)
        #expect(dates.count <= 20)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= now })
    }

    @Test func horizonExcludesFarFutureTransitions() {
        let now = at(8, 0)
        let dates = SmartAgenda.switchDates(
            courses: [course(start: at(10, 0, day: 5), end: at(11, 0, day: 5))],
            exams: [], tasks: [], milestones: [], now: now, leadMinutes: 10,
            options: allOn, horizonHours: 48, calendar: calendar)
        #expect(!dates.contains(at(10, 0, day: 5)))
    }

    // MARK: 无障碍

    @Test func accessibilityTextJoinsFields() {
        let item = SmartAgendaItem(id: "x", kind: .exam, status: "09:00 开考", title: "高等数学",
                                   detail: "A302 · 17 号座", value: "09:00",
                                   urgency: .imminent, target: .exam(id: "e1", termID: "t1"))
        #expect(item.accessibilityText == "09:00 开考，高等数学，A302 · 17 号座")
    }

    @Test func accessibilityTextKeepsUnitWithNumber() {
        let item = SmartAgendaItem(id: "x", kind: .milestone, status: "还有", title: "回家",
                                   detail: "3 月 10 日", value: "2", unit: "天",
                                   urgency: .distant, target: .milestone(id: "m1"))
        #expect(item.accessibilityText == "还有 2 天，回家，3 月 10 日")
    }
}
