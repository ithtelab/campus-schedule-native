import SwiftUI

struct WeekScheduleView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var selectedCourse: DemoCourse?
    @State private var showingWeeks = false
    @State private var showingEditor = false
    @State private var showingImport = false
    @State private var showingSearch = false
    private let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let rowHeight: CGFloat = 56
    private let groupGap: CGFloat = 22
    private var dayCount: Int { store.showsWeekend ? 7 : 5 }
    private var courses: [DemoCourse] { store.courses(in: store.selectedWeek) }
    /// 网格总高度：按实际节次数计算，额外的高度来自上下午之间的分组间隔。
    private var totalHeight: CGFloat {
        CGFloat(max(1, store.periods.count)) * rowHeight + groupGap * CGFloat(periodGroupMarks.count)
    }

    var body: some View {
        @Bindable var calendar = store
        NavigationStack {
            VStack(spacing: 0) {
                nowStatusBar
                weekHeader
                TabView(selection: $calendar.selectedWeek) {
                    ForEach(1...store.totalWeeks, id: \.self) { week in
                        weekPage(week).tag(week)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(DesignSystem.background)
            .overlay { emptyTermGuide }
            .navigationTitle("课表").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("这一周的课").font(DesignSystem.hand(23)).accessibilityAddTraits(.isHeader)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        // 学期切换放在这里：课表上看到的是哪个学期，是使用中最常需要确认的事。
                        if store.terms.count > 1 {
                            Menu("切换学期", systemImage: "square.stack") {
                                ForEach(store.terms) { term in
                                    Button {
                                        store.selectTerm(term.id)
                                    } label: {
                                        if term.id == store.activeTermID {
                                            Label(term.name, systemImage: "checkmark")
                                        } else {
                                            Text(term.name)
                                        }
                                    }
                                }
                            }
                        }
                        Button("搜索课程", systemImage: "magnifyingglass") { showingSearch = true }
                        Button(store.showsWeekend ? "显示五天" : "显示七天", systemImage: "calendar") { store.showsWeekend.toggle() }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("课表显示选项")
                    .tint(DesignSystem.toolbarTint)
                    Button("添加课程", systemImage: "plus") { showingEditor = true }
                        .tint(DesignSystem.toolbarTint)
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
            .sheet(isPresented: $showingEditor) { CourseEditorView() }
            .sheet(isPresented: $showingWeeks) { weekPicker }
            .sheet(isPresented: $showingImport) { ImportView() }
            .sheet(isPresented: $showingSearch) { CourseSearchView() }
        }
    }

    @ViewBuilder private func weekPage(_ week: Int) -> some View {
        if typeSize.isAccessibilitySize { accessibleList(week: week) }
        else {
            GeometryReader { geometry in
                // iPad 全屏时单日列会被拉到 200 点以上，课程卡里的两行文字显得很空。
                // 限制内容宽度并居中，让五天网格保持手机上的疏密比例。
                let available = min(geometry.size.width, Self.maximumContentWidth)
                let width = max(1, (available - 24 - 33 - CGFloat(dayCount) * 4) / CGFloat(dayCount))
                let pageCourses = store.courses(in: week)
                VStack(spacing: 0) {
                    weekdayHeader(width: width, week: week)
                    ScrollView(.vertical) {
                        timetable(width: width, week: week, courses: pageCourses).padding(.bottom, 20)
                    }
                }
                .frame(width: available)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// 五天网格超过这个宽度后不再变宽，只增加两侧留白。
    private static let maximumContentWidth: CGFloat = 620

    /// 顶部状态条：正在上课时显示地点与剩余时间，未到时显示下一节。
    ///
    /// 学生打开课表最想知道的就是这两件事，因此放在最上方而不是要求切换到今日页。
    @ViewBuilder private var nowStatusBar: some View {
        let phase = NowStatus.phase(for: store.occurrences, now: store.now)
        if let title = NowStatus.title(phase), let detail = NowStatus.detail(phase) {
            HStack(spacing: 10) {
                Circle()
                    .fill(NowStatus.isUrgent(phase) ? DesignSystem.accent : DesignSystem.accent.opacity(0.35))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.paper)
            .overlay(alignment: .bottom) {
                Rectangle().fill(DesignSystem.rule).frame(height: 0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)，\(detail)")
        }
    }

    /// 整个学期没有任何课程时的引导。
    ///
    /// 首次使用必须导入或添加课程，而这两个入口原本藏在设置里；这里直接给出来，
    /// 免得用户对着空网格不知道下一步。
    @ViewBuilder private var emptyTermGuide: some View {
        // 判断整学期是否为空，而不是当前周：第 3 周没课不代表课表是空的。
        if store.courses.isEmpty && !store.isPreview {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                VStack(spacing: 6) {
                    Text("还没有课程").font(.headline)
                    Text("从教务系统导入，或手动添加第一门课。")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    Button("导入课表") { showingImport = true }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.accent)
                    Button("手动添加") { showingEditor = true }
                        .buttonStyle(.bordered)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.background)
        }
    }

    private var weekHeader: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button { showingWeeks = true } label: {
                            Text("第 \(store.selectedWeek) 周").font(.title3.weight(.bold))
                        }
                        Spacer()
                        Button("上一周", systemImage: "chevron.left") { changeWeek(-1) }
                            .labelStyle(.iconOnly).disabled(store.selectedWeek <= 1)
                        Button("下一周", systemImage: "chevron.right") { changeWeek(1) }
                            .labelStyle(.iconOnly).disabled(store.selectedWeek >= store.totalWeeks)
                    }
                    Text("\(store.date(week: store.selectedWeek).formatted(.dateTime.month().day())) — \(store.date(week: store.selectedWeek, day: 6).formatted(.dateTime.month().day()))")
                        .font(.caption).foregroundStyle(.secondary)
                    if store.selectedWeek != store.currentWeek {
                        Button("回到本周") { returnToCurrentWeek() }.font(.subheadline)
                    }
                    if hasHiddenWeekendCourses {
                        Button("周末有课 · 显示七天") { store.showsWeekend = true }.font(.subheadline)
                    }
                }
                .padding(20)
            } else {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Button { showingWeeks = true } label: {
                        HStack(spacing: 7) {
                            Text("第 \(store.selectedWeek) 周").font(.title3.weight(.bold))
                            Image(systemName: "chevron.down").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.primary)
                    }
                    let progress = NowStatus.weekProgress(for: store.occurrences, week: store.selectedWeek,
                                                          semesterStart: store.semesterStart, now: store.now)
                    Text("\(store.date(week: store.selectedWeek).formatted(.dateTime.month().day())) — \(store.date(week: store.selectedWeek, day: 6).formatted(.dateTime.month().day())) · \(progress.text)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.selectedWeek != store.currentWeek {
                    Button("回到本周") { returnToCurrentWeek() }.font(.caption.weight(.medium))
                }
                HStack(spacing: 0) {
                    Button("上一周", systemImage: "chevron.left") { changeWeek(-1) }
                        .frame(width: 44, height: 44).disabled(store.selectedWeek <= 1)
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                    Button("下一周", systemImage: "chevron.right") { changeWeek(1) }
                        .frame(width: 44, height: 44).disabled(store.selectedWeek >= store.totalWeeks)
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                }
                .labelStyle(.iconOnly).font(.subheadline.weight(.semibold)).padding(.leading, 8)
            }
            if hasHiddenWeekendCourses {
                Button("周末有课 · 显示七天") { store.showsWeekend = true }
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 12)
            }
        }
    }

    private func weekdayHeader(width: CGFloat, week: Int) -> some View {
        HStack(spacing: 4) {
            Text("节次").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 33)
            ForEach(0..<dayCount, id: \.self) { day in
                let isToday = week == store.currentWeek && day == (ScheduleRules.calendar.component(.weekday, from: store.now) + 5) % 7
                VStack(spacing: 5) {
                    Text(days[day]).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text("\(ScheduleRules.calendar.component(.day, from: store.date(week: week, day: day)))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(isToday ? DesignSystem.inverse : Color.primary)
                        .background(isToday ? DesignSystem.accent : Color.clear, in: Circle())
                }
                .frame(width: width).accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    private func timetable(width: CGFloat, week: Int, courses: [DemoCourse]) -> some View {
        HStack(alignment: .top, spacing: 4) {
            ZStack(alignment: .top) {
                ForEach(store.periods) { period in
                    VStack(spacing: 3) {
                        Text("\(period.id)").font(.system(size: 11, weight: .medium))
                        Text(period.start).font(.system(size: 8).monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .frame(width: 33, height: rowHeight, alignment: .top)
                    .offset(y: offset(period.id) + 8)
                }
            }
            .frame(width: 33, height: totalHeight, alignment: .top)
            ForEach(0..<dayCount, id: \.self) { day in dayColumn(day, width: width, week: week, courses: courses) }
        }
        .frame(height: totalHeight, alignment: .top).padding(.horizontal, 12)
        .overlay(alignment: .topLeading) {
            ForEach(periodGroupMarks, id: \.self) { mark in
                Text(mark.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
                    .padding(.leading, 16).offset(y: offset(mark.period) - 19)
            }
        }
    }

    /// 「下午」「晚上」两个分界标记。
    ///
    /// 各校节次数不同（8…14 节），因此按总节次三等分取近似位置，
    /// 而不是写死第 5 节和第 9 节。
    private struct PeriodGroupMark: Hashable {
        let period: Int
        let label: String
    }

    private var periodGroupMarks: [PeriodGroupMark] {
        let ids = store.periods.map(\.id)
        guard ids.count >= 6 else { return [] }
        let afternoon = ids[ids.count / 3]
        let evening = ids[ids.count * 2 / 3]
        return [PeriodGroupMark(period: afternoon, label: "下午"),
                PeriodGroupMark(period: evening, label: "晚上")]
    }

    /// 教室文案。调课换教室时同时给出原地点，便于对照。
    private func roomText(_ course: DemoCourse) -> String {
        guard course.wasRescheduled, let original = course.originalRoom, !original.isEmpty else {
            return course.shortRoom
        }
        return "\(course.shortRoom)（原 \(DemoCourse.shorten(original))）"
    }

    private func dayColumn(_ day: Int, width: CGFloat, week: Int, courses: [DemoCourse]) -> some View {
        ZStack(alignment: .top) {
            ForEach(store.periods.map(\.id), id: \.self) { period in
                Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 0.5).offset(y: offset(period))
            }
            ForEach(courses.filter { $0.weekday == day }) { course in
                let height = max(32, position(course.endTime) - position(course.startTime) - 4)
                let date = store.date(week: week, day: day)
                let ended = (ScheduleRules.date(day: date, time: course.endTime) ?? .distantFuture) <= store.now
                let ongoing = (ScheduleRules.date(day: date, time: course.startTime) ?? .distantFuture) <= store.now && !ended
                let ink = ongoing ? DesignSystem.inverse : Color.primary
                // 颜色只作识别辅助：进行中用色条实色，已结束压淡，其余用低饱和底色。
                let cardFill = ongoing ? course.color.accentColor
                    : ended ? course.color.endedFill(for: scheme) : course.color.fill(for: scheme)
                let borderColor = ongoing ? course.color.accentColor : course.color.border(for: scheme)
                Button { selectedCourse = course } label: {
                    HStack(spacing: 0) {
                        // 左侧窄色条：即使卡片很矮也能靠颜色分辨课程。
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(ongoing ? DesignSystem.inverse.opacity(0.85) : course.color.accentColor)
                            .frame(width: 3)
                            .padding(.vertical, height < 65 ? 3 : 6)
                            .padding(.leading, store.showsWeekend ? 4 : 5)
                        VStack(alignment: .leading, spacing: height < 65 ? 2 : 4) {
                            HStack(alignment: .top, spacing: 3) {
                                Text(course.title).font(.system(size: store.showsWeekend ? 12 : 14, weight: .bold)).lineLimit(height < 65 ? 2 : 4)
                                // 单双周角标：学生按周次决定今天要不要来上课。
                                if let badge = course.weekPattern.badge, height >= 52 {
                                    Text(badge)
                                        .font(.system(size: 8, weight: .heavy))
                                        .padding(.horizontal, 3).padding(.vertical, 1)
                                        .background(ongoing ? DesignSystem.inverse.opacity(0.25) : course.color.accentColor.opacity(0.28),
                                                    in: RoundedRectangle(cornerRadius: 3))
                                        .lineLimit(1)
                                }
                            }
                            Text(roomText(course)).font(.system(size: store.showsWeekend ? 9 : 10)).lineLimit(height < 65 ? 1 : 2)
                                .foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.8) : Color.secondary)
                            if course.wasRescheduled && height >= 80 {
                                // 明确标出「调课」，否则学生按原教室跑一趟才发现换了地方。
                                Text("调课")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.85) : course.color.accentColor)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if height >= 80 && !store.showsWeekend {
                                // 一行放不下起止时间会被省略号截断，改成分两行：
                                // 学生要知道几点下课，截断等于没给。
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(course.startTime)
                                    Text(course.endTime)
                                }
                                .font(.system(size: 8.5).monospacedDigit())
                                .foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.8) : Color.secondary)
                                .lineLimit(1)
                            } else if height >= 52 && store.showsWeekend {
                                // 七天视图列窄，只补结束时间也要能挤下。
                                Text(course.endTime).font(.system(size: 8.5).monospacedDigit())
                                    .foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.75) : Color.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, store.showsWeekend ? 4 : 6)
                        .padding(.trailing, store.showsWeekend ? 3 : 5)
                        .padding(.vertical, height < 65 ? 2 : 7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: height)
                    .foregroundStyle(ink)
                    .background(cardFill, in: RoundedRectangle(cornerRadius: 9))
                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(borderColor, lineWidth: 0.8) }
                }
                .buttonStyle(.plain).foregroundStyle(.primary)
                .accessibilityLabel("\(days[day])，\(course.title)，\(course.startTime)至\(course.endTime)，\(course.room)")
                .offset(y: min(totalHeight - 32, position(course.startTime)))
            }
        }
        .frame(width: width, height: totalHeight, alignment: .top)
        .overlay(alignment: .top) {
            if week == store.currentWeek && day == (ScheduleRules.calendar.component(.weekday, from: store.now) + 5) % 7 {
                HStack(spacing: 0) {
                    Circle().fill(.primary).frame(width: 5, height: 5)
                    Rectangle().fill(.primary).frame(height: 1)
                }
                .offset(y: previewLineOffset - 2).accessibilityHidden(true)
            }
        }
    }

    private var previewLineOffset: CGFloat {
        func minutes(_ value: String) -> Int {
            let pieces = value.split(separator: ":").compactMap { Int($0) }
            return pieces[0] * 60 + pieces[1]
        }
        let now = minutes(store.timeText)
        for period in store.periods {
            let start = minutes(period.start)
            let end = minutes(period.end)
            if now < start { return offset(period.id) }
            if now <= end {
                return offset(period.id) + rowHeight * CGFloat(now - start) / CGFloat(max(1, end - start))
            }
        }
        return totalHeight
    }

    private func accessibleList(week: Int) -> some View {
        List {
            ForEach(0..<dayCount, id: \.self) { day in
                Section(days[day]) {
                    let daily = store.courses(in: week).filter { $0.weekday == day }.sorted { $0.startPeriod < $1.startPeriod }
                    if daily.isEmpty { Text("没有课程").foregroundStyle(.secondary) }
                    ForEach(daily) { course in
                        Button { selectedCourse = course } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(course.title).font(.headline).foregroundStyle(.primary)
                                Text("\(course.startTime)–\(course.endTime)")
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                Text(course.room).font(.subheadline).foregroundStyle(.secondary)
                                Text("第 \(course.startPeriod)–\(course.endPeriod) 节 · \(course.teacher)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var weekPicker: some View {
        NavigationStack {
            List(1...store.totalWeeks, id: \.self) { week in
                Button {
                    store.selectedWeek = week
                    showingWeeks = false
                } label: {
                    HStack {
                        Text("第 \(week) 周")
                        Text(store.date(week: week), format: .dateTime.month().day()).foregroundStyle(.secondary)
                        Spacer()
                        if store.selectedWeek == week { Image(systemName: "checkmark") }
                    }
                    .foregroundStyle(store.selectedWeek == week ? DesignSystem.accent : Color.primary)
                }
            }
            .navigationTitle("选择教学周").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingWeeks = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func offset(_ period: Int) -> CGFloat {
        // 每个分组标记之前都留出间隔，位置与「下午/晚上」标签使用同一份数据源。
        let extra = CGFloat(periodGroupMarks.filter { period >= $0.period }.count) * groupGap
        return CGFloat(period - 1) * rowHeight + extra
    }
    private func position(_ time: String) -> CGFloat {
        func minutes(_ text: String) -> Int {
            let parts = text.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        let value = minutes(time)
        for period in store.periods {
            let start = minutes(period.start), end = minutes(period.end)
            if value < start { return offset(period.id) }
            if value <= end { return offset(period.id) + rowHeight * CGFloat(value - start) / CGFloat(max(1, end - start)) }
        }
        return totalHeight
    }
    private func changeWeek(_ delta: Int) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            store.selectedWeek = min(store.totalWeeks, max(1, store.selectedWeek + delta))
        }
    }
    private var hasHiddenWeekendCourses: Bool { !store.showsWeekend && courses.contains { $0.weekday >= 5 } }
    private func returnToCurrentWeek() { store.selectedWeek = min(store.totalWeeks, max(1, store.currentWeek)) }
}
