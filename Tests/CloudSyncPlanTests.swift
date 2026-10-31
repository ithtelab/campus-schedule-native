import Foundation
import Testing
@testable import ScheduleCore

struct CloudSyncPlanTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func stamped(_ text: String, at offset: TimeInterval = 0, device: String = "device-a") -> StampedPayload {
        StampedPayload(updatedAt: now.addingTimeInterval(offset), deviceID: device,
                       payload: Data(text.utf8))
    }

    // MARK: 空状态

    @Test func bothEmptyIsIdle() {
        #expect(CloudSyncPlan.decide(local: nil, remote: nil, lastSyncedPayload: nil) == .idle)
    }

    @Test func localOnlyPushes() {
        #expect(CloudSyncPlan.decide(local: stamped("a"), remote: nil, lastSyncedPayload: nil) == .pushLocal)
    }

    @Test func remoteOnlyApplies() {
        #expect(CloudSyncPlan.decide(local: nil, remote: stamped("a"), lastSyncedPayload: nil) == .applyRemote)
        // 即使云端内容很旧，本地空表也该接受它。
        #expect(CloudSyncPlan.decide(local: nil, remote: stamped("a", at: -86400), lastSyncedPayload: nil) == .applyRemote)
    }

    // MARK: 内容一致

    @Test func identicalContentNeedsNoTransfer() {
        let local = stamped("same", at: 100, device: "device-a")
        let remote = stamped("same", at: 200, device: "device-b")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: nil) == .idle)
    }

    // MARK: 同一设备

    @Test func sameDeviceNewerLocalPushes() {
        let local = stamped("new", at: 200, device: "device-a")
        let remote = stamped("old", at: 100, device: "device-a")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: nil) == .pushLocal)
    }

    @Test func sameDeviceNewerRemoteApplies() {
        let local = stamped("old", at: 100, device: "device-a")
        let remote = stamped("new", at: 200, device: "device-a")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: nil) == .applyRemote)
    }

    // MARK: 跨设备

    @Test func untouchedLocalAcceptsRemote() {
        let synced = Data("base".utf8)
        let local = StampedPayload(updatedAt: now, deviceID: "device-a", payload: synced)
        let remote = stamped("remote-edit", at: 50, device: "device-b")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: synced) == .applyRemote)
    }

    @Test func locallyEditedAndRemotelyEditedConflicts() {
        let synced = Data("base".utf8)
        let local = StampedPayload(updatedAt: now.addingTimeInterval(10), deviceID: "device-a",
                                   payload: Data("local-edit".utf8))
        let remote = stamped("remote-edit", at: 50, device: "device-b")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: synced) == .conflict)
    }

    @Test func localEditWithoutSyncHistoryConflicts() {
        // 从未同步过（lastSynced 为 nil）但两边都有不同内容，不能替用户做决定。
        let local = stamped("local", at: 10)
        let remote = stamped("remote", at: 50, device: "device-b")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: nil) == .conflict)
    }

    @Test func conflictIsNotResolvedByTimestamps() {
        // 即使本地时间戳更新，只要两边都改过就仍然是冲突，避免静默丢失远端改动。
        let synced = Data("base".utf8)
        let local = StampedPayload(updatedAt: now.addingTimeInterval(999), deviceID: "device-a",
                                   payload: Data("local".utf8))
        let remote = stamped("remote", at: 1, device: "device-b")
        #expect(CloudSyncPlan.decide(local: local, remote: remote, lastSyncedPayload: synced) == .conflict)
    }

    // MARK: 体积

    @Test func acceptsPayloadAtLimit() throws {
        let ok = StampedPayload(updatedAt: now, deviceID: "d",
                                payload: Data(count: CloudSyncPlan.maximumPayloadBytes))
        try CloudSyncPlan.validateSize(ok)
    }

    @Test func rejectsPayloadAboveLimit() {
        let tooBig = StampedPayload(updatedAt: now, deviceID: "d",
                                    payload: Data(count: CloudSyncPlan.maximumPayloadBytes + 1))
        #expect(throws: CloudSyncError.payloadTooLarge(CloudSyncPlan.maximumPayloadBytes + 1,
                                                       CloudSyncPlan.maximumPayloadBytes)) {
            try CloudSyncPlan.validateSize(tooBig)
        }
    }

    @Test func errorMessageMentionsSizes() {
        let message = CloudSyncError.payloadTooLarge(2_000_000, CloudSyncPlan.maximumPayloadBytes)
            .errorDescription ?? ""
        #expect(message.contains("MB") || message.contains("KB"))
    }

    // MARK: 编解码

    @Test func stampedPayloadRoundTrips() throws {
        let original = stamped("课表内容", at: 42)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(StampedPayload.self, from: encoder.encode(original))
        #expect(restored == original)
    }
}
