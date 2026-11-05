import SwiftUI
@preconcurrency import ActivityKit

@main
struct CampusScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            CampusWindowContent()
        }
        // iPad 允许任意尺寸窗口，才能在分屏与台前调度里按需调整。
        .windowResizability(.contentMinSize)
        .backgroundTask(.appRefresh(AcademicRefreshService.taskID)) {
            await CourseLiveActivities.shared.cleanUpAfterBackgroundWake()
            await AcademicRefreshService.shared.check()
        }
    }
}

private struct CampusWindowContent: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        Group {
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["CAMPUS_LIVE_PREVIEW"] != nil {
                CourseLiveGallery()
            } else if ProcessInfo.processInfo.environment["CAMPUS_CHARACTER_PREVIEW"] != nil {
                CampusCharacterGallery()
            } else if ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] != nil {
                WidgetGalleryView()
            } else {
                RootView(appearance: $appearance)
            }
            #else
            RootView(appearance: $appearance)
            #endif
        }
        .background {
            AppAppearanceHost(appearance: appearance).frame(width: 0, height: 0)
        }
    }
}

/// 组件深链的载荷。`sheet(item:)` 需要 Identifiable，而目标本身只有可选的 id。
struct MilestoneLinkPayload: Identifiable {
    var id: String { milestoneID ?? "all" }
    var milestoneID: String?
}

/// 主界面。iPad 上用侧边栏承载三个分区，iPhone 保持标签栏。
///
/// 两套布局共享同一份状态与子视图，因此切换设备不会改变行为。
struct RootView: View {
    @Binding var appearance: AppAppearance
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var linkedCourse: DemoCourse?
    @State private var linkedOccurrenceID: String?
    @State private var courseNavigationRevision = 0
    @State private var linkUnavailable = false
    /// 从组件点进来时要打开的纪念事件。nil 表示没有待处理的目标。
    @State private var milestoneLink: MilestoneLinkPayload?
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

    #if targetEnvironment(simulator)
    @State private var store = PreviewStore(testingInMemory: ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] == "data-reliability")
    @State private var selectedScreen = Screen(rawValue: ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] ?? "week") ?? .week
    #else
    @State private var store = PreviewStore()
    @State private var selectedScreen: Screen = .week
    #endif

    var body: some View {
        Group {
            if let linkedCourse {
                CourseNowView(course: linkedCourse, occurrenceID: linkedOccurrenceID, onClose: closeLinkedCourse)
            } else if linkUnavailable {
                NavigationStack {
                    ContentUnavailableView {
                        Label("课程安排已更新", systemImage: "calendar.badge.clock")
                    } description: {
                        Text("这条组件记录已不在当前课表中，请查看更新后的安排。")
                    } actions: {
                        Button("查看课表", action: closeLinkedCourse)
                    }
                    .navigationTitle("本次课程").navigationBarTitleDisplayMode(.inline)
                }
            } else if horizontalSizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .tint(store.appearance.theme == .blueStickers ? CampusStickerMark.accent : DesignSystem.accent)
        .safeAreaInset(edge: .top) {
            if store.storageReadOnly {
                Button { closeLinkedCourse(); selectedScreen = .settings } label: {
                    Label("课表读取失败，原数据已保护。前往设置恢复", systemImage: "exclamationmark.shield")
                        .font(.footnote).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                }
                .foregroundStyle(.primary).background(DesignSystem.surface)
            }
        }
        // A dedicated root screen avoids competing with a previously presented editor sheet.
        .id(courseNavigationRevision)
        .onOpenURL { url in
            guard url.scheme == "campusschedule" else { return }
            linkedCourse = nil; linkedOccurrenceID = nil; linkUnavailable = false
            // 纪念事件走独立入口：它不属于任何学期，也不在课表页。
            if let target = MilestoneDeepLink.target(url) {
                milestoneLink = MilestoneLinkPayload(milestoneID: target.milestoneID)
                courseNavigationRevision += 1
                return
            }
            milestoneLink = nil
            if let target = CourseDeepLink.target(url) {
                selectedScreen = .week
                linkedCourse = store.resolveCourseLink(target)
                linkUnavailable = linkedCourse == nil
                let occurrence = CourseDeepLink.occurrence(for: target, in: store.occurrences, now: store.now)
                linkedOccurrenceID = target.occurrenceID ?? occurrence?.id
                if let occurrence {
                    store.selectedWeek = min(store.totalWeeks, max(1, ScheduleRules.week(on: occurrence.start, semesterStart: store.semesterStart)))
                }
            } else { selectedScreen = .today }
            courseNavigationRevision += 1
        }
        .sheet(item: $milestoneLink) { target in
            NavigationStack {
                Group {
                    if let id = target.milestoneID, store.milestones.contains(where: { $0.id == id }) {
                        MilestoneDetailView(id: id)
                    } else {
                        MilestoneListView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完成") { milestoneLink = nil }
                    }
                }
            }
            .environment(store)
        }
        .onChange(of: phase) { _, value in
            if value == .active && !(ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] ?? "").hasPrefix("live") {
                store.clockDate = Date(); store.synchronize()
            }
        }
        .task { await runSmokeChecksIfRequested() }
        .task(id: phase) {
            guard phase == .active, !store.isPreview else { return }
            await AcademicRefreshService.shared.check()
        }
        .environment(store)
        .environment(\.campusTheme, store.appearance.theme)
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
        .environment(\.dynamicTypeSize,
            ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_ACCESSIBILITY"] == "1" ? .accessibility3 : systemTypeSize)
        .environment(\.campusSuppressMotion,
            store.appearance.effects == .staticOnly || ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_REDUCE_MOTION"] == "1")
    }

    private func closeLinkedCourse() {
        linkedCourse = nil; linkedOccurrenceID = nil; linkUnavailable = false
        selectedScreen = .week
    }

    /// iPad：侧边栏常驻，内容区随选择切换。
    private var splitLayout: some View {
        let accent = store.appearance.theme == .blueStickers ? CampusStickerMark.accent : DesignSystem.accent
        return NavigationSplitView {
            List(Screen.allCases) { screen in
                Button {
                    selectedScreen = screen
                } label: {
                    Label(screen.title, systemImage: screen.symbol)
                }
                .buttonStyle(.plain)
                .listRowBackground(screen == selectedScreen ? accent.opacity(0.12) : Color.clear)
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
                    screenView(screen)
                }
            }
        }
        .tint(store.appearance.theme == .blueStickers ? CampusStickerMark.accent : DesignSystem.accent)
    }

    @ViewBuilder private func screenView(_ screen: Screen) -> some View {
        switch screen {
        case .week: WeekScheduleView()
        case .today: TodayView(permitsPreviewSheets: courseNavigationRevision == 0)
        case .settings: SettingsView(appearance: $appearance)
        }
    }

    /// 环境变量驱动的自动检查，仅在 CI 与截图流程中启用。
    private func runSmokeChecksIfRequested() async {
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] == "data-reliability" {
                try? DataReliabilitySmoke.run().write(to: URL.documentsDirectory.appendingPathComponent("data-reliability-smoke.txt"),
                                                     atomically: true, encoding: .utf8)
                return
            }
            if ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] == "clean" {
                let result = store.courses.isEmpty && store.exams.isEmpty && store.milestones.isEmpty
                    && !store.storageReadOnly ? "PASS: fresh launch has no sample records" : "FAIL: expected an empty personal store"
                try? result.write(to: URL.documentsDirectory.appendingPathComponent("clean-launch-smoke.txt"), atomically: true, encoding: .utf8)
                return
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
            #endif
            store.synchronize()
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"] != nil {
                try? await Task.sleep(for: .milliseconds(800))
                let result: String
                if SystemSnapshot.url == nil { result = "UNAVAILABLE: App Group container is not available in this environment" }
                else { result = SystemSnapshot.read().contains(where: { $0.courseID == "persistence-test" }) ? "PASS" : "FAIL" }
                try? result.write(to: URL.documentsDirectory.appendingPathComponent("snapshot-smoke.txt"), atomically: true, encoding: .utf8)
            }
            #endif
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30)); store.clockDate = Date()
                    if !store.isPreview {
                        await CourseLiveActivities.shared.reconcile(items: store.occurrences, enabled: store.liveEnabled,
                            lead: store.reminderMinutes, termID: store.activeTermID, appearance: store.appearance)
                    }
                }
                catch { break }
            }
    }
}

#Preview("浅色") {
    RootView(appearance: .constant(.light)).preferredColorScheme(.light)
}

#Preview("深色") {
    RootView(appearance: .constant(.dark)).preferredColorScheme(.dark)
}
