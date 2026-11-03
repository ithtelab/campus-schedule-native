import Foundation
import WebKit

/// 从 WebView 读取 HTML 的辅助。使用 `evaluateJavaScript` 只读取，不修改页面。
///
/// 标记为 `@MainActor`：`WKWebView` 只能在主线程访问，返回值也不该跨隔离域传递。
@MainActor
enum WebContentCollector {
    /// 读取当前页面和已加载的同源 frame；不绕过跨域访问限制。
    static func collect(from webView: WKWebView) async throws -> String {
        let html: String = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript("""
                (function () {
                  var queue = [document], seen = [], pages = [], size = 0;
                  while (queue.length && seen.length < 32) {
                    var doc = queue.shift();
                    if (!doc || seen.indexOf(doc) >= 0) continue;
                    seen.push(doc);
                    if (doc.documentElement) {
                      var html = doc.documentElement.outerHTML;
                      size += html.length;
                      if (size > 4 * 1024 * 1024) throw new Error('页面内容过大，请切到单独的课表页后重试。');
                      pages.push(html);
                    }
                    var frames = doc.querySelectorAll('iframe, frame');
                    for (var i = 0; i < frames.length && queue.length < 32; i++) {
                      try { if (frames[i].contentDocument) queue.push(frames[i].contentDocument); }
                      catch (_) { /* 跨域 frame 由浏览器保护，不读取。 */ }
                    }
                  }
                  return pages.join('\\n');
                })()
                """) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let text = result as? String, !text.isEmpty {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: CollectError.emptyDocument)
                }
            }
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
