import SwiftUI

struct TodayView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.campusSuppressMotion) private var suppressMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .largeTitle) private var focusSize: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var timeColumn: CGFloat = 72
    @State private var selectedCourse: DemoCourse?
    @State private var showingEditor = false
    @State private var character = CampusCharacterPlayer(style: .girl)
    @State private var detailCharacter: CampusCharacterPlayer?
    @State private var courseFeedback = 0
    private var time: String { store.timeText }
    private var daily: [DemoCourse] { store.todayCourses }
    private var next: DemoCourse? { daily.first { $0.endTime > time } }
    private var characterContext: CampusScheduleContext {
        CampusScheduleContext.make(items: store.occurrences, now: store.now, leadMinutes: store.reminderMinutes)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    // 课程卡片随页面滚动，不再吸顶：吸顶后在长列表里挡住内容，而且
                    // 卡片本身足够大，滚动时一直压在顶部会显得拥挤。
                    LazyVStack(alignment: .leading, spacing: 0) {
                        introduction.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
                        // 考试提醒放在课程卡之前：临近考试时它比今天的课更该被看到。
                        examBanner
                        if let next {
                            focusCard(next)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity)
                        }
                        agenda.padding(.horizontal, 20).padding(.top, 18)
                        closingNote.padding(20)
                        Color.clear.frame(height: 20).id("agenda-end")
                    }
                    .padding(.bottom, 20)
                }
                .coordinateSpace(name: "todayScroll")
                .task {
                    // 截图流程需要看到页面底部的收尾区域。
                    guard store.isPreview, ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SCROLL"] == "1" else { return }
                    try? await Task.sleep(for: .milliseconds(700))
                    proxy.scrollTo("agenda-end", anchor: .bottom)
                }
            }
            .background(DesignSystem.background)
            .navigationTitle("今日").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("添加课程", systemImage: "plus") { showingEditor = true }.tint(DesignSystem.toolbarTint)
                }
            }
            .sheet(item: $selectedCourse) { CourseDetailView(course: $0, character: detailCharacter) }
            .sheet(isPresented: $showingEditor) { CourseEditorView() }
            .task {
                showingEditor = ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "course"
                if ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "detail", let next { openCourse(next) }
            }
            .sensoryFeedback(.selection, trigger: courseFeedback)
            .onChange(of: characterContext, initial: true) { _, context in
                character.synchronize(context, animated: scenePhase == .active && !reduceMotion && !suppressMotion)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { character.stop() }
            }
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
            }
        }
    }

    private func focusCard(_ course: DemoCourse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(course.startTime <= time ? "正在上课" : "下一节课").font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Button("课程详情", systemImage: "arrow.up.right") { openCourse(course) }
                        .labelStyle(.iconOnly).font(.caption).buttonStyle(.plain)
                }
                HStack(alignment: .center, spacing: 12) {
                    Button { openCourse(course) } label: {
                      VStack(alignment: .leading, spacing: 7) {
                        Text(course.title).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        Text(course.shortRoom.isEmpty ? "地点待确认" : course.shortRoom)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(course.startTime)–\(course.endTime)")
                            .font(.title3.weight(.medium).monospacedDigit())
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(CampusPressStyle()).accessibilityHint("查看课程详情")
                    if !typeSize.isAccessibilitySize {
                        CampusCharacter(player: character, contextDriven: true).frame(width: 78, height: 150)
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
        .foregroundStyle(.primary)
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
        return Button { openCourse(course) } label: {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.startTime).font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(course.endTime).font(.caption.monospacedDigit()).foregroundStyle(secondaryInk)
                }
                .frame(width: typeSize.isAccessibilitySize ? nil : timeColumn, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.title).font(.title3.weight(.bold))
                    Text(course.shortRoom.isEmpty ? "地点待确认" : course.shortRoom)
                        .font(.subheadline.weight(.medium))
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
        .buttonStyle(CampusPressStyle())
        .accessibilityElement(children: .combine)
    }

    /// 最近一场考试的提醒条。
    ///
    /// 只在两周内出现，避免平时占地方；已经考完的不显示。
    @ViewBuilder private var examBanner: some View {
        let upcoming = ExamPlan.upcoming(store.exams, now: store.now)
        if let next = upcoming.first,
           let days = ExamPlan.daysUntilNext(store.exams, now: store.now),
           days <= 14 {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(next.courseTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(examDetail(next, days: days))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(days == 0 ? "今天" : "\(days) 天")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.paper)
            .overlay(alignment: .bottom) {
                Rectangle().fill(DesignSystem.rule).frame(height: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("考试提醒：\(next.courseTitle)，\(examDetail(next, days: days))")
        }
    }

    private func examDetail(_ exam: Exam, days: Int) -> String {
        let date = exam.date.formatted(.dateTime.month().day())
        let place = exam.room.isEmpty ? "" : " · \(exam.room)"
        let when = days == 0 ? "\(exam.startTime) 开考" : "\(date) \(exam.startTime)"
        return when + place
    }

    /// 列表收尾：三种状态各自说明今天的情况，并附本周与本月统计。
    ///
    /// 居中排版，不带图标与手写字，避免看起来像可点的入口。
    @ViewBuilder private var closingNote: some View {
        let summary = ScheduleSummary.make(occurrences: store.occurrences, now: store.now,
                                           semesterStart: store.semesterStart)
        let state = ClosingState(daily: daily, remaining: summary.todayRemaining,
                                 completed: summary.todayCompleted)
        // 没有课时中间已有空状态说明，底部再写一次就是重复文案。
        if !(daily.isEmpty && summary.weekSessions == 0 && summary.monthSessions == 0) {
            VStack(spacing: 14) {
                VStack(spacing: 5) {
                    Text(state.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                if summary.weekSessions > 0 || summary.monthSessions > 0 {
                    statsRow(summary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
    }


    /// 一行小字：不加容器、不描边，避免看起来像一块卡片或可点的面板。
    private func statsRow(_ summary: ScheduleSummary) -> some View {
        Text("本周 \(summary.weekSessions) 节 · 本月已上 \(summary.monthCompleted)/\(summary.monthSessions) 节")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }

    /// 今日页收尾的三种状态。
    private struct ClosingState {
        let title: String
        let detail: String

        init(daily: [DemoCourse], remaining: Int, completed: Int) {
            if daily.isEmpty {
                title = "今天没有课"
                detail = "从添加第一门课开始，或到设置里导入课表。"
            } else if remaining > 0 {
                title = "今天的课程到这里"
                detail = "还有 \(remaining) 节没上。"
            } else {
                title = "今天的课都上完了"
                detail = completed > 0 ? "共 \(completed) 节，休息一下。" : "休息一下。"
            }
        }
    }

    private func openCourse(_ course: DemoCourse) {
        courseFeedback += 1
        // Inspecting a past/future lesson never changes today's character context.
        let relevant = characterContext.occurrenceID == course.id
        detailCharacter = relevant ? character : nil
        if relevant { character.respondToContext(reducedMotion: reduceMotion || suppressMotion) }
        selectedCourse = course
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
