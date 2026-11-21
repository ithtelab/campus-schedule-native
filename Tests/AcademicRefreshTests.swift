import Foundation
import Testing
@testable import ScheduleCore

struct AcademicRefreshTests {
    @Test func scopeRejectsInsecureAndDifferentOrigins() throws {
        let entrance = try #require(URL(string: "https://jw.example.edu/login"))
        let page = try #require(URL(string: "https://jw.example.edu/portal/table?term=2026#current"))
        let scope = try #require(AcademicRefreshScope(entrance: entrance, page: page))
        #expect(scope.page.fragment == nil)
        #expect(scope.page.query == "term=2026")

        for address in ["http://jw.example.edu/table", "https://login.example.edu/table",
                        "https://jw.example.edu:8443/table", "https://user@jw.example.edu/table"] {
            let untrusted = try #require(URL(string: address))
            #expect(AcademicRefreshScope(entrance: entrance, page: untrusted) == nil)
        }
    }

    @Test func filtersCookiesBeforeReplay() throws {
        let address = try #require(URL(string: "https://jw.example.edu/portal/table"))
        let scope = try #require(AcademicRefreshScope(entrance: address, page: address))
        let now = Date(timeIntervalSince1970: 1000)
        func cookie(_ domain: String, path: String = "/portal", name: String = "session",
                    value: String = "session-token", expires: Date? = nil) -> AcademicRefreshCookie {
            .init(name: name, value: value, domain: domain, path: path, expires: expires)
        }

        #expect(cookie("jw.example.edu").isUsable(in: scope, now: now))
        #expect(cookie(".example.edu", path: "/").isUsable(in: scope, now: now))
        #expect(!cookie("example.edu").isUsable(in: scope, now: now))
        #expect(!cookie("login.example.edu").isUsable(in: scope, now: now))
        #expect(!cookie("jw.example.edu", path: "/port").isUsable(in: scope, now: now))
        #expect(!cookie("jw.example.edu", expires: now).isUsable(in: scope, now: now))
        #expect(!cookie("jw.example.edu", name: "extra=cookie").isUsable(in: scope, now: now))
        #expect(!cookie("jw.example.edu", value: "x; other=secret").isUsable(in: scope, now: now))
    }

    @Test func legacyHTTPAllowsOnlyQITAndNeverSendsSecureCookies() throws {
        let entrance = try #require(URL(string: "http://jw.qit.edu.cn/jwglxt/xtgl/login_slogin.html"))
        let page = try #require(URL(string: "http://jw.qit.edu.cn/jwglxt/kbcx/table.html"))
        let scope = try #require(AcademicRefreshScope(entrance: entrance, page: page))
        #expect(scope.usesHTTP)

        var cookie = AcademicRefreshCookie(name: "JSESSIONID", value: "sample", domain: "jw.qit.edu.cn",
                                            path: "/jwglxt", expires: nil, secure: false)
        let now = Date()
        #expect(cookie.isUsable(in: scope, now: now))
        cookie.secure = true
        #expect(!cookie.isUsable(in: scope, now: now))
        cookie.secure = nil
        #expect(!cookie.isUsable(in: scope, now: now))

        for address in ["http://jw.qit.edu.cn:8080/table", "http://other.qit.edu.cn/table",
                        "http://jw.qit.edu.cn.example.edu/table", "https://jw.qit.edu.cn/table"] {
            let other = try #require(URL(string: address))
            #expect(AcademicRefreshScope(entrance: entrance, page: other) == nil)
            #expect(AcademicRefreshScope(entrance: other, page: other)?.usesHTTP != true)
        }
    }

    @Test func comparesScheduleWithoutGuessingMovesOrCancellations() {
        let math = ParsedCourse(title: "数学", room: "302", weekday: 1, startPeriod: 3, endPeriod: 4, weeks: [1, 2])
        let english = ParsedCourse(title: "英语", weekday: 2, startPeriod: 1, endPeriod: 2)
        var moved = math
        moved.weekday = 3
        moved.room = "205"

        #expect(AcademicRefreshDiff(baseline: [math, english], latest: [english, math]).isEmpty)
        let change = AcademicRefreshDiff(baseline: [math, english], latest: [english, moved])
        #expect(change.appeared == [moved])
        #expect(change.missing == [math])
        #expect(change.changes(totalWeeks: 20) == [AcademicRefreshChange(before: math, after: moved)])
    }

    @Test func pairsAnUnchangedSlotBeforeConsideringSameNameMoves() {
        let first = ParsedCourse(title: "实验", room: "302", weekday: 0, startPeriod: 1, endPeriod: 2)
        let second = ParsedCourse(title: "实验", room: "503", weekday: 2, startPeriod: 5, endPeriod: 6)
        var firstWithNewRoom = first
        firstWithNewRoom.room = "404"
        var secondMoved = second
        secondMoved.weekday = 3
        let changes = AcademicRefreshDiff(baseline: [first, second], latest: [firstWithNewRoom, secondMoved])
            .changes(totalWeeks: 20)
        #expect(changes == [AcademicRefreshChange(before: first, after: firstWithNewRoom),
                            AcademicRefreshChange(before: second, after: secondMoved)])
    }

    @Test func keepsAmbiguousSameNameMovesSeparate() {
        let first = ParsedCourse(title: "实验", weekday: 0, startPeriod: 1, endPeriod: 2)
        let second = ParsedCourse(title: "实验", weekday: 1, startPeriod: 1, endPeriod: 2)
        let moved = ParsedCourse(title: "实验", weekday: 2, startPeriod: 1, endPeriod: 2)
        let changes = AcademicRefreshDiff(baseline: [first, second], latest: [moved]).changes(totalWeeks: 20)
        #expect(changes.count == 3)
        #expect(changes.allSatisfy { $0.before == nil || $0.after == nil })
    }

    @Test func rejectsAReplacementPageWithoutAnyPreviouslySeenCourse() {
        let math = ParsedCourse(title: "数学", weekday: 0, startPeriod: 1, endPeriod: 2)
        let biology = ParsedCourse(title: "生物", weekday: 1, startPeriod: 3, endPeriod: 4)
        var mathMoved = math
        mathMoved.weekday = 4
        #expect(AcademicRefreshDiff.hasContinuity(baseline: [math], latest: [mathMoved, biology]))
        #expect(!AcademicRefreshDiff.hasContinuity(baseline: [math], latest: [biology]))
    }
}
