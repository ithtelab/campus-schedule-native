import SwiftUI

struct TodayView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var focusSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var timeColumn: CGFloat = 72
    @State private var selectedCourse: DemoCourse?
    @State private var showingEditor = false
    @State private var pinnedY: CGFloat = .infinity
    private var time: String { store.timeText }
    private var daily: [DemoCourse] { store.todayCourses }
    private var next: DemoCourse? { daily.first { $0.endTime > time } }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        introduction.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
                        Section {
                            agenda.padding(.horizontal, 20).padding(.top, 18)
                            closingNote.padding(20)
                            DemoNotice().padding(.horizontal, 20)
                            Color.clear.frame(height: 20).id("agenda-end")
                        } header: {
                            if let next {
                                focusCard(next)
                                    .padding(.horizontal, 20).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(DesignSystem.paper)
                                    .onGeometryChange(for: CGFloat.self) { geometry in
                                        geometry.frame(in: .named("todayScroll")).minY
                                    } action: { value in
                                        if store.isPreview { pinnedY = value }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .coordinateSpace(name: "todayScroll")
                .task {
                    guard store.isPreview, ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SCROLL"] == "1" else { return }
                    try? await Task.sleep(for: .milliseconds(700))
                    proxy.scrollTo("agenda-end", anchor: .bottom)
                    try? await Task.sleep(for: .milliseconds(700))
                    let result = abs(pinnedY) <= 2 ? "PASS: course header stays pinned; y=\(pinnedY)" : "FAIL: pinned header y=\(pinnedY)"
                    try? result.write(to: URL.documentsDirectory.appendingPathComponent("today-sticky-smoke.txt"), atomically: true, encoding: .utf8)
                }
            }
            .background(DesignSystem.background)
            .navigationTitle("今日").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加课程", systemImage: "plus") { showingEditor = true }.tint(DesignSystem.toolbarTint)
                }
            }
            .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
            .sheet(isPresented: $showingEditor) { CourseEditorView() }
            .task { showingEditor = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "course" }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
            CampusHeading(title: next == nil && !daily.isEmpty ? "下课啦。" : "今天，去上课。")
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            layout {
                Text(store.now, format: .dateTime.month().day().weekday(.wide)).font(.caption)
                if !typeSize.isAccessibilitySize { Spacer() }
                Text("第 \(store.currentWeek) 周").font(.caption.weight(.medium))
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .foregroundStyle(DesignSystem.inverse)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 5)).rotationEffect(.degrees(-2))
                if store.isPreview {
                    Text("演示 \(time)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func focusCard(_ course: DemoCourse) -> some View {
        Button { selectedCourse = course } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(course.startTime <= time ? "正在上课" : "下一节课").font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.caption).accessibilityHidden(true)
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(course.title).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        Text(course.shortRoom.isEmpty ? "地点待确认" : course.shortRoom)
                            .font(.system(size: min(focusSize, 44), weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(course.startTime)–\(course.endTime)")
                            .font(.system(size: min(focusSize, 44), weight: .bold, design: .rounded).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize {
                        CampusFigure(pose: course.startTime <= time ? .walking : .reading)
                            .frame(width: 72, height: 134)
                    }
                }
                Text(course.startTime <= time ? "\(course.endTime) 下课" : "\(minutesUntil(course.startTime)) 分钟后上课")
                    .font(.caption.weight(.medium).monospacedDigit())
                if let movement = roomChangeMessage(after: course) {
                    Text(movement).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.paper, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary, lineWidth: 1.2) }
        }
        .buttonStyle(.plain).foregroundStyle(.primary)
        .accessibilityHint("查看课程详情")
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text("一天的安排").font(DesignSystem.hand(25))
                if !typeSize.isAccessibilitySize { Spacer() }
                Text("\(daily.count) 门课 · \(daily.last?.endTime ?? "—") 结束")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if daily.isEmpty {
                ContentUnavailableView("今天没有课程", systemImage: "calendar",
                                       description: Text("添加课程，或到课表查看其他日期。"))
            }
            ForEach(daily) { course in agendaRow(course) }
        }
    }

    private func agendaRow(_ course: DemoCourse) -> some View {
        let ended = course.endTime <= time
        let focused = next?.id == course.id
        let ink = focused ? DesignSystem.inverse : Color.primary
        let secondaryInk = focused ? DesignSystem.inverse.opacity(0.8) : Color.secondary
        return Button { selectedCourse = course } label: {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.startTime).font(.title3.weight(.bold).monospacedDigit())
                    Text(course.endTime).font(.caption.monospacedDigit()).foregroundStyle(secondaryInk)
                }
                .frame(width: typeSize.isAccessibilitySize ? nil : timeColumn, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.title).font(.subheadline.weight(.medium))
                    Text(course.shortRoom.isEmpty ? "地点待确认" : course.shortRoom)
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(ended ? "已结束" : focused ? (course.startTime <= time ? "进行中" : "接下来") : "待上课")
                    .font(.caption2).foregroundStyle(secondaryInk)
                    .frame(width: typeSize.isAccessibilitySize ? nil : 40, alignment: .trailing)
            }
            .foregroundStyle(ink).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 15).padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? Color.primary : ended ? DesignSystem.paper : Color.primary.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if ended { RoundedRectangle(cornerRadius: 12).strokeBorder(DesignSystem.rule, lineWidth: 0.75) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var closingNote: some View {
        HStack(spacing: 16) {
            if next == nil {
                CampusFigure(pose: .stretching).frame(width: 88, height: 158)
                VStack(alignment: .leading, spacing: 8) {
                    Text(daily.isEmpty ? "暂时没有课程" : "把时间留给自己").font(DesignSystem.hand(24))
                    Text(daily.isEmpty ? "从添加第一门课开始。" : "今天的课程结束了，休息一下。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                CampusNotebook().stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 34, height: 38).rotationEffect(.degrees(-5)).accessibilityHidden(true)
                Text("校园日常").font(DesignSystem.hand(23))
                Spacer()
            }
        }
    }

    private func roomChangeMessage(after course: DemoCourse) -> String? {
        guard course.startTime <= time,
              let following = daily.first(where: { $0.startTime >= course.endTime && $0.id != course.id }) else { return nil }
        guard let moves = ScheduleRules.needsMove(from: course.room, to: following.room) else { return "下一节地点待确认" }
        return moves ? "下一节换教室 · \(following.startTime) \(following.shortRoom)" : nil
    }

    private func minutesUntil(_ end: String) -> Int {
        func minutes(_ text: String) -> Int {
            let parts = text.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        return max(0, minutes(end) - minutes(time))
    }
}
