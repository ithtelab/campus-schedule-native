import Foundation

/// A reusable session can read only the selected origin, with one legacy HTTP exception.
struct AcademicRefreshScope: Codable, Equatable, Sendable {
    private static let legacyHTTPHost = "jw.qit.edu.cn"
    let entrance: URL
    let page: URL

    init?(entrance: URL, page: URL) {
        guard let scheme = entrance.scheme?.lowercased(), scheme == page.scheme?.lowercased(),
              let host = entrance.host?.lowercased(), !host.isEmpty, host == page.host?.lowercased(),
              entrance.user == nil, entrance.password == nil, page.user == nil, page.password == nil,
              var components = URLComponents(url: page, resolvingAgainstBaseURL: false) else { return nil }
        switch scheme {
        case "https":
            guard (entrance.port ?? 443) == (page.port ?? 443) else { return nil }
        case "http":
            guard host == Self.legacyHTTPHost, (entrance.port ?? 80) == 80, (page.port ?? 80) == 80 else { return nil }
        default:
            return nil
        }
        components.fragment = nil
        guard let cleanPage = components.url else { return nil }
        self.entrance = entrance
        self.page = cleanPage
    }

    var usesHTTP: Bool { page.scheme?.lowercased() == "http" }

    var cookiePath: String {
        let path = URLComponents(url: page, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
        return path.isEmpty ? "/" : path
    }
}

struct AcademicRefreshCookie: Codable, Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expires: Date?
    var secure: Bool? = nil

    func isUsable(in scope: AcademicRefreshScope, now: Date) -> Bool {
        guard !scope.usesHTTP || secure == false,
              expires.map({ $0 > now }) ?? true, !name.isEmpty, path.hasPrefix("/"),
              name.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 && !Self.nameSeparators.contains($0) }),
              value.utf8.allSatisfy({ $0 >= 33 && $0 <= 126 && $0 != 59 }),
              let host = scope.page.host?.lowercased() else { return false }
        let lowerDomain = domain.lowercased()
        let domainName = lowerDomain.hasPrefix(".") ? String(lowerDomain.dropFirst()) : lowerDomain
        guard !domainName.isEmpty, host == domainName || (lowerDomain.hasPrefix(".") && host.hasSuffix("." + domainName)) else {
            return false
        }
        let requestPath = scope.cookiePath
        return requestPath == path || requestPath.hasPrefix(path.hasSuffix("/") ? path : path + "/")
    }

    private static let nameSeparators = Set("()<>@,;:\\\"/[]?={}".utf8)
}

struct AcademicRefreshDiff: Equatable, Sendable {
    let appeared: [ParsedCourse]
    let missing: [ParsedCourse]

    init(baseline: Set<ParsedCourse>, latest: Set<ParsedCourse>) {
        appeared = latest.subtracting(baseline).sorted(by: Self.earlier)
        missing = baseline.subtracting(latest).sorted(by: Self.earlier)
    }

    var isEmpty: Bool { appeared.isEmpty && missing.isEmpty }

    private static func earlier(_ lhs: ParsedCourse, _ rhs: ParsedCourse) -> Bool {
        (lhs.weekday, lhs.startPeriod, lhs.title) < (rhs.weekday, rhs.startPeriod, rhs.title)
    }
}
