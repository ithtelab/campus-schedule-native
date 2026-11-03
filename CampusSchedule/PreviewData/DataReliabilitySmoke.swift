import Foundation

/// 只由 CI 环境变量触发；实例为纯内存，不加载或写入用户 SwiftData。
@MainActor enum DataReliabilitySmoke {
    static func run() -> String {
        var failures: [String] = []
        func check(_ condition: Bool, _ name: String) { if !condition { failures.append(name) } }
        let store = PreviewStore(testingInMemory: true)
        guard let course = store.courses.first else { return "FAIL: missing in-memory fixture" }
        let exception = CourseException(courseID: course.id, day: store.date(week: 1, day: course.weekday), cancelled: true)
        store.exceptions = [exception]
        let parsed = ParsedCourse(title: course.title, teacher: course.teacher, room: "新教室",
            weekday: course.weekday, startPeriod: course.startPeriod, endPeriod: course.endPeriod, weeks: course.weeks)
        let plan = store.makeImportPlan(.init(courses: [parsed]))
        check(store.applyImport(plan) == 1 && store.applyImport(plan) == 1, "repeat import count")
        check(store.courses.filter { $0.id == course.id }.count == 1, "stable course identity")
        check(store.exceptions.contains { $0.id == exception.id && $0.courseID == course.id }, "exception association")
        let odd = ParsedCourse(title: "单双周用例", weekday: 2, startPeriod: 3, endPeriod: 4, weeks: [1, 3])
        var even = odd; even.weeks = [2, 4]
        check(store.applyImport([odd, even]) == 2, "separate week sets")
        check(store.courses.filter { $0.title == odd.title }.count == 2, "odd and even retained")
        let sourceTerm = store.activeTermID
        let stalePlan = store.makeImportPlan(.init(courses: [parsed]))
        let newTerm = store.addTerm()
        store.selectTerm(newTerm)
        check(store.applyImport(stalePlan) == 0 && store.courses.isEmpty, "stale import target")
        store.selectTerm(sourceTerm)
        let late = DemoCourse(id: "late", title: "晚间课程", room: "A302", teacher: "",
            weekday: 1, startPeriod: 9, endPeriod: 10, startTime: "19:00", endTime: "20:35", color: .blue)
        store.courses.append(late)
        store.exceptions.append(CourseException(courseID: late.id, day: store.date(week: 1, day: 1), cancelled: true))
        check(store.applyAcademicSettings(termID: sourceTerm, name: store.semesterName, start: store.semesterStart,
            weeks: 16, periods: Array(store.periods.prefix(8))), "atomic academic update")
        check(!store.courses.contains { $0.id == late.id }, "new period boundary")
        check(!store.exceptions.contains { $0.courseID == late.id }, "removed course exceptions")
        check(store.courses.allSatisfy { $0.weeks.allSatisfy { (1...16).contains($0) } }, "clamped weeks")
        let original = Data("unreadable-original".utf8)
        let damaged = PreviewStore(testingInMemory: true, recoveryTestData: original)
        damaged.courses.append(course)
        check(damaged.storageReadOnly && damaged.courses.isEmpty && !damaged.save(), "failed read blocks edits and saves")
        check((try? damaged.recoveryDataForExport()) == original, "original bytes preserved")
        return failures.isEmpty ? "PASS: in-memory store import identities, week sets, target checks, academic commit and read protection" : "FAIL: " + failures.joined(separator: ", ")
    }
}
