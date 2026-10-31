import Foundation

/// 通过 iCloud 键值存储在多台设备之间同步课表。
///
/// 使用 `NSUbiquitousKeyValueStore` 而不是 CloudKit：后者需要在开发者网站为
/// App ID 勾选 CloudKit 服务，而这个账号目前只有 iCloud 文档存储能力；
/// 键值存储已经可用，且课表体量远小于它的限制。
///
/// 同步策略是「明确选择才启用」，与产品约定一致：未开启时完全不碰 iCloud。
@MainActor
final class CloudSync {
    static let shared = CloudSync()

    private enum Key {
        static let stamped = "schedule.stamped"
        static let lastSynced = "schedule.lastSyncedPayload"
        static let device = "schedule.deviceID"
    }

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var observer: NSObjectProtocol?
    private var onRemoteChange: ((StampedPayload) -> Void)?

    /// 系统是否提供了 iCloud 账户。未登录时为 false。
    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// 本机标识，用来区分自己写入的回声和真实远端变更。
    private(set) lazy var deviceID: String = {
        if let existing = defaults.string(forKey: Key.device) { return existing }
        let created = UUID().uuidString
        defaults.set(created, forKey: Key.device)
        return created
    }()

    /// 上一次成功同步的内容，用于判断本地是否被改动。
    private var lastSyncedPayload: Data? {
        get { defaults.data(forKey: Key.lastSynced) }
        set { defaults.set(newValue, forKey: Key.lastSynced) }
    }

    /// 供界面层做冲突判断时读取，避免把内部存储细节暴露出去。
    var lastSyncedPayloadForComparison: Data? { lastSyncedPayload }

    // MARK: 远端读取

    /// 读取云端内容。数据损坏时返回 nil 并保留错误，避免把坏数据当成「云端为空」。
    func remote() -> StampedPayload? {
        guard let data = store.data(forKey: Key.stamped) else { return nil }
        return try? JSONDecoder().decode(StampedPayload.self, from: data)
    }

    /// 云端存在但无法解码时，明确报告而不是静默覆盖。
    var remoteIsCorrupt: Bool {
        guard let data = store.data(forKey: Key.stamped) else { return false }
        return (try? JSONDecoder().decode(StampedPayload.self, from: data)) == nil
    }

    // MARK: 推送

    /// 把本地内容写入 iCloud。成功后才记录为「已同步」。
    func push(_ payload: Data, at date: Date = Date()) throws {
        guard isAvailable else { throw CloudSyncError.unavailable }
        let stamped = StampedPayload(updatedAt: date, deviceID: deviceID, payload: payload)
        try CloudSyncPlan.validateSize(stamped)
        let encoded = try JSONEncoder().encode(stamped)
        store.set(encoded, forKey: Key.stamped)
        guard store.synchronize() else { throw CloudSyncError.writeRejected }
        lastSyncedPayload = payload
    }

    /// 采用远端内容后调用，把云端内容记为已同步，避免下次又判定成冲突。
    func markSynced(_ payload: Data) {
        lastSyncedPayload = payload
    }

    // MARK: 变更监听

    /// 开始监听云端变化。回调在主线程执行，只推送与本地不同的内容。
    func startObserving(_ handler: @escaping (StampedPayload) -> Void) {
        onRemoteChange = handler
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            // 配额冲突时系统会给出当前值，需要重新比较而不是直接接受。
            if let payload = self.remote(), payload.deviceID != self.deviceID {
                self.onRemoteChange?(payload)
            } else if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
                // 配额不足：保留本地数据，向界面报告。
                self.onRemoteChange?(StampedPayload(updatedAt: Date(), deviceID: "", payload: Data()))
            }
        }
    }

    func stopObserving() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        onRemoteChange = nil
    }

    /// 决定这次启动该做什么。
    func decision(local: Data?) -> SyncDecision {
        let localStamped = local.map {
            StampedPayload(updatedAt: Date(), deviceID: deviceID, payload: $0)
        }
        return CloudSyncPlan.decide(local: localStamped, remote: remote(), lastSyncedPayload: lastSyncedPayload)
    }

    /// 清除本地记录的同步状态，仅在用户明确关闭同步时调用。
    func resetSyncState() {
        defaults.removeObject(forKey: Key.lastSynced)
    }
}
