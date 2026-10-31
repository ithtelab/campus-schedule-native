import Foundation

/// 一份带时间戳的同步载荷。
///
/// 时间戳和内容一起存储，因为只看云端 `updatedAt` 无法区分「本地没改过」和
/// 「本地改过但还没推送」这两种情况，而它们的处理方式完全不同。
public struct StampedPayload: Codable, Equatable, Sendable {
    /// 内容最后一次修改的时间，由修改方写入。
    public var updatedAt: Date
    /// 生成这份内容的设备，仅用于把「自己的回声」和真实远端变更区分开。
    public var deviceID: String
    /// 课表备份的 JSON 字节。
    public var payload: Data

    public init(updatedAt: Date, deviceID: String, payload: Data) {
        self.updatedAt = updatedAt
        self.deviceID = deviceID
        self.payload = payload
    }
}

/// 一次同步应当执行的动作。
public enum SyncDecision: Equatable, Sendable {
    /// 两边都没有内容，不需要做事。
    case idle
    /// 云端没有内容，或本地更新：应当把本地推上去。
    case pushLocal
    /// 本地没有内容，或云端更新且本地未改动：可以直接采用云端。
    case applyRemote
    /// 两边都改过且内容不同：必须由用户选择，不能静默覆盖。
    case conflict
}

public enum CloudSyncPlan {
    /// NSUbiquitousKeyValueStore 对单个值有大小限制，超限写入会被拒绝，
    /// 因此在写入前判断而不是等系统报错。
    public static let maximumPayloadBytes = 900_000

    /// 决定同步动作。
    ///
    /// - Parameters:
    ///   - local: 本地当前内容；`nil` 表示本地没有课表。
    ///   - remote: 云端内容；`nil` 表示云端为空。
    ///   - lastSynced: 上一次成功同步时的内容摘要，用于判断本地是否被改动过。
    /// - Returns: 应当执行的动作。
    public static func decide(local: StampedPayload?, remote: StampedPayload?,
                              lastSyncedPayload: Data?) -> SyncDecision {
        switch (local, remote) {
        case (nil, nil):
            return .idle

        case (let local?, nil):
            // 云端空、本地有内容：推上去。
            return .pushLocal

        case (nil, _):
            // 本地空：采用云端，即使它看起来更旧。
            return .applyRemote

        case (let local?, let remote?):
            if local.payload == remote.payload {
                // 内容一致，只可能时间戳不同，不需要传输。
                return .idle
            }
            if remote.deviceID == local.deviceID {
                // 同一台设备写的内容却不一样，说明本地有更新的改动需要覆盖云端。
                return remote.updatedAt < local.updatedAt ? .pushLocal : .applyRemote
            }
            // 本地自上次同步以来没有被改动过，可以安全地接受云端内容。
            if let lastSyncedPayload, lastSyncedPayload == local.payload {
                return .applyRemote
            }
            // 本地改过、云端也改过：交给用户决定。
            return .conflict
        }
    }

    /// 写入前的体积检查。超过上限时明确报错，不截断也不丢字段。
    public static func validateSize(_ stamped: StampedPayload) throws {
        guard stamped.payload.count <= maximumPayloadBytes else {
            throw CloudSyncError.payloadTooLarge(stamped.payload.count, maximumPayloadBytes)
        }
    }

    /// 把字节格式化成便于展示的大小。
    public static func sizeDescription(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

public enum CloudSyncError: LocalizedError, Equatable, Sendable {
    case unavailable
    case payloadTooLarge(Int, Int)
    case decodeFailed
    case writeRejected

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "未登录 iCloud，或系统未提供 iCloud 存储。请在系统设置中登录 Apple 账户后重试。"
        case .payloadTooLarge(let actual, let limit):
            "课表数据为 \(CloudSyncPlan.sizeDescription(actual))，超过 iCloud 键值存储的 \(CloudSyncPlan.sizeDescription(limit)) 上限。请减少课程后重试，或继续使用手动导出备份。"
        case .decodeFailed:
            "iCloud 中的课表数据无法解析，可能是更高版本的 App 写入的。"
        case .writeRejected:
            "iCloud 拒绝写入，可能是空间不足或暂时不可用。"
        }
    }
}
