import SwiftUI
@preconcurrency import ActivityKit

@main
struct CampusScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["CAMPUS_LIVE_PREVIEW"] != nil {
                CourseLiveGallery()
            } else if ProcessInfo.processInfo.environment["CAMPUS_CHARACTER_PREVIEW"] != nil {
                CampusCharacterGallery()
            } else if ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] != nil {
                WidgetGalleryView()
            } else {
                RootView()
            }
        }
        // iPad 允许任意尺寸窗口，才能在分屏与台前调度里按需调整。
        .windowResizability(.contentMinSize)
    }
}

/// 主界面。iPad 上用侧边栏承载三个分区，iPhone 保持标签栏。
///
/// 两套布局共享同一份状态与子视图，因此切换设备不会改变行为。
struct RootView: View {
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var linkedCourse: DemoCourse?
    enum Screen: String, CaseIterable, Identifiable {
        case today, week, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: "课表"
            case .today: "今日"
            case .settings: "设置"
            }
        }
        var symbol: String {
            switch self {
            case .week: "calendar"
            case .today: "sun.max"
            case .settings: "slider.horizontal.3"
            }
        }
    }

    @State private var store = PreviewStore()
    // 云端显式选择页面；本演示版正常启动突出课表，个人存储保持隔离。
    @State private var selectedScreen = Screen(
        rawValue: ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] ?? ProcessInfo.processInfo.environment["CAMPUS_DEMO_SCREEN"] ?? "week"
    ) ?? .week

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .tint(DesignSystem.accent)
        .onOpenURL { url in
            if url.host == "course", let id = url.pathComponents.last { linkedCourse = store.courses.first { $0.id == id } }
            else { selectedScreen = .today }
        }
        .sheet(item: $linkedCourse) { CourseDetailView(course: $0).environment(store) }
        .onChange(of: phase) { _, value in
            if value == .active && !(ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] ?? "").hasPrefix("live") {
                store.clockDate = Date(); store.synchronize()
            }
        }
        .task { await runSmokeChecksIfRequested() }
        .environment(store)
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
        .environment(\.dynamicTypeSize,
            ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_ACCESSIBILITY"] == "1" ? .accessibility3 : systemTypeSize)
        .environment(\.campusSuppressMotion,
            ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_REDUCE_MOTION"] == "1")
    }

    /// iPad：侧边栏常驻，内容区随选择切换。
    private var splitLayout: some View {
        NavigationSplitView {
            List(Screen.allCases) { screen in
                Button {
                    selectedScreen = screen
                } label: {
                    Label(screen.title, systemImage: screen.symbol)
                }
                .buttonStyle(.plain)
                .listRowBackground(screen == selectedScreen ? DesignSystem.accent.opacity(0.12) : Color.clear)
            }
            .navigationTitle("课间册")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            screenView(selectedScreen)
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// iPhone：原有标签栏。
    private var tabLayout: some View {
        TabView(selection: $selectedScreen) {
            ForEach(Screen.allCases) { screen in
                Tab(screen.title, systemImage: screen.symbol, value: screen) {
                    screenView(screen).tint(DesignSystem.toolbarTint)
                }
            }
        }
    }

    @ViewBuilder private func screenView(_ screen: Screen) -> some View {
        switch screen {
        case .week: WeekScheduleView()
        case .today: TodayView()
        case .settings: SettingsView()
        }
    }

    /// 环境变量驱动的自动检查，仅在 CI 与截图流程中启用。
    private func runSmokeChecksIfRequested() async {
            if ProcessInfo.processInfo.environment["CAMPUS_DEMO_SMOKE"] == "1" {
                let passed = store.isDemoEdition && !store.isPreview && !store.courses.isEmpty && store.currentWeek == 8
                try? (passed ? "PASS: normal demo edition opens populated current-term data separately from personal storage" : "FAIL: demo edition routing")
                    .write(to: URL.documentsDirectory.appendingPathComponent("demo-edition-smoke.txt"), atomically: true, encoding: .utf8)
            }
            if store.isPreview, ProcessInfo.processInfo.environment["CAMPUS_TOSS_SMOKE"] == "1", let first = store.todayCourses.first {
                let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
                let before = try? encoder.encode(store.courses)
                let occurrences = store.occurrences
                let reaction = CourseTossReaction()
                let accepted = reaction.accept([CourseTossReaction.payload(first)], courses: store.todayCourses)
                let rejected = !reaction.accept(["foreign-payload"], courses: store.todayCourses)
                let after = try? encoder.encode(store.courses)
                let passed = accepted && rejected && reaction.count == 1 && reaction.title == first.title && before != nil && before == after && occurrences == store.occurrences
                try? (passed ? "PASS: toss reaction accepts known course, rejects foreign payload, preserves complete course and reminder instances" : "FAIL: toss mutated course data")
                    .write(to: URL.documentsDirectory.appendingPathComponent("course-toss-smoke.txt"), atomically: true, encoding: .utf8)
            }
            if store.isPreview {
                let result = CampusArtAssets.available && CampusCharacterAssets.available ? "PASS: light/dark figures, two 16-frame action atlases and bundled handwriting font loaded" : "FAIL: campus art, animation atlas or handwriting font missing"
                try? result.write(to: URL.documentsDirectory.appendingPathComponent("campus-assets-smoke.txt"), atomically: true, encoding: .utf8)
            }
            if let smoke = ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"], smoke.hasPrefix("live") {
                let result: String
                if smoke == "live-audit" {
                    let remaining = Activity<CourseActivityAttributes>.activities
                    result = remaining.isEmpty ? "REMOVED" : "STILL_PRESENT_AFTER_END"
                    for activity in remaining { await CourseLiveActivities.shared.finish(activity, suppress: false) }
                } else if smoke == "live-intent" {
                    do {
                        let item = CourseOccurrence(id: "cloud-intent-smoke", courseID: "cloud-intent", title: "结束动作验证", room: "A302", start: Date().addingTimeInterval(5), end: Date().addingTimeInterval(20))
                        try CourseLiveActivities.shared.start(item)
                        _ = try await EndCourseIntent(id: item.id).perform()
                        let stillActive = Activity<CourseActivityAttributes>.activities.contains { $0.attributes.occurrenceID == item.id && $0.activityState != .ended && $0.activityState != .dismissed }
                        let defaults = UserDefaults(suiteName: SystemSnapshot.group) ?? .standard
                        let suppressed = (defaults.stringArray(forKey: "endedOccurrences") ?? []).contains(item.id)
                        result = !stillActive && suppressed ? "PASS: shared LiveActivityIntent ends matching activity and suppresses restart" : "FAIL: end intent did not finish or suppress"
                    } catch { result = "UNAVAILABLE: \(error.localizedDescription)" }
                } else {
                    do {
                        let item = CourseOccurrence(id: "cloud-live-smoke", courseID: "cloud-test", title: "云端课程验证", room: "A302",
                            start: Date().addingTimeInterval(5), end: Date().addingTimeInterval(20), nextTitle: "下一门课程", nextRoom: "B205")
                        try CourseLiveActivities.shared.start(item)
                        result = Activity<CourseActivityAttributes>.activities.isEmpty ? "UNAVAILABLE: system did not start an activity" : "PASS: Live Activity created"
                    } catch { result = "UNAVAILABLE: \(error.localizedDescription)" }
                }
                try? result.write(to: URL.documentsDirectory.appendingPathComponent("activity-smoke.txt"), atomically: true, encoding: .utf8)
                return
            }
            if let smoke = ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] {
                let file = URL.documentsDirectory.appendingPathComponent("persistence-smoke.txt")
                if smoke == "seed" && store.courses.isEmpty {
                    store.courses.append(DemoCourse(id: "persistence-test", title: "本地保存测试", room: "A302", teacher: "", weekday: 0,
                        startPeriod: 1, endPeriod: 2, startTime: "08:00", endTime: "09:35", color: .blue))
                    store.courses[0].remindersEnabled = false
                    store.refreshCourseTimes()
                }
                let result = store.errorMessage == nil && store.courses.contains(where: { $0.id == "persistence-test" && !$0.remindersEnabled }) ? "PASS" : "FAIL"
                try? result.write(to: file, atomically: true, encoding: .utf8)
            }
            store.synchronize()
            if ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] != nil {
                try? await Task.sleep(for: .milliseconds(800))
                let result: String
                if SystemSnapshot.url == nil { result = "UNAVAILABLE: App Group container is not available in this environment" }
                else { result = SystemSnapshot.read().contains(where: { $0.courseID == "persistence-test" }) ? "PASS" : "FAIL" }
                try? result.write(to: URL.documentsDirectory.appendingPathComponent("snapshot-smoke.txt"), atomically: true, encoding: .utf8)
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30)); store.clockDate = Date()
                    if !store.isPreview { await CourseLiveActivities.shared.reconcile(items: store.occurrences, enabled: store.liveEnabled, lead: store.reminderMinutes) }
                }
                catch { break }
            }
    }
}

#Preview("浅色") {
    RootView().preferredColorScheme(.light)
}

#Preview("深色") {
    RootView().preferredColorScheme(.dark)
}
