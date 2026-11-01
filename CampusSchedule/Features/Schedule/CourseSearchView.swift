import SwiftUI

/// 课程搜索。按名称、教师、教室查找，结果按课程聚合。
struct CourseSearchView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedHit: CourseSearch.Hit?

    private var searchable: [SearchableCourse] {
        store.courses.map {
            SearchableCourse(id: $0.id, title: $0.title, teacher: $0.teacher, room: $0.room,
                             weekday: $0.weekday, startPeriod: $0.startPeriod,
                             endPeriod: $0.endPeriod, weeks: $0.weeks)
        }
    }

    private var hits: [CourseSearch.Hit] {
        CourseSearch.search(searchable, query: query, totalWeeks: store.totalWeeks)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.courses.isEmpty {
                    ContentUnavailableView("这个学期还没有课程", systemImage: "magnifyingglass")
                } else if hits.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(hits) { hit in
                        Button { selectedHit = hit } label: { row(hit) }
                            .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索课程")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "课程名、教师或教室")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .sheet(item: $selectedHit) { hit in
                if let course = store.courses.first(where: { $0.id == hit.courseID }) {
                    CourseDetailView(course: course)
                }
            }
        }
    }

    private func row(_ hit: CourseSearch.Hit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(hit.title).font(.body.weight(.medium)).lineLimit(1)
                Spacer(minLength: 0)
                Text(hit.weeksText).font(.caption2).foregroundStyle(.secondary)
            }
            if !hit.teacher.isEmpty {
                Text(hit.teacher).font(.caption).foregroundStyle(.secondary)
            }
            // 同一门课可能在不同天上课，全部列出。
            Text(hit.slots.joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            if !hit.room.isEmpty {
                Text(hit.room).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
