import Foundation

/// 通过 iCloud 键值存储在多台设备之间同步课表。
///
/// 同步策略是「明确选择才启用」，与产品约定一致：未开启时完全不碰 iCloud。
@MainActor
final class CloudSync {
    static let shared = CloudSync()

    enum Event {
        case remote(StampedPayload)
        case accountChanged
        case cloudCopyRemoved
        case quotaExceeded
    }

    private enum Key {
        static let stamped = "schedule.stamped"
        static let lastSynced = "schedule.lastSyncedPayload"
        static let device = "schedule.deviceID"
        static let accountIdentity = "schedule.cloudAccountIdentity"
        static let acceptedGeneration = "schedule.acceptedCloudGeneration"
        static let deletionGeneration = "schedule.cloudDeletionGeneration"
    }

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var observer: NSObjectProtocol?
    private var onRemoteChange: ((Event) -> Void)?

    /// 检查这个 App 的键值存储可用性，不以 iCloud 云盘的文件身份判断。
    func requestSync() throws {
        guard !accountChanged else { throw CloudSyncError.accountChanged }
        guard store.synchronize() else { throw CloudSyncError.unavailable }
        guard canUseRemote(remoteStamp()) else {
            throw CloudSyncError.cloudCopyRemoved
        }
        if defaults.data(forKey: Key.accountIdentity) == nil { try rememberIdentity() }
    }

    /// Called only when the person actively enables syncing. Existing local data is retained.
    func authorizeConnection() throws {
        guard store.synchronize() else { throw CloudSyncError.unavailable }
        let generation = deletionGeneration ?? remoteStamp()?.deletionGeneration
        if accountChanged || generation != acceptedGeneration { resetSyncState() }
        try rememberIdentity()
        defaults.set(generation, forKey: Key.acceptedGeneration)
    }

    private var acceptedGeneration: String? { defaults.string(forKey: Key.acceptedGeneration) }
    private var deletionGeneration: String? { store.string(forKey: Key.deletionGeneration) }

    private func canUseRemote(_ stamped: StampedPayload?) -> Bool {
        CloudSyncPlan.canUseRemote(stamped, acceptedGeneration: acceptedGeneration, deletionGeneration: deletionGeneration)
    }

    private func isCurrent(_ stamped: StampedPayload) -> Bool {
        guard let deletionGeneration else { return true }
        return stamped.deletionGeneration == deletionGeneration
    }

    private var accountChanged: Bool {
        guard let saved = defaults.data(forKey: Key.accountIdentity) else { return false }
        guard let previous = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(saved)) as? NSObject,
              let current = FileManager.default.ubiquityIdentityToken else { return true }
        return !previous.isEqual(current)
    }

    private func rememberIdentity() throws {
        let token = FileManager.default.ubiquityIdentityToken
        let data = try token.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: false) }
        defaults.set(data, forKey: Key.accountIdentity)
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
    private func remoteStamp() -> StampedPayload? {
        guard let data = store.data(forKey: Key.stamped) else { return nil }
        return try? JSONDecoder().decode(StampedPayload.self, from: data)
    }

    func remote() -> StampedPayload? {
        guard let stamped = remoteStamp(), isCurrent(stamped), !stamped.isDeletion else { return nil }
        return stamped
    }

    /// 云端存在但无法解码时，明确报告而不是静默覆盖。
    var remoteIsCorrupt: Bool {
        guard let data = store.data(forKey: Key.stamped) else { return false }
        guard let stamped = try? JSONDecoder().decode(StampedPayload.self, from: data) else { return true }
        return isCurrent(stamped) && !stamped.isDeletion && (try? ScheduleArchive.decoded(from: stamped.payload)) == nil
    }

    // MARK: 推送

    /// 把本地内容写入 iCloud。成功后才记录为「已同步」。
    func push(_ payload: Data, at date: Date = Date()) throws {
        try requestSync()
        guard !remoteIsCorrupt else { throw CloudSyncError.decodeFailed }
        let payload = CloudSyncPlan.canonicalPayload(payload)
        if let remote = remote(), CloudSyncPlan.canonicalPayload(remote.payload) == payload {
            lastSyncedPayload = payload
            return
        }
        let stamped = StampedPayload(updatedAt: date, deviceID: deviceID, payload: payload,
                                     deletionGeneration: acceptedGeneration)
        let encoded = try CloudSyncPlan.storageData(stamped)
        store.set(encoded, forKey: Key.stamped)
        guard store.synchronize() else { throw CloudSyncError.writeRejected }
        lastSyncedPayload = payload
    }

    /// 采用远端内容后调用，把云端内容记为已同步，避免下次又判定成冲突。
    func markSynced(_ payload: Data) {
        lastSyncedPayload = CloudSyncPlan.canonicalPayload(payload)
    }

    func removeCloudCopy() throws {
        try requestSync()
        let generation = UUID().uuidString
        let marker = StampedPayload(updatedAt: Date(), deviceID: deviceID, payload: Data(),
                                    deletionGeneration: generation)
        let encoded = try CloudSyncPlan.storageData(marker)
        // Separate key prevents an offline device's queued archive write from erasing the deletion.
        store.set(generation, forKey: Key.deletionGeneration)
        store.set(encoded, forKey: Key.stamped)
        guard store.synchronize() else { throw CloudSyncError.writeRejected }
    }

    // MARK: 变更监听

    /// 开始监听云端变化。回调在主线程执行，只推送与本地不同的内容。
    func startObserving(_ handler: @escaping (Event) -> Void) {
        onRemoteChange = handler
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let reason = note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            if reason == NSUbiquitousKeyValueStoreAccountChange || self.accountChanged {
                self.onRemoteChange?(.accountChanged)
                return
            }
            if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
                self.onRemoteChange?(.quotaExceeded)
                return
            }
            let stamped = self.remoteStamp()
            if !self.canUseRemote(stamped) {
                self.onRemoteChange?(.cloudCopyRemoved)
            } else if let stamped, self.isCurrent(stamped), !stamped.isDeletion, stamped.deviceID != self.deviceID {
                self.onRemoteChange?(.remote(stamped))
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
