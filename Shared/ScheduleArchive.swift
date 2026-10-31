import Foundation

/// 版本化的课表备份格式。
///
/// 内部模型会继续演进，但已经导出的文件必须始终能读回来，因此这里使用独立的
/// 传输结构，而不是直接编码 `DemoCourse`。字段一律用原始类型，不引用界面层类型。
///
/// `semesters` 是数组，即使当前只写一个学期：多学期功能上线后，旧文件仍然有效，
/// 新文件也只是多填几个元素，不需要再升版本重新设计。
public struct ScheduleArchive: Codable, Equatable {
    /// 当前写出的格式版本。读取时接受 1...currentSchema，超出范围明确报错而不是猜。
    public static let currentSchema = 1

    public var schema: Int
    public var exportedAt: Date
    public var appVersion: String?
    public var semesters: [ArchivedSemester]

    public init(schema: Int = ScheduleArchive.currentSchema, exportedAt: Date = Date(),
                appVersion: String? = nil, semesters: [ArchivedSemester]) {
        self.schema = schema
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.semesters = semesters
    }
}

public struct ArchivedSemester: Codable, Equatable {
    public var id: String
    public var name: String
    public var startDate: Date
    public var totalWeeks: Int
    public var periods: [ArchivedPeriod]
    public var courses: [ArchivedCourse]
    public var exceptions: [ArchivedException]

    public init(id: String, name: String, startDate: Date, totalWeeks: Int,
                periods: [ArchivedPeriod], courses: [ArchivedCourse], exceptions: [ArchivedException]) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.totalWeeks = totalWeeks
        self.periods = periods
        self.courses = courses
        self.exceptions = exceptions
    }
}

public struct ArchivedPeriod: Codable, Equatable {
    public var index: Int
    public var start: String
    public var end: String

    public init(index: Int, start: String, end: String) {
        self.index = index
        self.start = start
        self.end = end
    }
}

public struct ArchivedCourse: Codable, Equatable {
    public var id: String
    public var sourceID: String?
    public var title: String
    public var room: String
    public var teacher: String
    /// 0 表示周一，与内部模型一致。
    public var weekday: Int
    public var startPeriod: Int
    public var endPeriod: Int
    /// 内部 `CourseColor` 的原始值，例如 "blue"。未知值导入时回退到默认色。
    public var color: String
    public var weeks: [Int]
    public var remindersEnabled: Bool

    public init(id: String, sourceID: String? = nil, title: String, room: String, teacher: String,
                weekday: Int, startPeriod: Int, endPeriod: Int, color: String, weeks: [Int],
                remindersEnabled: Bool = true) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.room = room
        self.teacher = teacher
        self.weekday = weekday
        self.startPeriod = startPeriod
        self.endPeriod = endPeriod
        self.color = color
        self.weeks = weeks
        self.remindersEnabled = remindersEnabled
    }
}

public struct ArchivedException: Codable, Equatable {
    public var id: String
    public var courseID: String
    public var day: Date
    public var cancelled: Bool
    public var start: Date?
    public var end: Date?
    public var room: String?

    public init(id: String, courseID: String, day: Date, cancelled: Bool = false,
                start: Date? = nil, end: Date? = nil, room: String? = nil) {
        self.id = id
        self.courseID = courseID
        self.day = day
        self.cancelled = cancelled
        self.start = start
        self.end = end
        self.room = room
    }
}

// MARK: - 校验

public enum ArchiveError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case emptySemesterList
    case tooManySemesters(Int)
    case invalidTotalWeeks(Int)
    case emptyPeriods(String)
    case nonPositivePeriod(String, Int)
    case malformedTime(String, String)
    case duplicatePeriodIndex(String, Int)
    case courseOutsidePeriodRange(String, String)
    case invalidWeekday(String, Int)
    case invalidPeriodRange(String, String)
    case weeksOutsideTerm(String, String)
    case duplicateCourseID(String)
    case duplicateSemesterID(String)
    case duplicateExceptionID(String)
    case exceptionWithoutCourse(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "备份格式版本 \(version) 不受支持，请升级 App 后再试。"
        case .emptySemesterList:
            "备份里没有任何学期数据。"
        case .tooManySemesters(let count):
            "备份包含 \(count) 个学期，超出当前版本可处理的数量。"
        case .invalidTotalWeeks(let weeks):
            "学期总周数 \(weeks) 不在 1…53 范围内。"
        case .emptyPeriods(let semester):
            "「\(semester)」没有任何节次时间。"
        case .nonPositivePeriod(let semester, let index):
            "「\(semester)」的节次编号 \(index) 必须为正数。"
        case .malformedTime(let semester, let value):
            "「\(semester)」的时间「\(value)」不是 HH:mm 格式。"
        case .duplicatePeriodIndex(let semester, let index):
            "「\(semester)」的节次 \(index) 重复出现。"
        case .courseOutsidePeriodRange(let title, let semester):
            "课程「\(title)」引用了「\(semester)」不存在的节次。"
        case .invalidWeekday(let title, let weekday):
            "课程「\(title)」的星期 \(weekday) 不在 0…6 范围内。"
        case .invalidPeriodRange(let title, let semester):
            "课程「\(title)」的开始节次不在有效范围内，或结束节次早于开始节次。"
        case .weeksOutsideTerm(let title, let semester):
            "课程「\(title)」的周次超出「\(semester)」的学期范围。"
        case .duplicateCourseID(let id):
            "课程标识 \(id) 重复出现。"
        case .duplicateSemesterID(let id):
            "学期标识 \(id) 重复出现。"
        case .duplicateExceptionID(let id):
            "调课记录标识 \(id) 重复出现。"
        case .exceptionWithoutCourse(let id):
            "调课记录指向了不存在的课程 \(id)。"
        }
    }
}

public extension ScheduleArchive {
    /// 严格校验，任何可疑数据都报错而不是静默修正，避免导入后数据悄悄变形。
    func validated() throws -> ScheduleArchive {
        guard schema >= 1, schema <= ScheduleArchive.currentSchema else {
            throw ArchiveError.unsupportedSchema(schema)
        }
        guard !semesters.isEmpty else { throw ArchiveError.emptySemesterList }
        guard semesters.count <= 4 else { throw ArchiveError.tooManySemesters(semesters.count) }

        var semesterIDs = Set<String>()
        var totalCourses = 0
        for semester in semesters {
            guard semesterIDs.insert(semester.id).inserted else {
                throw ArchiveError.duplicateSemesterID(semester.id)
            }
            guard (1...53).contains(semester.totalWeeks) else {
                throw ArchiveError.invalidTotalWeeks(semester.totalWeeks)
            }
            guard !semester.periods.isEmpty else { throw ArchiveError.emptyPeriods(semester.name) }

            var indices = Set<Int>()
            for period in semester.periods {
                guard period.index > 0 else { throw ArchiveError.nonPositivePeriod(semester.name, period.index) }
                guard indices.insert(period.index).inserted else {
                    throw ArchiveError.duplicatePeriodIndex(semester.name, period.index)
                }
                guard Self.isClockTime(period.start), Self.isClockTime(period.end) else {
                    throw ArchiveError.malformedTime(
                        semester.name,
                        Self.isClockTime(period.start) ? period.end : period.start
                    )
                }
            }
            let highest = indices.max() ?? 0

            var courseIDs = Set<String>()
            for course in semester.courses {
                totalCourses += 1
                guard courseIDs.insert(course.id).inserted else {
                    throw ArchiveError.duplicateCourseID(course.id)
                }
                guard (0...6).contains(course.weekday) else {
                    throw ArchiveError.invalidWeekday(course.title, course.weekday)
                }
                guard course.startPeriod > 0, course.endPeriod >= course.startPeriod,
                      indices.contains(course.startPeriod), indices.contains(course.endPeriod),
                      course.endPeriod <= highest else {
                    throw ArchiveError.invalidPeriodRange(course.title, semester.name)
                }
                guard course.weeks.allSatisfy({ $0 >= 1 && $0 <= semester.totalWeeks }), !course.weeks.isEmpty else {
                    throw ArchiveError.weeksOutsideTerm(course.title, semester.name)
                }
            }

            var exceptionIDs = Set<String>()
            for exception in semester.exceptions {
                guard exceptionIDs.insert(exception.id).inserted else {
                    throw ArchiveError.duplicateExceptionID(exception.id)
                }
                guard courseIDs.contains(exception.courseID) else {
                    throw ArchiveError.exceptionWithoutCourse(exception.courseID)
                }
            }
        }
        guard totalCourses > 0 else { throw ArchiveError.emptySemesterList }
        return self
    }

    /// 只接受 00:00…23:59 的定点时间，拒绝 "8:00"、"24:00" 这类会静默偏移的写法。
    static func isClockTime(_ value: String) -> Bool {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }

    var courseCount: Int { semesters.reduce(0) { $0 + $1.courses.count } }

    /// 人类可读的摘要，用于导入前的确认提示。
    var summary: String {
        let names = semesters.map(\.name).joined(separator: "、")
        return "\(names) · \(semesters.first?.totalWeeks ?? 0) 周 · \(courseCount) 门课程 · \(semesters.first?.exceptions.count ?? 0) 条调课"
    }
}

// MARK: - 编解码

public extension ScheduleArchive {
    /// 导出的字节应当可读、可 diff，便于用户自己检查，也便于排查问题。
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = iso8601.date(from: text) { return date }
            if let date = iso8601NoFraction.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析时间 \(text)")
        }
        return decoder
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601NoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func encoded() throws -> Data { try Self.encoder().encode(self) }

    /// 解码并立即校验，导入路径应优先使用这个入口。
    static func decoded(from data: Data) throws -> ScheduleArchive {
        try decodedUnvalidated(from: data).validated()
    }

    /// 只解码不校验：仅在需要展示原始内容做诊断时使用。
    static func decodedUnvalidated(from data: Data) throws -> ScheduleArchive {
        try decoder().decode(ScheduleArchive.self, from: data)
    }
}
