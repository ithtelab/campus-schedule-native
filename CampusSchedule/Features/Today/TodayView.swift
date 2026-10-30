import SwiftUI

struct TodayView: View {
    @Environment(PreviewStore.self) private var store
    @State private var selectedCourse: DemoCourse?
    @State private var showingEditor = false
    private let previewTime = "09:41"
    private var nextCourse: DemoCourse? { store.todayCourses.first { $0.endTime > previewTime } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.date(week: 8), format: .dateTime.month(.wide).day().weekday(.wide))
                                .font(.title2.weight(.bold))
                            Text("\(store.semesterName) · 第 8 周")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("演示 \(previewTime)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(DesignSystem.surface, in: Capsule()).foregroundStyle(.secondary)
                    }
                    if let nextCourse { focusCard(nextCourse) }
                    else if !store.todayCourses.isEmpty {
                        ContentUnavailableView("今天的课程结束了", systemImage: "moon.stars",
                                               description: Text("休息一下，为明天留一点精力。"))
                    }
                    HStack(spacing: 0) {
                        summary("今日课程", value: "\(store.todayCourses.count)", unit: "门")
                        Divider().frame(height: 30)
                        summary("剩余课程", value: "\(store.todayCourses.filter { $0.endTime > previewTime }.count)", unit: "门")
                        Divider().frame(height: 30)
                        summary("最晚下课", value: store.todayCourses.last?.endTime ?? "—", unit: "")
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("一天的安排").font(.title3.weight(.bold))
                            Spacer()
                            Label("按时间排列", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                        }
                        if store.todayCourses.isEmpty {
                            ContentUnavailableView("今天没有课程", systemImage: "cup.and.saucer",
                                                   description: Text("可以添加课程，或到课表查看其他日期。"))
                        }
                        ForEach(store.todayCourses) { course in timelineRow(course) }
                    }
                    DemoNotice()
                }
                .padding(20).padding(.bottom, 20)
            }
            .background(DesignSystem.background)
            .navigationTitle("今日").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加课程", systemImage: "plus") { showingEditor = true }
                }
            }
            .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
            .sheet(isPresented: $showingEditor) { CourseEditorView() }
            .task { showingEditor = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "course" }
        }
    }

    private func focusCard(_ course: DemoCourse) -> some View {
        let ongoing = course.startTime <= previewTime
        return Button { selectedCourse = course } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(ongoing ? "正在上课" : "接下来", systemImage: ongoing ? "waveform" : "arrow.up.right.circle")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(ongoing ? "\(course.endTime) 下课" : "\(minutesUntil(course.startTime)) 分钟后上课")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(course.color.tint.opacity(0.12), in: Capsule())
                }
                .foregroundStyle(course.color.tint)
                Text(course.title).font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(.primary)
                HStack(alignment: .top, spacing: 18) {
                    Label("\(course.startTime)–\(course.endTime)", systemImage: "clock")
                    Label(course.shortRoom, systemImage: "mappin")
                }
                .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Text("第 \(course.startPeriod)–\(course.endPeriod) 节 · \(course.teacher)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(alignment: .top) {
                Capsule().fill(course.color.tint.opacity(0.6)).frame(width: 42, height: 3)
            }
        }
        .buttonStyle(.plain)
    }

    private func summary(_ title: String, value: String, unit: String) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title3.weight(.semibold).monospacedDigit())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineRow(_ course: DemoCourse) -> some View {
        let ended = course.endTime <= previewTime
        let current = nextCourse?.id == course.id
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(course.startTime).font(.subheadline.weight(.semibold).monospacedDigit())
                Text(course.endTime).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 48)
            VStack(spacing: 5) {
                Circle().fill(ended ? Color.secondary.opacity(0.35) : course.color.tint).frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.15)).frame(width: 1)
            }
            .frame(width: 8)
            Button { selectedCourse = course } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(course.title).font(.headline).foregroundStyle(.primary)
                        Spacer(minLength: 4)
                        Text(ended ? "已结束" : current ? (course.startTime <= previewTime ? "进行中" : "接下来") : "待上课")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ended ? Color.secondary : course.color.tint)
                    }
                    Label(course.room, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
                    Text("第 \(course.startPeriod)–\(course.endPeriod) 节 · \(course.teacher)").font(.caption).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.surface, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain).opacity(ended ? 0.65 : 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minutesUntil(_ end: String) -> Int {
        func minutes(_ value: String) -> Int {
            let parts = value.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        return max(0, minutes(end) - minutes(previewTime))
    }
}
