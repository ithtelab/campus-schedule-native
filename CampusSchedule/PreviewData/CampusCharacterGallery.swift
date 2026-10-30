import SwiftUI

/// Cloud-only QA screen. These are the same players and controls used in the app.
struct CampusCharacterGallery: View {
    private enum ValidationError: Error { case frameMismatch, reducedMotionMismatch, overlappingPlayback, cancellationFailure, scheduleMismatch }
    @State private var boy = CampusCharacterPlayer(style: .boy)
    @State private var girl = CampusCharacterPlayer(style: .girl)
    @State private var caption = "点人物触发动作，长按选择"
    @State private var finished = false
    @State private var scheduleMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("原生动作验证页 · 演示素材").font(.caption).foregroundStyle(.secondary)
                    Text(caption).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    HStack(alignment: .bottom, spacing: 30) {
                        VStack(spacing: 10) {
                            CampusCharacter(player: boy, contextDriven: scheduleMode).frame(width: 130, height: 280)
                            Text("男生").font(.caption)
                        }
                        VStack(spacing: 10) {
                            CampusCharacter(player: girl, contextDriven: scheduleMode).frame(width: 130, height: 280)
                            Text("女生").font(.caption)
                        }
                    }
                    Text("\(boy.state.rawValue) · \(girl.state.rawValue)")
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    if !scheduleMode { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(CampusCharacterAction.allCases, id: \.self) { action in
                            Button(action.title) {
                                boy.request(action, reducedMotion: false)
                                girl.request(action, reducedMotion: false)
                            }
                            .buttonStyle(.bordered).disabled(boy.isPlaying || girl.isPlaying)
                        }
                    } }
                    Text(finished ? "动作状态检查完成" : "身体与书本逐帧变化，非整图晃动")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(DesignSystem.background)
            .navigationTitle("校园人物交互").navigationBarTitleDisplayMode(.inline)
            .tint(DesignSystem.accent)
            .task { await smoke() }
        }
    }

    @MainActor private func smoke() async {
        guard ProcessInfo.processInfo.environment["CAMPUS_CHARACTER_PREVIEW"] == "smoke" else { return }
        let output = URL.documentsDirectory.appendingPathComponent("campus-interaction-smoke.txt")
        var proofs: [String] = []
        guard CampusCharacterAssets.available else {
            try? "FAIL: animation atlas unavailable".write(to: output, atomically: true, encoding: .utf8)
            return
        }
        do {
            try await Task.sleep(for: .seconds(3))
            for action in [CampusCharacterAction.stand, .pickUpBook, .putDownBook, .walk, .sit, .pickUpBook, .putDownBook, .stretch, .prepareCourse] {
                caption = action.title
                let expectedBoy = CampusAnimationPlan.make(action, from: boy.state)
                let expectedGirl = CampusAnimationPlan.make(action, from: girl.state)
                async let boyResult = boy.play(action)
                async let girlResult = girl.play(action)
                let results = await (boyResult, girlResult)
                guard results.0 && results.1,
                      boy.state == expectedBoy.destination, girl.state == expectedGirl.destination,
                      boy.frame == boy.state.frame, girl.frame == girl.state.frame,
                      boy.playedFrames == expectedBoy.frames, girl.playedFrames == expectedGirl.frames else {
                    throw ValidationError.frameMismatch
                }
                proofs.append("PASS: \(action.rawValue) (boy and girl, frame sequence and final state)")
                try await Task.sleep(for: .milliseconds(250))
            }
            let reduced = CampusCharacterPlayer(style: .girl)
            let reducedResult = await reduced.play(.stand, reducedMotion: true)
            guard reducedResult, reduced.state == .standingEmpty, reduced.playedFrames.isEmpty else { throw ValidationError.reducedMotionMismatch }
            proofs.append("PASS: reduce motion changes stable pose without playback")
            let pending = Task { @MainActor in await boy.play(.walk) }
            try await Task.sleep(for: .milliseconds(40))
            let duplicate = await boy.play(.sit)
            guard !duplicate else { throw ValidationError.overlappingPlayback }
            boy.stop()
            let completed = await pending.value
            guard !completed, !boy.isPlaying, boy.frame == boy.state.frame else { throw ValidationError.cancellationFailure }
            proofs.append("PASS: repeated taps do not overlap; stop restores stable pose")
            scheduleMode = true
            let day = ScheduleRules.calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
            func date(_ time: String) -> Date { ScheduleRules.date(day: day, time: time)! }
            let items: [CourseOccurrence] = [
                .init(id: "a", courseID: "a", title: "高等数学", room: "A302", start: date("08:00"), end: date("09:35")),
                .init(id: "b", courseID: "b", title: "大学英语", room: "B205", start: date("10:00"), end: date("11:35"))
            ]
            for (time, title) in [("09:41", "课间 · 坐着休息"), ("09:50", "提前十分钟 · 换教室"), ("10:00", "上课 · 坐下看书"), ("11:35", "今天下课 · 收书放松")] {
                caption = "\(time) · \(title)"
                let context = CampusScheduleContext.make(items: items, now: date(time), leadMinutes: 10)
                boy.synchronize(context, animated: true); girl.synchronize(context, animated: true)
                try await waitForPlayers()
                guard boy.state == context.stableState, girl.state == context.stableState,
                      boy.context == context, girl.context == context else { throw ValidationError.scheduleMismatch }
                // A tap may respond but must return to the same timetable-owned pose.
                boy.respondToContext(reducedMotion: false); girl.respondToContext(reducedMotion: false)
                try await waitForPlayers()
                guard boy.state == context.stableState, girl.state == context.stableState,
                      boy.style == .boy, girl.style == .girl else { throw ValidationError.scheduleMismatch }
                proofs.append("PASS: schedule \(time) \(context.phase.rawValue); response preserves context and identity")
                try await Task.sleep(for: .milliseconds(400))
            }
            // A new timetable state has priority over an unfinished response.
            girl.respondToContext(reducedMotion: false)
            try await Task.sleep(for: .milliseconds(40))
            let active = CampusScheduleContext.make(items: items, now: date("10:30"), leadMinutes: 10)
            girl.synchronize(active, animated: false)
            try await Task.sleep(for: .milliseconds(250))
            guard !girl.isBusy, girl.state == .seatedReading, girl.context == active else { throw ValidationError.scheduleMismatch }
            proofs.append("PASS: timetable changes cancel stale actions; no late pose overwrite")
            girl.respondToContext(reducedMotion: true)
            guard !girl.isBusy, girl.state == .seatedReading else { throw ValidationError.reducedMotionMismatch }
            proofs.append("PASS: timetable response respects reduce motion")
            caption = "动作验证完成"; finished = true
            try proofs.joined(separator: "\n").write(to: output, atomically: true, encoding: .utf8)
        } catch {
            try? (proofs.joined(separator: "\n") + "\nFAIL: \(error)").write(to: output, atomically: true, encoding: .utf8)
        }
    }

    @MainActor private func waitForPlayers() async throws {
        for _ in 0..<300 {
            if !boy.isBusy && !girl.isBusy { return }
            try await Task.sleep(for: .milliseconds(40))
        }
        throw ValidationError.scheduleMismatch
    }
}
