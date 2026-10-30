import SwiftUI

@main
struct CampusScheduleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
        .onChange(of: phase) { _, value in if value == .active { store.clockDate = Date(); store.synchronize() } }
        .task {
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
