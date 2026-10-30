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
            $0.weekday == weekday && !$0.weeks.isDisjoint(with: weeks)
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

                Section("课程颜色") {
                    HStack(spacing: 18) {
                        ForEach(CourseColor.allCases, id: \.self) { item in
                            Button { color = item } label: {
                                Circle().fill(item.tint.opacity(0.18)).frame(width: 40, height: 40)
                                    .overlay { Circle().fill(item.tint).frame(width: 22, height: 22) }
                                    .overlay { if color == item { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain).accessibilityLabel(item.name)
                            .accessibilityAddTraits(color == item ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    if conflict { Label("与已有课程时间重叠，请调整时间或周次", systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
                    Label("仅在本次演示中添加", systemImage: "info.circle").foregroundStyle(.secondary)
                } footer: { Text("目前不保存到设备。关闭 APP 后会恢复演示数据，不会安排通知。") }
            }
            .navigationTitle("添加课程").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { addCourse() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weeks.isEmpty || conflict)
                }
            }
            .onChange(of: startPeriod) { _, value in endPeriod = max(endPeriod, value) }
            .task {
                if ProcessInfo.processInfo.environment["CAMPUS_PREVIEW_SHEET"] == "course" {
                    title = "线性代数"; room = "教学楼 A · 206"; teacher = "李老师"; frequency = "双周"
                }
            }
        }
        .presentationDetents([.large])
    }

    private func addCourse() {
        guard !conflict, !weeks.isEmpty else { return }
        store.courses.append(DemoCourse(
            id: UUID().uuidString, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "地点待定" : room,
            teacher: teacher.isEmpty ? "教师待定" : teacher, weekday: weekday,
            startPeriod: startPeriod, endPeriod: endPeriod,
            startTime: store.periods[startPeriod - 1].start, endTime: store.periods[endPeriod - 1].end,
            color: color, weeks: weeks))
        dismiss()
    }
}
