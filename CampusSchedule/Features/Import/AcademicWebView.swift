import Foundation
import WebKit

/// 从 WebView 读取 HTML 的辅助。使用 `evaluateJavaScript` 只读取，不修改页面。
enum WebContentCollector {
    /// 读取整页 HTML。先滚动到底再读，确保懒加载的表格行都已渲染。
    static func collect(from webView: WKWebView) async throws -> String {
        // 逐步滚动触发懒加载，然后回到顶部。
        _ = try? await webView.evaluateJavaScript(
            """
            (async () => {
              const step = Math.max(200, window.innerHeight);
              for (let y = 0; y < document.body.scrollHeight; y += step) {
                window.scrollTo(0, y);
                await new Promise(r => setTimeout(r, 60));
              }
              window.scrollTo(0, 0);
              return true;
            })()
            """
        )
        guard let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String,
              !html.isEmpty else {
            throw CollectError.emptyDocument
        }
        return html
    }

    /// 教务系统通用的桌面版 UA：移动版页面常把课表裁成单日视图。
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    enum CollectError: LocalizedError {
        case emptyDocument

        var errorDescription: String? {
            switch self {
            case .emptyDocument: "页面内容为空，请等待加载完成或重新登录。"
            }
        }
    }
}
