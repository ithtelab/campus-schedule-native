import BackgroundTasks
import CoreFoundation
import Foundation
import Observation
import Security
import UserNotifications

@MainActor @Observable
final class AcademicRefreshService {
    static let shared = AcademicRefreshService()
    nonisolated static let taskID = "com.ithtelab.campustimetable.academic-refresh"
    private static let interval: TimeInterval = 6 * 60 * 60

    struct Connection: Codable {
        let id: UUID
        let school: String
        let term: String
        let scope: AcademicRefreshScope
        let totalWeeks: Int
        let numbering: String
        let expires: Date
        var cookies: [AcademicRefreshCookie]
        var baseline: Set<ParsedCourse>
        var latest: Set<ParsedCourse>
        var checkedAt: Date
        var attemptedAt: Date
        var needsLogin = false

        var diff: AcademicRefreshDiff { .init(baseline: baseline, latest: latest) }
    }

    private(set) var connection: Connection?
    private(set) var busy = false
    private(set) var message: String?
    private var revision = UUID()

    func restore() {
        guard connection == nil, !busy else { return }
        do { connection = try AcademicRefreshKeychain.read() }
        catch { message = error.localizedDescription }
    }

    /// Enroll only if a fresh GET with the captured cookies reproduces the exact table the user reviewed.
    func connect(school: String, term: String, scope: AcademicRefreshScope, totalWeeks: Int,
                 numbering: AcademicSystemProfile.WeekdayNumbering, cookies: [AcademicRefreshCookie],
                 baseline: Set<ParsedCourse>) async {
        guard !busy else { return }
        let now = Date()
        let candidate = Connection(id: UUID(), school: school, term: term, scope: scope, totalWeeks: totalWeeks,
                                   numbering: numbering.rawValue, expires: now.addingTimeInterval(7 * 24 * 3600),
                                   cookies: cookies.filter { $0.isUsable(in: scope, now: now) }, baseline: baseline,
                                   latest: baseline, checkedAt: now, attemptedAt: now)
        busy = true
        message = nil
        let currentRevision = revision
        defer { busy = false; scheduleNext() }
        do {
            guard try await Self.fetch(candidate) == baseline else { throw RefreshError.notReplayable }
            try Task.checkCancellation()
            guard revision == currentRevision else { return }
            try save(candidate)
        } catch is CancellationError {
        } catch {
            guard revision == currentRevision, !Task.isCancelled else { return }
            message = "未开启自动检查。\(error.localizedDescription)"
        }
    }

    func check(force: Bool = false) async {
        restore()
        guard !busy, var active = connection, !active.needsLogin else { return }
        let now = Date()
        guard force || now.timeIntervalSince(active.attemptedAt) >= Self.interval else {
            scheduleNext()
            return
        }
        busy = true
        message = nil
        let currentRevision = revision
        defer { busy = false; scheduleNext() }
        do {
            active.attemptedAt = now
            try save(active)
            let latest = try await Self.fetch(active)
            try Task.checkCancellation()
            guard revision == currentRevision, !Task.isCancelled else { return }
            let changed = latest != active.latest && latest != active.baseline
            active.latest = latest
            active.checkedAt = Date()
            try save(active)
            if changed { await alertIfAllowed(revision: currentRevision) }
        } catch is CancellationError {
        } catch {
            guard revision == currentRevision else { return }
            if (error as? RefreshError) == .needsLogin {
                active.needsLogin = true
                active.cookies = []
                do { try save(active) }
                catch { message = error.localizedDescription; return }
            }
            message = error.localizedDescription
        }
    }

    func markReviewed(id: UUID, latest: Set<ParsedCourse>) {
        guard !busy, var active = connection, active.id == id, active.latest == latest else { return }
        active.baseline = latest
        do { try save(active); message = nil }
        catch { message = error.localizedDescription }
    }

    func disconnect() {
        do {
            try AcademicRefreshKeychain.remove()
            revision = UUID()
            connection = nil
            message = nil
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskID)
        } catch { message = error.localizedDescription }
    }

    private func save(_ active: Connection) throws {
        try AcademicRefreshKeychain.write(active)
        connection = active
    }

    private func scheduleNext() {
        guard let active = connection, !active.needsLogin else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = max(Date().addingTimeInterval(60), active.attemptedAt.addingTimeInterval(Self.interval))
        do { try BGTaskScheduler.shared.submit(request) }
        catch {
            if message == nil { message = "后台刷新暂不可用。打开 App 时仍会检查。" }
        }
    }

    private func alertIfAllowed(revision currentRevision: UUID) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard revision == currentRevision, !Task.isCancelled,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "教务课表有变化"
        content.body = "打开课间册，在「导入课表」里核对新旧安排。"
        try? await center.add(UNNotificationRequest(identifier: "academic.refresh.changes", content: content, trigger: nil))
    }

    private static func fetch(_ active: Connection) async throws -> Set<ParsedCourse> {
        let now = Date()
        guard let scope = AcademicRefreshScope(entrance: active.scope.entrance, page: active.scope.page),
              scope == active.scope else { throw RefreshError.notReplayable }
        let cookies = active.cookies.filter { $0.isUsable(in: scope, now: now) }
        guard active.expires > now, !cookies.isEmpty else { throw RefreshError.needsLogin }
        var request = URLRequest(url: scope.page, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue(WebContentCollector.desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(cookies.sorted { $0.path.count > $1.path.count }.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                         forHTTPHeaderField: "Cookie")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForResource = 18
        let session = URLSession(configuration: configuration, delegate: AcademicNoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw RefreshError.notReplayable }
        if (300..<400).contains(http.statusCode) || http.statusCode == 401 || http.statusCode == 403 {
            throw RefreshError.needsLogin
        }
        guard http.statusCode == 200 else { throw RefreshError.unavailable }
        let limit = 4 * 1024 * 1024
        guard http.expectedContentLength <= limit else { throw RefreshError.notReplayable }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw RefreshError.notReplayable }
            data.append(byte)
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: gb18030) else {
            throw RefreshError.notReplayable
        }
        let numbering = AcademicSystemProfile.WeekdayNumbering(rawValue: active.numbering) ?? .automatic
        let result = await Task.detached(priority: .utility) {
            AcademicSystemProfile.parsePage(html, totalWeeks: active.totalWeeks, numbering: numbering)
        }.value
        guard !result.courses.isEmpty, result.courses.count <= 400, result.warnings.isEmpty else {
            throw RefreshError.notReplayable
        }
        return Set(result.courses)
    }

    private enum RefreshError: LocalizedError, Equatable {
        case needsLogin, notReplayable, unavailable

        var errorDescription: String? {
            switch self {
            case .needsLogin: "教务登录已失效或页面要求重新验证。请重新登录并提取课表。"
            case .notReplayable: "无法直接读取与导入时一致的教务课表。请打开教务网页核对。"
            case .unavailable: "暂时无法读取教务课表。"
            }
        }
    }
}

private final class AcademicNoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
private enum AcademicRefreshKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: AcademicRefreshService.taskID,
         kSecAttrAccount as String: "active-school",
         kSecAttrSynchronizable as String: false]
    }

    static func read() throws -> AcademicRefreshService.Connection? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw unavailable }
        return try JSONDecoder().decode(AcademicRefreshService.Connection.self, from: data)
    }

    static func write(_ connection: AcademicRefreshService.Connection) throws {
        let data = try JSONEncoder().encode(connection)
        guard data.count <= 256 * 1024 else { throw unavailable }
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw unavailable }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw unavailable }
    }

    private static var unavailable: any Error {
        NSError(domain: "AcademicRefresh", code: 1, userInfo: [NSLocalizedDescriptionKey: "暂时无法访问本机钥匙串。请解锁设备后重试。"])
    }
}
