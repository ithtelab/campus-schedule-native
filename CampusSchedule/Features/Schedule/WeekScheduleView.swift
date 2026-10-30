import SwiftUI

struct WeekScheduleView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedCourse: DemoCourse?
    @State private var showingWeeks = false
    @State private var showingEditor = false
    private let days = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    private let rowHeight: CGFloat = 48
    private let groupGap: CGFloat = 26
    private var dayCount: Int { store.showsWeekend ? 7 : 5 }
    private var courses: [DemoCourse] { store.courses(in: store.selectedWeek) }
    private var totalHeight: CGFloat { rowHeight * 10 + groupGap * 2 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekHeader
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
            .navigationTitle("课表").navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    Text("\(courses.count) 次课 · 演示课表").font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
            } else {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Button { showingWeeks = true } label: {
                        HStack(spacing: 7) {
                            Text("第 \(store.selectedWeek) 周").font(.title2.weight(.bold))
                            Image(systemName: "chevron.down").font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.primary)
                    }
                    Text("\(store.date(week: store.selectedWeek).formatted(.dateTime.month().day())) — \(store.date(week: store.selectedWeek, day: 6).formatted(.dateTime.month().day()))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if store.selectedWeek != 8 {
                    Button("回到示例周") { store.selectedWeek = 8 }.font(.caption.weight(.medium))
                } else {
                    Text(store.showsWeekend ? "七天视图" : "工作日").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    Button("上一周", systemImage: "chevron.left") { changeWeek(-1) }.disabled(store.selectedWeek <= 1)
                    Button("下一周", systemImage: "chevron.right") { changeWeek(1) }.disabled(store.selectedWeek >= store.totalWeeks)
                }
                .labelStyle(.iconOnly).font(.subheadline.weight(.semibold)).padding(.leading, 8)
            }
            HStack(spacing: 5) {
                Circle().fill(DesignSystem.accent).frame(width: 5, height: 5)
                Text("\(courses.count) 门课程安排")
                Spacer()
                if !store.showsWeekend && courses.contains(where: { $0.weekday >= 5 }) {
                    Button("周末有课") { store.showsWeekend = true }
                } else { Text("演示课表") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 18)
            }
        }
    }

    private func weekdayHeader(width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text("节次").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 33)
            ForEach(0..<dayCount, id: \.self) { day in
                let isToday = store.selectedWeek == 8 && day == 0
                VStack(spacing: 5) {
                    Text(days[day]).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Text("\(Calendar.current.component(.day, from: store.date(week: store.selectedWeek, day: day)))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(isToday ? Color.white : Color.primary)
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
        .simultaneousGesture(DragGesture(minimumDistance: 45).onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height) * 1.5 { changeWeek(value.translation.width < 0 ? 1 : -1) }
        })
    }

    private func dayColumn(_ day: Int, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            if store.selectedWeek == 8 && day == 0 {
                RoundedRectangle(cornerRadius: 12).fill(DesignSystem.accent.opacity(0.035))
            }
            ForEach(1...10, id: \.self) { period in
                Rectangle().fill(Color.primary.opacity(0.035)).frame(height: 0.5).offset(y: offset(period))
            }
            ForEach(courses.filter { $0.weekday == day }) { course in
                Button { selectedCourse = course } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(course.title).font(.system(size: store.showsWeekend ? 10 : 12, weight: .semibold)).lineLimit(3)
                        Text(course.shortRoom).font(.system(size: store.showsWeekend ? 9 : 10)).lineLimit(2).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, store.showsWeekend ? 4 : 6).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: offset(course.endPeriod) + rowHeight - offset(course.startPeriod) - 4)
                    .background(course.color.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        Capsule().fill(course.color.tint.opacity(0.8)).frame(width: 16, height: 2).padding(.leading, 7).padding(.top, 3)
                    }
                }
                .buttonStyle(.plain).foregroundStyle(.primary).offset(y: offset(course.startPeriod))
                .accessibilityLabel("\(days[day])，\(course.title)，\(course.startTime)至\(course.endTime)，\(course.room)")
            }
        }
        .frame(width: width, height: totalHeight, alignment: .top)
        .overlay(alignment: .top) {
            if store.selectedWeek == 8 && day == 0 {
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 5, height: 5)
                    Rectangle().fill(.red.opacity(0.7)).frame(height: 1)
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
        let now = 9 * 60 + 41
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
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(course.color.tint)
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
    private func changeWeek(_ delta: Int) { store.selectedWeek = min(store.totalWeeks, max(1, store.selectedWeek + delta)) }
}
