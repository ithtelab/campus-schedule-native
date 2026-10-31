import SwiftUI
import CoreFoundation

/// 教务课表导入。三条路径：搜索学校、粘贴文本、选择文件。
///
/// 无论走哪条，最终都落到同一个「解析 → 预览 → 确认」流程，
/// 因此在真正写入前，用户总能看到将要导入什么。
struct ImportView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var directory: SchoolDirectory?
    @State private var directoryError: String?
    @State private var pastedText = ""
    @State private var showingPaste = false
    @State private var showingFile = false
    @State private var outcome: ParseOutcome?
    @State private var plan: ImportPlanner.Plan?
    @State private var mode: Mode = .school

    enum Mode: String, CaseIterable, Identifiable {
        case school = "学校"
        case paste = "粘贴"
        case file = "文件"
        var id: String { rawValue }
    }

    private var results: [SchoolEntry] { directory?.search(query) ?? [] }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .school: schoolList
                case .paste: pasteView
                case .file: fileView
                }
            }
            .navigationTitle("导入课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    Picker("方式", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
            }
            .sheet(item: $plan) { plan in
                ImportPreviewView(plan: plan) { finalPlan in
                    apply(finalPlan)
                } onCancel: { self.plan = nil }
            }
            .task { loadDirectory() }
        }
    }

    // MARK: 学校

    private var schoolList: some View {
        List {
            if let error = directoryError {
                Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
            if let directory, query.isEmpty {
                Section {
                    let summary = directory.summary
                    LabeledContent("收录学校", value: "\(directory.count) 所")
                    LabeledContent("已验证", value: "\(summary.verified) 所")
                    LabeledContent("可用", value: "\(summary.usable) 所")
                } header: { Text("目录") }
                footer: { Text("目录不含登录状态，仅提供各校教务入口。导入需要你自己粘贴或上传课表内容。") }
            }
            Section {
                ForEach(results) { entry in
                    row(entry)
                }
            } header: {
                if !query.isEmpty { Text("\(results.count) 个结果") }
            }
        }
        .searchable(text: $query, prompt: "搜索学校名称或教务地址")
    }

    private func row(_ entry: SchoolEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.name)
            HStack(spacing: 6) {
                if let system = entry.system {
                    Text(system.displayName).font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(DesignSystem.accent.opacity(0.12), in: Capsule())
                }
                Text(entry.confidenceText).font(.caption2).foregroundStyle(.secondary)
            }
            if !entry.url.isEmpty {
                Text(entry.url).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIPasteboard.general.string = entry.url
            mode = .paste
        }
    }

    // MARK: 粘贴

    private var pasteView: some View {
        List {
            Section {
                TextEditor(text: $pastedText)
                    .frame(minHeight: 220)
                    .font(.callout)
                    .overlay(alignment: .topLeading) {
                        if pastedText.isEmpty {
                            Text("把教务系统的课表页面全选复制后粘贴到这里")
                                .foregroundStyle(.tertiary).allowsHitTesting(false).padding(.top, 8).padding(.leading, 4)
                        }
                    }
            } header: { Text("课表内容") }
            footer: { Text("支持表格式课表与逐行文本。需要包含星期与节次，例如「周一 第1-2节 高等数学」。") }

            Section {
                Button("从剪贴板粘贴", systemImage: "doc.on.clipboard") {
                    pastedText = UIPasteboard.general.string ?? pastedText
                }
                Button("解析并预览", systemImage: "wand.and.stars") { parsePasted() }
                    .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: 文件

    private var fileView: some View {
        List {
            Section {
                Button("选择文件", systemImage: "folder") { showingFile = true }
            } header: { Text("从文件导入") }
            footer: { Text("支持从教务系统导出的 HTML、纯文本，或本 App 的备份 JSON。") }
            if !pastedText.isEmpty {
                Section("已读取") {
                    Text(pastedText.prefix(200)).font(.caption).foregroundStyle(.secondary)
                    Button("解析并预览", systemImage: "wand.and.stars") { parsePasted() }
                }
            }
        }
        .fileImporter(isPresented: $showingFile, allowedContentTypes: [.plainText, .html, .json, .text]) { result in
            readFile(result)
        }
    }

    // MARK: 动作

    private func loadDirectory() {
        guard directory == nil else { return }
        guard let url = Bundle.main.url(forResource: "schools", withExtension: "json") else {
            directoryError = "学校目录文件缺失，请重新安装 App。"
            return
        }
        do {
            directory = try SchoolDirectory.decode(Data(contentsOf: url))
        } catch {
            directoryError = error.localizedDescription
        }
    }

    private func readFile(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            // 国内教务系统常导出 GB18030，按 UTF-8 失败后尝试它，最后退回 Latin-1 保证能读。
            let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: gb18030)
                    ?? String(data: data, encoding: .isoLatin1) else {
                store.errorMessage = "无法读取文件内容，请另存为 UTF-8 后重试。"
                return
            }
            pastedText = text
            // 文件读取后直接进入解析，省一次点击。
            parsePasted()
        } catch {
            store.errorMessage = "读取文件失败：\(error.localizedDescription)"
        }
    }

    private func parsePasted() {
        let text = pastedText
        // 先试分享码：结构化 JSON 比文本启发式可靠，也用不上字体与排版。
        let parsed: ParseOutcome
        if let share = ShareCodeParser.parse(text, totalWeeks: store.totalWeeks) {
            parsed = share
        } else {
            // 再按自由文本尝试：教务系统整页复制通常是每行一节课。
            let lineOutcome = TimetableTextParser.parseLines(text, totalWeeks: store.totalWeeks)
            parsed = lineOutcome.courses.isEmpty ? parseAsTable(text) : lineOutcome
        }
        guard !parsed.courses.isEmpty else {
            store.errorMessage = parsed.warnings.first ?? "没有识别到课程。"
            return
        }
        outcome = parsed
        let existing = store.courses.map {
            ParsedCourse(title: $0.title, teacher: $0.teacher, room: $0.room, weekday: $0.weekday,
                         startPeriod: $0.startPeriod, endPeriod: $0.endPeriod, weeks: $0.weeks)
        }
        plan = ImportPlanner.plan(parsed, existing: existing, totalWeeks: store.totalWeeks)
    }

    /// 把整段文本按行切成网格再解析，用于 HTML 转文本后仍保留行列结构的页面。
    private func parseAsTable(_ text: String) -> ParseOutcome {
        let rows = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { line -> [String] in
                // 制表符与连续空格都视作列分隔。
                line.split(whereSeparator: { $0 == "\t" }).map { $0.trimmingCharacters(in: .whitespaces) }
            }
            .filter { $0.count > 1 }
        return TimetableGridBudget.parse(rows: rows, totalWeeks: store.totalWeeks)
    }

    private func apply(_ plan: ImportPlanner.Plan) {
        store.applyImport(plan.courses)
        self.plan = nil
        dismiss()
    }
}

/// 网格解析的轻量封装，避免视图里出现循环细节。
enum TimetableGridBudget {
    static func parse(rows: [[String]], totalWeeks: Int) -> ParseOutcome {
        TimetableTextParser.parseGrid(rows, totalWeeks: totalWeeks)
    }
}

extension ImportPlanner.Plan: Identifiable {
    public var id: String { "\(courses.count)-\(conflicts.count)-\(courses.first?.title ?? "")" }
}
