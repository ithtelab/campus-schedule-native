import SwiftUI

struct CourseDetailView: View {
    let course: DemoCourse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.title).foregroundStyle(course.color.tint)
                        Text(course.title).font(.title.weight(.semibold))
                        Text("示例课程").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                Section("上课安排") {
                    LabeledContent("时间", value: "\(course.startTime)–\(course.endTime)")
                    LabeledContent("节次", value: "第 \(course.startPeriod)–\(course.endPeriod) 节")
                    LabeledContent("地点", value: course.room)
                    LabeledContent("教师", value: course.teacher)
                }
                Section {
                    Label("上课提醒尚未启用", systemImage: "bell.badge")
                } footer: {
                    Text("当前仅展示界面，不会发送通知。真实周次、调停课与提醒逻辑将在后续实现。")
                }
            }
            .navigationTitle("课程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
