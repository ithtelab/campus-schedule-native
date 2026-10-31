import SwiftUI

struct WeekScheduleView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedCourse: DemoCourse?
    @State private var showingWeeks = false
    @State private var showingEditor = false
    @State private var toss = CourseTossReaction()
    private let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let rowHeight: CGFloat = 56
    private let groupGap: CGFloat = 22
    private var dayCount: Int { store.showsWeekend ? 7 : 5 }
    private var courses: [DemoCourse] { store.courses(in: store.selectedWeek) }
    private var totalHeight: CGFloat { rowHeight * 10 + groupGap * 2 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekHeader
                    .contentShape(Rectangle())
                    .simultaneousGesture(DragGesture(minimumDistance: 45).onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) * 1.5 { changeWeek(value.translation.width < 0 ? 1 : -1) }
                    })
                if typeSize.isAccessibilitySize { accessibleList }
                else {
                    GeometryReader { geometry in
                        let width = max(1, (geometry.size.width - 24 - 33 - CGFloat(dayCount) * 4) / CGFloat(dayCount))
                        VStack(spacing: 0) {
                            weekdayHeader(width: width)
                            ScrollView(.vertical) {
                                timetable(width: width).padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .background(DesignSystem.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { CourseTossDock(courses: courses, reaction: toss) }
            .navigationTitle("课表").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("这一周的课").font(DesignSystem.hand(23)).accessibilityAddTraits(.isHeader)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button(store.showsWeekend ? "显示五天" : "显示七天", systemImage: "calendar") { store.showsWeekend.toggle() }
                    } label: { Image(systemName: "ellipsis") }
                    .accessibilityLabel("课表显示选项")
                    .tint(DesignSystem.toolbarTint)
                    Button("添加课程", systemImage: "plus") { showingEditor = true }
                        .tint(DesignSystem.toolbarTint)
                }
            }
            .sheet(item: $selectedCourse) { CourseDetailView(course: $0) }
            .sheet(isPresented: $showingEditor) { CourseEditorView() }
            .sheet(isPresented: $showingWeeks) { weekPicker }
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
                    Text("\(store.date(week: store.selectedWeek).formatted(.dateTime.month().day())) — \(store.date(week: store.selectedWeek, day: 6).formatted(.dateTime.month().day())) · \(courses.count) 次课")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.selectedWeek != store.currentWeek {
                    Button("回到本周") { returnToCurrentWeek() }.font(.caption.weight(.medium))
                }
                HStack(spacing: 0) {
                    Button("上一周", systemImage: "chevron.left") { changeWeek(-1) }
                        .frame(width: 44, height: 44).disabled(store.selectedWeek <= 1)
                    Button("下一周", systemImage: "chevron.right") { changeWeek(1) }
                        .frame(width: 44, height: 44).disabled(store.selectedWeek >= store.totalWeeks)
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

    private func weekdayHeader(width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text("节次").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 33)
            ForEach(0..<dayCount, id: \.self) { day in
                let isToday = store.selectedWeek == store.currentWeek && day == (ScheduleRules.calendar.component(.weekday, from: store.now) + 5) % 7
                VStack(spacing: 5) {
                    Text(days[day]).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text("\(ScheduleRules.calendar.component(.day, from: store.date(week: store.selectedWeek, day: day)))")
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

    private func timetable(width: CGFloat) -> some View {
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
            ForEach(0..<dayCount, id: \.self) { day in dayColumn(day, width: width) }
        }
        .frame(height: totalHeight, alignment: .top).padding(.horizontal, 12)
        .overlay(alignment: .topLeading) {
            ForEach([5, 9], id: \.self) { period in
                Text(period == 5 ? "下午" : "晚上").font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
                    .padding(.leading, 16).offset(y: offset(period) - 19)
            }
        }
    }

    private func dayColumn(_ day: Int, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            ForEach(1...10, id: \.self) { period in
                Rectangle().fill(Color.primary.opacity(0.045)).frame(height: 0.5).offset(y: offset(period))
            }
            ForEach(courses.filter { $0.weekday == day }) { course in
                let height = max(32, position(course.endTime) - position(course.startTime) - 4)
                let date = store.date(week: store.selectedWeek, day: day)
                let ended = (ScheduleRules.date(day: date, time: course.endTime) ?? .distantFuture) <= store.now
                let ongoing = (ScheduleRules.date(day: date, time: course.startTime) ?? .distantFuture) <= store.now && !ended
                let ink = ongoing ? DesignSystem.inverse : Color.primary
                Button { selectedCourse = course } label: {
                    VStack(alignment: .leading, spacing: height < 65 ? 2 : 4) {
                        Text(course.title).font(.system(size: store.showsWeekend ? 12 : 14, weight: .bold)).lineLimit(height < 65 ? 2 : 4)
                        Text(course.shortRoom).font(.system(size: store.showsWeekend ? 9 : 10)).lineLimit(height < 65 ? 1 : 2).foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.8) : Color.secondary)
                        Spacer(minLength: 0)
                        if height >= 80 && !store.showsWeekend {
                            Text(course.startTime).font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(ongoing ? DesignSystem.inverse.opacity(0.8) : Color.secondary).lineLimit(1)
                        }
                    }
                    .padding(.leading, store.showsWeekend ? 6 : 8)
                    .padding(.trailing, store.showsWeekend ? 3 : 5).padding(.vertical, height < 65 ? 2 : 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: height)
                    .foregroundStyle(ink)
                    .background(ongoing ? Color.primary : ended ? DesignSystem.paper : Color.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 9))
                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(ended ? 0.2 : 0.25), lineWidth: 0.8) }
                }
                .buttonStyle(.plain).foregroundStyle(.primary).offset(y: min(totalHeight - 32, position(course.startTime)))
                .draggable(CourseTossReaction.payload(course))
                .accessibilityAction(named: "扔个纸团，保留课程") {
                    toss.accept([CourseTossReaction.payload(course)], courses: courses)
                }
                .accessibilityLabel("\(days[day])，\(course.title)，\(course.startTime)至\(course.endTime)，\(course.room)")
            }
        }
        .frame(width: width, height: totalHeight, alignment: .top)
        .overlay(alignment: .top) {
            if store.selectedWeek == store.currentWeek && day == (ScheduleRules.calendar.component(.weekday, from: store.now) + 5) % 7 {
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

    private var accessibleList: some View {
        List {
            ForEach(0..<dayCount, id: \.self) { day in
                Section(days[day]) {
                    let daily = courses.filter { $0.weekday == day }.sorted { $0.startPeriod < $1.startPeriod }
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
        CGFloat(period - 1) * rowHeight + (period >= 5 ? groupGap : 0) + (period >= 9 ? groupGap : 0)
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
    private func changeWeek(_ delta: Int) { store.selectedWeek = min(store.totalWeeks, max(1, store.selectedWeek + delta)) }
    private var hasHiddenWeekendCourses: Bool { !store.showsWeekend && courses.contains { $0.weekday >= 5 } }
    private func returnToCurrentWeek() { store.selectedWeek = min(store.totalWeeks, max(1, store.currentWeek)) }
}
