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
    }
}
