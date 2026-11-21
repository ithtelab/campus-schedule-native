import SwiftUI
import UniformTypeIdentifiers

struct CalendarExportView: View {
    @Environment(PreviewStore.self) private var store
    @State private var termID = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var includeCourses = true
    @State private var includeExams = true
    @State private var includeLocations = true
    @State private var document: CalendarExportDocument?
    @State private var presentingExporter = false
    @State private var exportError: String?

    private var term: TermSummary? { store.terms.first { $0.id == termID } }

    private var events: [CalendarExport.Event] {
        guard let content = store.termContents[termID], end >= start else { return [] }
        let calendar = ScheduleRules.calendar
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let courses = includeCourses ? store.occurrences(in: termID).map { course in
            CalendarExport.Event(id: "course:\(termID):\(course.id)", title: course.title, location: course.room,
                                 start: course.start, end: course.end)
        } : []
        let exams = includeExams ? content.exams.compactMap { exam -> CalendarExport.Event? in
            guard let session = ExamSession(exam: exam, termID: termID) else { return nil }
            return CalendarExport.Event(id: "exam:\(termID):\(session.id)", title: "考试 · \(session.title)",
                                        location: session.room, start: session.start, end: session.end)
        } : []
        return (courses + exams).filter { (first...last).contains(calendar.startOfDay(for: $0.start)) }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    var body: some View {
        Form {
            Section("选择范围") {
                Picker("学期", selection: $termID) {
                    ForEach(store.terms) { term in Text(term.name).tag(term.id) }
                }
                DatePicker("开始日期", selection: $start, displayedComponents: .date)
                DatePicker("结束日期", selection: $end, in: start..., displayedComponents: .date)
            }
            Section("导出内容") {
                Toggle("课程", isOn: $includeCourses)
                Toggle("考试", isOn: $includeExams)
                Toggle("包含教室与考场", isOn: $includeLocations)
            }
            Section {
                if events.isEmpty { Text("所选范围内没有可导出的安排").foregroundStyle(.secondary) }
                else {
                    Text("共 \(events.count) 项安排")
                    ForEach(events.prefix(3), id: \.id) { event in
                        LabeledContent(event.title) {
                            Text(event.start, format: .dateTime.month().day().hour().minute()).foregroundStyle(.secondary)
                        }
                    }
                    Button("导出日历文件", systemImage: "square.and.arrow.up") {
                        document = CalendarExportDocument(data: CalendarExport.data(events: events, includeLocations: includeLocations))
                        presentingExporter = true
                    }
                }
            } header: { Text("导出预览") }
            footer: { Text("将生成可导入系统日历的 .ics 文件。文件保存后可自行分享。") }
        }
        .navigationTitle("导出到日历")
        .environment(\.timeZone, ScheduleRules.calendar.timeZone)
        .onAppear { if termID.isEmpty { termID = store.activeTermID; updateDates() } }
        .onChange(of: termID) { _, _ in updateDates() }
        .onChange(of: start) { _, value in if end < value { end = value } }
        .fileExporter(isPresented: $presentingExporter, document: document,
                      contentType: CalendarExportDocument.type, defaultFilename: "课间册-\(term?.name ?? "日程").ics") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("导出失败", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    private func updateDates() {
        guard let term else { return }
        start = term.startDate
        end = ScheduleRules.calendar.startOfDay(for: term.endDate)
    }
}

private struct CalendarExportDocument: FileDocument {
    static let type = UTType(filenameExtension: "ics") ?? .plainText
    static var readableContentTypes: [UTType] { [type] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
