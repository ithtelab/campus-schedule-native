import SwiftUI
import WebKit

/// 在 App 内登录教务系统并提取课表。
///
/// 流程：打开学校入口 → 用户自行登录 → 进入课表页 → 点「提取课表」。
/// 不保存密码，Cookie 只在本次会话的内存里。
struct AcademicLoginView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let school: SchoolEntry
    @State private var extractedHTML: String?
    @State private var isLoading = true
    @State private var lastError: String?
    @State private var plan: ImportPlanner.Plan?
    @State private var extracting = false
    /// 由 WebViewHost 在创建时回填，供提取按钮读取页面。
    @State private var webViewRef: WKWebView?

    var body: some View {
        NavigationStack {
            Group {
                if let url = URL(string: school.url), !school.url.isEmpty {
                    webContent(url)
                } else {
                    emptyAddressView
                }
            }
            .navigationTitle(school.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("提取课表") { extract() }
                        .disabled(isLoading || extracting)
                }
            }
            .sheet(item: $plan) { plan in
                ImportPreviewView(plan: plan) { confirmed in
                    store.applyImport(confirmed.courses)
                    self.plan = nil
                    dismiss()
                } onCancel: { self.plan = nil }
            }
            .alert("无法访问", isPresented: .init(
                get: { lastError != nil },
                set: { if !$0 { lastError = nil } }
            )) {
                Button("知道了", role: .cancel) { lastError = nil }
            } message: {
                Text(lastError ?? "")
            }
        }
    }

    private func webContent(_ url: URL) -> some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("正在加载…").frame(height: 2)
            }
            WebViewHost(url: url, webViewRef: $webViewRef,
                        isLoading: $isLoading, lastError: $lastError)
            instruction
        }
    }

    /// 告诉用户该做什么，而不是让他猜。
    private var instruction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("登录后进入「我的课表」页面，再点右上角「提取课表」", systemImage: "info.circle")
                .font(.footnote)
            Text("账密不会被保存，登录状态只在本次会话有效。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DesignSystem.paper)
    }

    private var emptyAddressView: some View {
        ContentUnavailableView {
            Label("缺少教务地址", systemImage: "link.badge.plus")
        } description: {
            Text("这所学校在目录里没有登记教务系统网址。请改用「粘贴」方式导入。")
        }
    }

    private func extract() {
        guard let webView = webViewRef else {
            lastError = "页面尚未加载完成。"
            return
        }
        extracting = true
        Task { @MainActor in
            defer { extracting = false }
            do {
                let html = try await WebContentCollector.collect(from: webView)
                extractedHTML = html
                try planFromHTML(html)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func planFromHTML(_ html: String) throws {
        // 1) 内嵌 JSON：正方、URP 等把课表放在脚本变量里，最可靠。
        for candidate in AcademicSystemProfile.embeddedJSON(from: html) {
            if let outcome = AcademicSystemProfile.courses(fromEmbeddedJSON: candidate,
                                                           totalWeeks: store.totalWeeks),
               !outcome.courses.isEmpty {
                finish(plan: makePlan(outcome))
                return
            }
        }

        // 2) 表格结构：绝大多数教务系统。
        let tables = HTMLTableExtractor.extractTables(from: html)
        var best: ParseOutcome?
        for table in tables {
            let outcome = TimetableTextParser.parseGrid(table, totalWeeks: store.totalWeeks)
            if outcome.courses.count > (best?.courses.count ?? 0) { best = outcome }
        }
        if let outcome = best, !outcome.courses.isEmpty {
            finish(plan: makePlan(outcome))
            return
        }

        // 3) 整页文本：纯 div 布局，靠每行的星期与节次识别。
        let textFallback = TimetableTextParser.parseLines(html, totalWeeks: store.totalWeeks)
        guard !textFallback.courses.isEmpty else {
            throw tables.isEmpty ? ImportFailure.noTable : ImportFailure.noCourses
        }
        finish(plan: makePlan(textFallback))
    }

    private func makePlan(_ outcome: ParseOutcome) -> ImportPlanner.Plan {
        let existing = store.courses.map {
            ParsedCourse(title: $0.title, teacher: $0.teacher, room: $0.room, weekday: $0.weekday,
                         startPeriod: $0.startPeriod, endPeriod: $0.endPeriod, weeks: $0.weeks)
        }
        return ImportPlanner.plan(outcome, existing: existing, totalWeeks: store.totalWeeks,
                            periodCount: store.periods.count)
    }

    private func finish(plan: ImportPlanner.Plan) {
        self.plan = plan
    }

    enum ImportFailure: LocalizedError {
        case noTable, noCourses

        var errorDescription: String? {
            switch self {
            case .noTable: "页面里没有找到表格。请确认已经进入课表页面，而不是登录页。"
            case .noCourses: "找到表格但没识别出课程。可以尝试在电脑上打开课表后复制内容，用「粘贴」导入。"
            }
        }
    }
}

/// 把 WKWebView 的引用透出给 SwiftUI，用于主动读取页面。
private struct WebViewHost: UIViewRepresentable {
    let url: URL
    @Binding var webViewRef: WKWebView?
    @Binding var isLoading: Bool
    @Binding var lastError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 内存级 Cookie：退出即失效，不在磁盘留下登录凭据。
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = WebContentCollector.desktopUserAgent
        webView.load(URLRequest(url: url))
        DispatchQueue.main.async { webViewRef = webView }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WebViewHost
        init(_ parent: WebViewHost) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            parent.isLoading = false
            parent.lastError = error.localizedDescription
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            parent.isLoading = false
            let code = (error as NSError).code
            parent.lastError = code == NSURLErrorNotConnectedToInternet
                ? "没有网络连接。"
                : code == NSURLErrorCannotFindHost
                    ? "找不到服务器，可能需要连接校园网。"
                    : error.localizedDescription
        }
    }
}
