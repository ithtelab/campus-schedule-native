import SwiftUI

/// 课程搜索。按名称、教师、教室查找，结果按课程聚合。
struct CourseSearchView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedVariant: CourseSearch.Variant?

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
                    List {
                        ForEach(hits) { hit in
                            Section {
                                ForEach(hit.variants) { variant in
                                    Button { selectedVariant = variant } label: { row(variant) }
                                        .buttonStyle(.plain)
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.title).font(.headline).foregroundStyle(.primary)
                                    let description = [hit.teacher, hit.room].filter { !$0.isEmpty }.joined(separator: " · ")
                                    if !description.isEmpty { Text(description).font(.caption) }
                                }
                            }
                        }
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
            .sheet(item: $selectedVariant) { variant in
                let termID = store.activeTermID
                if let course = store.course(withID: variant.id, in: termID) {
                    CourseDetailView(course: course, linkedTermID: termID)
                } else {
                    ContentUnavailableView("课程已更新", systemImage: "calendar.badge.exclamationmark")
                }
            }
        }
    }

    private func row(_ variant: CourseSearch.Variant) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(variant.slot).foregroundStyle(.primary)
            Text(variant.weeksText).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}
