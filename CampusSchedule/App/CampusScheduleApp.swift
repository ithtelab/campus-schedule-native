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
        .environment(store)
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
