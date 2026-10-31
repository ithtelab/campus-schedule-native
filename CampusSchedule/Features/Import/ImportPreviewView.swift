import SwiftUI

/// 导入前的预览与确认。用户在这里看到将要写入的全部内容。
struct ImportPreviewView: View {
    let plan: ImportPlanner.Plan
    let onConfirm: (ImportPlanner.Plan) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var grouped: [(weekday: Int, courses: [ParsedCourse])] {
        Dictionary(grouping: plan.courses, by: \.weekday)
            .map { (weekday: $0.key, courses: $0.value.sorted { $0.startPeriod < $1.startPeriod }) }
            .sorted { $0.weekday < $1.weekday }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("课程", value: "\(plan.courses.count) 门")
                    if plan.replacedCount > 0 {
                        LabeledContent("覆盖同名课程", value: "\(plan.replacedCount) 门")
                    }
                    if !plan.conflicts.isEmpty {
                        LabeledContent("时间重叠", value: "\(plan.conflicts.count) 处")
                            .foregroundStyle(.orange)
                    }
                } header: { Text("将导入") }

                ForEach(plan.warnings, id: \.self) { warning in
                    Section { Label(warning, systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }
                }

                if !plan.conflicts.isEmpty {
                    Section {
                        ForEach(plan.conflicts.indices, id: \.self) { index in
                            let conflict = plan.conflicts[index]
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(conflict.incoming.title) 与 \(conflict.existingTitle)").font(.callout)
                                Text(conflict.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } header: { Text("与现有课程重叠") }
                    footer: { Text("导入后这些时段会有两门课。可以继续导入，之后在课表里调整。") }
                }

                ForEach(grouped, id: \.weekday) { group in
                    Section(weekdayTitle(group.weekday)) {
                        ForEach(group.courses, id: \.self) { course in
                            row(course)
                        }
                    }
                }
            }
            .navigationTitle("确认导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel(); dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") { onConfirm(plan); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(!plan.isApplicable)
                }
            }
        }
    }

    private func row(_ course: ParsedCourse) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(course.title).lineLimit(1)
            HStack(spacing: 8) {
                Text("第\(course.startPeriod)-\(course.endPeriod)节")
                if !course.room.isEmpty { Text(course.room).lineLimit(1) }
                if !course.teacher.isEmpty { Text(course.teacher).lineLimit(1) }
            }
            .font(.caption).foregroundStyle(.secondary)
            Text(weeksText(course.weeks)).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func weeksText(_ weeks: Set<Int>) -> String {
        guard !weeks.isEmpty else { return "整学期" }
        let sorted = weeks.sorted()
        // 连续区间压成「1-8」，其余用逗号。
        var parts: [String] = []
        var start = sorted[0]
        var previous = sorted[0]
        for week in sorted.dropFirst() {
            if week == previous + 1 { previous = week; continue }
            parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
            start = week; previous = week
        }
        parts.append(start == previous ? "\(start)" : "\(start)-\(previous)")
        return parts.joined(separator: ",") + " 周"
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        "周" + ImportPlanner.weekdayName(weekday)
    }
}
