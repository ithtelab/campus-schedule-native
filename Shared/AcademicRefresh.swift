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

struct AcademicRefreshChange: Hashable, Identifiable, Sendable {
    let before: ParsedCourse?
    let after: ParsedCourse?

    var id: Self { self }
}

struct AcademicRefreshDiff: Equatable, Sendable {
    let appeared: [ParsedCourse]
    let missing: [ParsedCourse]

    init(baseline: Set<ParsedCourse>, latest: Set<ParsedCourse>) {
        appeared = latest.subtracting(baseline).sorted(by: Self.earlier)
        missing = baseline.subtracting(latest).sorted(by: Self.earlier)
    }

    var isEmpty: Bool { appeared.isEmpty && missing.isEmpty }

    /// Only pair a replacement if the match is unique in both directions.
    func changes(totalWeeks: Int) -> [AcademicRefreshChange] {
        var removed = missing
        var added = appeared
        var changes: [AcademicRefreshChange] = []
        func pair(_ matches: (ParsedCourse, ParsedCourse) -> Bool) {
            for before in removed {
                let candidates = added.filter { matches(before, $0) }
                guard candidates.count == 1, let after = candidates.first,
                      removed.filter({ matches($0, after) }).count == 1 else { continue }
                changes.append(AcademicRefreshChange(before: before, after: after))
            }
            let pairedBefore = Set(changes.compactMap(\.before))
            let pairedAfter = Set(changes.compactMap(\.after))
            removed.removeAll { pairedBefore.contains($0) }
            added.removeAll { pairedAfter.contains($0) }
        }
        pair { ImportPlanner.sameIdentity($0, $1, totalWeeks: totalWeeks) }
        pair { $0.title == $1.title }
        return changes + added.map { AcademicRefreshChange(before: nil, after: $0) }
            + removed.map { AcademicRefreshChange(before: $0, after: nil) }
    }

    static func hasContinuity(baseline: Set<ParsedCourse>, latest: Set<ParsedCourse>) -> Bool {
        !Set(baseline.map(\.title)).isDisjoint(with: latest.map(\.title))
    }

    private static func earlier(_ lhs: ParsedCourse, _ rhs: ParsedCourse) -> Bool {
        let lhsSlot = (lhs.weekday, lhs.startPeriod, lhs.endPeriod)
        let rhsSlot = (rhs.weekday, rhs.startPeriod, rhs.endPeriod)
        if lhsSlot != rhsSlot { return lhsSlot < rhsSlot }
        let lhsFields = (lhs.title, lhs.teacher, lhs.room)
        let rhsFields = (rhs.title, rhs.teacher, rhs.room)
        if lhsFields != rhsFields { return lhsFields < rhsFields }
        return lhs.weeks.sorted().lexicographicallyPrecedes(rhs.weeks.sorted())
    }
}
