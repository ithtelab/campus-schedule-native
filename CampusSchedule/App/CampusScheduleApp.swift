import SwiftUI
@preconcurrency import ActivityKit

@main
struct CampusScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.environment["CAMPUS_WIDGET_PREVIEW"] != nil {
                WidgetGalleryView()
            } else {
                RootView()
            }
        }
    }
}

struct RootView: View {
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @Environment(\.scenePhase) private var phase
    @State private var linkedCourse: DemoCourse?
    private enum Screen: String {
        case today, week, settings
    }

    @State private var store = PreviewStore()
    // 云端截图通过启动环境选择页面；普通启动始终显示今日。
    @State private var selectedScreen = Screen(
        rawValue: ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] ?? "today"
    ) ?? .today

    var body: some View {
        TabView(selection: $selectedScreen) {
            Tab("今日", systemImage: "sun.max", value: Screen.today) {
                TodayView()
                    .tint(DesignSystem.toolbarTint)
            }
            Tab("课表", systemImage: "calendar", value: Screen.week) {
                WeekScheduleView()
                    .tint(DesignSystem.toolbarTint)
            }
            Tab("设置", systemImage: "slider.horizontal.3", value: Screen.settings) {
                SettingsView()
                    .tint(DesignSystem.toolbarTint)
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
        .task {
            if let smoke = ProcessInfo.processInfo.environment["CAMPUS_SMOKE_TEST"], smoke.hasPrefix("live") {
                let result: String
                if smoke == "live-audit" {
                    let remaining = Activity<CourseActivityAttributes>.activities
                    result = remaining.isEmpty ? "REMOVED" : "STILL_PRESENT_AFTER_END"
                    for activity in remaining { await CourseLiveActivities.shared.finish(activity, suppress: false) }
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
        .environment(store)
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
        .environment(\.dynamicTypeSize,
            ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_ACCESSIBILITY"] == "1" ? .accessibility3 : systemTypeSize)
    }
}

#Preview("浅色") {
    RootView().preferredColorScheme(.light)
}

#Preview("深色") {
    RootView().preferredColorScheme(.dark)
}
