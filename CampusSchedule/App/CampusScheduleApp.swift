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
    // 云端显式选择页面；正常启动突出课表，个人数据仍从本机读取。
    @State private var selectedScreen = Screen(
        rawValue: ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_TAB"] ?? "week"
    ) ?? .week

    var body: some View {
        TabView(selection: $selectedScreen) {
            Tab("课表", systemImage: "calendar", value: Screen.week) {
                WeekScheduleView()
                    .tint(DesignSystem.toolbarTint)
            }
            Tab("今日", systemImage: "sun.max", value: Screen.today) {
                TodayView().tint(DesignSystem.toolbarTint)
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
            if store.isPreview, ProcessInfo.processInfo.environment["CAMPUS_TOSS_SMOKE"] == "1", let first = store.todayCourses.first {
                let before = try? JSONEncoder().encode(store.courses)
                let occurrences = store.occurrences
                let reaction = CourseTossReaction()
                let accepted = reaction.accept([CourseTossReaction.payload(first)], courses: store.todayCourses)
                let rejected = !reaction.accept(["foreign-payload"], courses: store.todayCourses)
                let after = try? JSONEncoder().encode(store.courses)
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
        .environment(\.campusSuppressMotion,
            ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_REDUCE_MOTION"] == "1")
    }
}

#Preview("浅色") {
    RootView().preferredColorScheme(.light)
}

#Preview("深色") {
    RootView().preferredColorScheme(.dark)
}
