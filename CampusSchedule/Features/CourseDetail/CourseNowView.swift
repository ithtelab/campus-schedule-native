import SwiftUI

/// System surfaces open this read-only view; editing remains in the app's course management flow.
struct CourseNowView: View {
    let course: DemoCourse
    var occurrenceID: String?
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var occurrence: CourseOccurrence? {
        CourseDeepLink.occurrence(for: .init(courseID: course.id, termID: store.activeTermID, occurrenceID: occurrenceID),
                                  in: store.occurrences, now: store.now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let item = occurrence {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let now = store.isPreview ? store.now : context.date
                            VStack(alignment: .leading, spacing: 20) {
                                Label(status(item, now: now), systemImage: item.end <= now ? "checkmark.circle" : "book.closed")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                                Text(item.title).font(.largeTitle.weight(.bold))
                                    .accessibilityIdentifier("course.now.title")
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(item.room.isEmpty ? "地点待确认" : item.room)
                                        .font(.title.weight(.semibold)).textSelection(.enabled)
                                    Text("\(ScheduleRules.time(item.start))–\(ScheduleRules.time(item.end))")
                                        .font(.title2.weight(.medium).monospacedDigit())
                                    Text(item.start, format: .dateTime.year().month().day().weekday(.wide))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                if item.start <= now && now < item.end {
                                    Text("还有 \(max(1, Int(ceil(item.end.timeIntervalSince(now) / 60)))) 分钟下课")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                } else if now < item.start && ScheduleRules.calendar.isDate(now, inSameDayAs: item.start) {
                                    Text("距离上课 \(max(1, Int(ceil(item.start.timeIntervalSince(now) / 60)))) 分钟")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if item.wasRescheduled {
                            Label("本次已调课，以上为最新时间和地点", systemImage: "calendar.badge.clock")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if !course.teacher.isEmpty {
                            Divider()
                            LabeledContent("任课教师", value: course.teacher).font(.subheadline)
                        }
                    } else {
                        ContentUnavailableView(occurrenceID == nil ? "暂无待上的安排" : "本次安排已更新",
                            systemImage: "calendar.badge.clock",
                            description: Text("请返回课表查看 \(course.title) 的最新安排。"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.background)
            .navigationTitle("本次课程").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .accessibilityIdentifier("course.now")
        }
        .presentationDetents([.large])
    }

    private func status(_ item: CourseOccurrence, now: Date) -> String {
        if now >= item.end { return "本次已结束" }
        if now >= item.start { return "正在上课" }
        return ScheduleRules.calendar.isDate(item.start, inSameDayAs: now) ? "即将上课" : "课程安排"
    }
}
