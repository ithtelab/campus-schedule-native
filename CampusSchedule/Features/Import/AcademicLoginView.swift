import SwiftUI
import WebKit

/// 在 App 内登录教务系统并提取课表。
///
/// 流程：打开学校入口 → 用户自行登录 → 进入课表页 → 点「提取课表」。
/// WebView 默认使用临时会话。仅在用户选择自动检查时提取当前课表页所需的 Cookie。
struct AcademicLoginView: View {
    @Environment(PreviewStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let school: SchoolEntry
    @State private var isLoading = true
    @State private var hasLoadedPage = false
    @State private var loadError: String?
    @State private var lastError: String?
    @State private var plan: ImportPlanner.Plan?
    @State private var extracting = false
    @State private var numbering: AcademicSystemProfile.WeekdayNumbering = .automatic
    @State private var enablesRefresh = false
    @State private var refreshCandidate: RefreshCandidate?
    /// 由 WebViewHost 在创建时回填，供提取按钮读取页面。
    @State private var webViewRef: WKWebView?

    private struct RefreshCandidate {
        let scope: AcademicRefreshScope
        let cookies: [AcademicRefreshCookie]
        let baseline: Set<ParsedCourse>
        let numbering: AcademicSystemProfile.WeekdayNumbering
    }

    private var refreshScope: AcademicRefreshScope? {
        guard !store.isPreview, let entrance = URL(string: school.url), let page = webViewRef?.url else { return nil }
        return AcademicRefreshScope(entrance: entrance, page: page)
    }

    var body: some View {
        NavigationStack {
            Group {
                if school.hasWebEntrance, let url = URL(string: school.url) {
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
                        .disabled(isLoading || extracting || !hasLoadedPage)
                }
                ToolbarItem(placement: .bottomBar) {
                    Menu {
                        Picker("星期格式", selection: $numbering) {
                            ForEach(AcademicSystemProfile.WeekdayNumbering.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    } label: { Label("星期格式", systemImage: "calendar") }
                }
            }
            .sheet(item: $plan) { plan in
                ImportPreviewView(plan: plan) { confirmed in
                    guard store.applyImport(confirmed) > 0 else { return false }
                    if let candidate = refreshCandidate {
                        let term = store.semesterName
                        let totalWeeks = store.totalWeeks
                        Task {
                            await AcademicRefreshService.shared.connect(school: school.name, term: term, scope: candidate.scope,
                                totalWeeks: totalWeeks, numbering: candidate.numbering, cookies: candidate.cookies,
                                baseline: candidate.baseline)
                        }
                    }
                    self.plan = nil
                    dismiss()
                    return true
                } onCancel: { self.plan = nil; refreshCandidate = nil }
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
            ZStack {
                WebViewHost(url: url, webViewRef: $webViewRef,
                            isLoading: $isLoading, hasLoadedPage: $hasLoadedPage,
                            loadError: $loadError)
                    .opacity(loadError == nil ? 1 : 0)
                if let loadError {
                    ContentUnavailableView {
                        Label("教务页面未能打开", systemImage: "network.slash")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("重新加载") {
                            self.loadError = nil
                            isLoading = true
                            hasLoadedPage = false
                            webViewRef?.load(URLRequest(url: webViewRef?.url ?? url))
                        }
                    }
                }
            }
            instruction
        }
    }

    /// 告诉用户该做什么，而不是让他猜。
    private var instruction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("登录后进入「我的课表」页面，再点右上角「提取课表」", systemImage: "info.circle")
                .font(.footnote)
            if hasLoadedPage, refreshScope != nil {
                Toggle("导入后自动检查变更", isOn: $enablesRefresh)
                    .font(.footnote).tint(DesignSystem.switchTint)
                if enablesRefresh {
                    Text("课表页的登录会话只存本机钥匙串，最多复用 7 天。通过读取验证后启用，并替换本机已保存的教务连接。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else if hasLoadedPage && !store.isPreview {
                Text("自动检查需要同一教务站点的 HTTPS 课表页。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text("密码不会保存。")
                .font(.caption2).foregroundStyle(.secondary)
            if (webViewRef?.url ?? URL(string: school.url))?.scheme == "http" {
                Text("学校页面使用 HTTP 连接，请在可信网络下登录。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
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
        refreshCandidate = nil
        let wantsRefresh = enablesRefresh
        let scope = refreshScope
        let selectedNumbering = numbering
        Task { @MainActor in
            defer { extracting = false }
            do {
                let html = try await WebContentCollector.collect(from: webView)
                let outcome = AcademicSystemProfile.parsePage(html, totalWeeks: store.totalWeeks, numbering: selectedNumbering)
                guard !outcome.courses.isEmpty else {
                    throw NSError(domain: "AcademicImport", code: 1, userInfo: [NSLocalizedDescriptionKey: outcome.warnings.first ?? ImportFailure.noCourses.localizedDescription])
                }
                var proposal = store.makeImportPlan(outcome)
                if wantsRefresh, let scope, scope == refreshScope, proposal.warnings.isEmpty {
                    let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
                    if scope == refreshScope {
                        let now = Date()
                        let scopedCookies = cookies.map {
                            AcademicRefreshCookie(name: $0.name, value: $0.value, domain: $0.domain, path: $0.path, expires: $0.expiresDate)
                        }.filter { $0.isUsable(in: scope, now: now) }
                        if !scopedCookies.isEmpty {
                            refreshCandidate = RefreshCandidate(scope: scope, cookies: scopedCookies,
                                baseline: Set(outcome.courses), numbering: selectedNumbering)
                        }
                    }
                }
                if wantsRefresh && refreshCandidate == nil {
                    proposal.warnings.append("该页无法建立自动检查，仍可手动导入。")
                }
                plan = proposal
            } catch {
                lastError = error.localizedDescription
            }
        }
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
    @Binding var hasLoadedPage: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 不使用全局 WebKit Cookie；后台检查只使用用户授权导入时提取的会话。
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = WebContentCollector.desktopUserAgent
        webView.load(URLRequest(url: url))
        DispatchQueue.main.async { webViewRef = webView }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let parent: WebViewHost
        init(_ parent: WebViewHost) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.hasLoadedPage = false
            parent.loadError = nil
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.hasLoadedPage = true
            parent.loadError = nil
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            fail(error)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            fail(error)
        }

        private func fail(_ error: any Error) {
            let failure = error as NSError
            // 登录跳转取消旧导航是正常行为，不把新页面盖成错误页。
            if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return }
            parent.isLoading = false
            parent.hasLoadedPage = false
            switch failure.domain == NSURLErrorDomain ? failure.code : 0 {
            case NSURLErrorNotConnectedToInternet:
                parent.loadError = "没有网络连接，请联网后重试。"
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
                parent.loadError = "暂时无法连接学校教务系统，可能需要校园网或学校官方 VPN。"
            case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                parent.loadError = "学校页面的连接被系统安全策略拦截，请更新 App 后重试。"
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                parent.loadError = "学校网站的安全连接验证失败，请联系学校确认入口或稍后重试。"
            default:
                parent.loadError = "教务页面加载失败，请重新加载后重试。"
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // target=_blank 的教务入口在当前会话打开，保留内存 Cookie。
            if navigationAction.targetFrame == nil,
               let scheme = navigationAction.request.url?.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.isLoading = false
            parent.hasLoadedPage = false
            parent.loadError = "页面进程已结束，请重新加载。"
        }
    }
}
