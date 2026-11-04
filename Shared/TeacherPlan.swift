import Foundation

/// 使用身份。
///
/// 身份决定信息呈现与快捷操作，不改变课程时间，也不删除任何数据。
/// 切换随时可以，同一用户可以同时保留学生与教师的安排。
///
/// 原始值是稳定的英文标识：展示文案随时可能改措辞，参与持久化后改文案就等于丢数据。
public enum CampusRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case student
    case teacher

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .student: "学生"
        case .teacher: "教师"
        }
    }

    /// 课程卡上第二个信息的标题：学生看任课教师，教师看教学班。
    public var courseContactLabel: String {
        switch self {
        case .student: "教师"
        case .teacher: "教学班"
        }
    }
}

/// 某一次授课的备课状态。
///
/// 按**这一次课**记录，而不是按整门课：同一门课每周内容不同，第 3 周备过不代表
/// 第 4 周备过。键使用 `CourseOccurrence.id`，它由课程标识加原定日期组成，调课后
/// 仍指向同一堂课。
public struct PrepRecord: Codable, Equatable, Sendable {
    public var prepared: Bool
    public var updatedAt: Date

    public init(prepared: Bool, updatedAt: Date = Date()) {
        self.prepared = prepared
        self.updatedAt = updatedAt
    }
}

public enum PrepPlan {
    /// 标记或取消标记某一次课。
    public static func toggle(_ records: [String: PrepRecord], occurrenceID: String,
                              now: Date = Date()) -> [String: PrepRecord] {
        var result = records
        let next = !(result[occurrenceID]?.prepared ?? false)
        result[occurrenceID] = PrepRecord(prepared: next, updatedAt: now)
        // 取消标记时直接移除条目，避免长期积累无意义的 false。
        if !next { result.removeValue(forKey: occurrenceID) }
        return result
    }

    /// 清理不再存在的课程实例。
    ///
    /// 学期起止日期改变会让所有实例标识重算，旧记录因此变成孤儿。不清理的话
    /// 备份里会永久保留一批指向不存在课程的键。
    public static func prune(_ records: [String: PrepRecord],
                             keeping occurrenceIDs: Set<String>) -> [String: PrepRecord] {
        records.filter { occurrenceIDs.contains($0.key) }
    }

    /// 是否已备课。
    public static func isPrepared(_ records: [String: PrepRecord], occurrenceID: String) -> Bool {
        records[occurrenceID]?.prepared ?? false
    }

    /// 已备课的次数，用于教师视角的进度提示。
    public static func preparedCount(_ records: [String: PrepRecord], in occurrenceIDs: Set<String>) -> Int {
        occurrenceIDs.reduce(0) { count, id in
            count + (isPrepared(records, occurrenceID: id) ? 1 : 0)
        }
    }
}
