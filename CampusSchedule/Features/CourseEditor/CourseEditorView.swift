import SwiftUI

struct CourseEditorView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var room = ""
    @State private var teacher = ""
    @State private var weekday = 0
    @State private var startPeriod = 5
    @State private var endPeriod = 6
    @State private var color = CourseColor.blue
    @State private var frequency = "每周"
    @State private var customWeeks: Set<Int> = [8]
    var editing: DemoCourse? = nil
    var template: DemoCourse? = nil
    private let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    private var weeks: Set<Int> {
        let all = Set(1...store.totalWeeks)
        switch frequency {
        case "单周": return all.filter { $0 % 2 == 1 }
        case "双周": return all.filter { $0 % 2 == 0 }
        case "指定": return customWeeks.intersection(all)
        default: return all
        }
    }

    private var conflict: Bool {
        store.courses.contains {
            $0.id != editing?.id && $0.weekday == weekday && !$0.weeks.isDisjoint(with: weeks)
                && $0.startPeriod <= endPeriod && $0.endPeriod >= startPeriod
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("课程名称", text: $title).font(.title3.weight(.semibold))
                    TextField("上课地点，例如 A 楼 302", text: $room)
                    TextField("任课教师（选填）", text: $teacher)
                } header: { Text("课程信息") }

                Section("上课时间") {
                    Picker("星期", selection: $weekday) {
                        ForEach(0..<7, id: \.self) { Text(weekdays[$0]).tag($0) }
                    }
                    Picker("开始节次", selection: $startPeriod) {
                        ForEach(1...10, id: \.self) { Text("第 \($0) 节").tag($0) }
                    }
                    Picker("结束节次", selection: $endPeriod) {
                        ForEach(startPeriod...10, id: \.self) { Text("第 \($0) 节").tag($0) }
                    }
                    LabeledContent("对应时间", value: "\(store.periods[startPeriod - 1].start)–\(store.periods[endPeriod - 1].end)")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("重复", selection: $frequency) {
                        ForEach(["每周", "单周", "双周", "指定"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if frequency == "指定" {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(1...store.totalWeeks, id: \.self) { week in
                                Button {
                                    if customWeeks.contains(week) { customWeeks.remove(week) }
                                    else { customWeeks.insert(week) }
                                } label: {
                                    Text("\(week)").font(.subheadline.monospacedDigit())
                                        .foregroundStyle(customWeeks.contains(week) ? DesignSystem.accent : Color.primary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(customWeeks.contains(week) ? DesignSystem.accent.opacity(0.15) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("第 \(week) 周")
                                .accessibilityAddTraits(customWeeks.contains(week) ? [.isSelected] : [])
                            }
                        }
                    }
                } header: { Text("上课周次") }
                footer: { Text("已选择 \(weeks.count) 个教学周。指定周次适合短学期课程或集中授课。") }

                Section {
                    if conflict { Label("与已有课程时间重叠，请调整时间或周次", systemImage: "exclamationmark.circle").foregroundStyle(.primary) }
                    Label(store.isPreview ? "本次仅为演示" : "课程保存在本机", systemImage: "info.circle").foregroundStyle(.secondary)
                } footer: { Text(store.isPreview ? "退出后恢复演示数据。" : "设置中可开启上课提醒，组件将使用同一份课表。") }
            }
            .navigationTitle(editing == nil ? "添加课程" : "编辑课程").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "添加" : "保存") { addCourse() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weeks.isEmpty || conflict)
                }
            }
            .onChange(of: startPeriod) { _, value in endPeriod = max(endPeriod, value) }
            .task {
                if let template {
                    title = template.title; room = template.room; teacher = template.teacher
                    startPeriod = template.startPeriod; endPeriod = template.endPeriod; color = template.color
                    frequency = "指定"; customWeeks = [min(store.totalWeeks, max(1, store.currentWeek))]
                }
                if let editing {
                    title = editing.title; room = editing.room; teacher = editing.teacher; weekday = editing.weekday
                    startPeriod = editing.startPeriod; endPeriod = editing.endPeriod; color = editing.color
                    customWeeks = editing.weeks; frequency = "指定"
                }
                if ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "course" {
                    title = "线性代数"; room = "教学楼 A · 206"; teacher = "李老师"; frequency = "双周"
                }
            }
        }
        .presentationDetents([.large])
    }

    private func addCourse() {
        guard !conflict, !weeks.isEmpty else { return }
        var value = DemoCourse(
            id: editing?.id ?? UUID().uuidString, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "地点待定" : room,
            teacher: teacher.isEmpty ? "教师待定" : teacher, weekday: weekday,
            startPeriod: startPeriod, endPeriod: endPeriod,
            startTime: store.periods[startPeriod - 1].start, endTime: store.periods[endPeriod - 1].end,
            color: color, weeks: weeks)
        value.remindersEnabled = editing?.remindersEnabled ?? true
        if let editing { store.courses.removeAll { $0.id == editing.id } }
        store.courses.append(value)
        dismiss()
    }
}
