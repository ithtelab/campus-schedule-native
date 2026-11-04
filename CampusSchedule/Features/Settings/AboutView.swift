import SwiftUI

struct AboutView: View {
    static let privacyURL = URL(string: "https://github.com/ithtelab/campus-schedule-native/blob/master/PRIVACY.md")!
    private let supportURL = URL(string: "https://github.com/ithtelab/campus-schedule-native/issues")!
    private let licenseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private var version: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version)（\(build)）"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 29, weight: .medium))
                        .frame(width: 64, height: 64)
                        .background(DesignSystem.surface, in: .rect(cornerRadius: 17))
                        .accessibilityHidden(true)
                    Text("课间册").font(.title2.bold())
                    Text("版本 \(version)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            Section("隐私与条款") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("隐私政策", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("about.privacy")
                Link(destination: licenseURL) { Label("Apple 标准使用条款", systemImage: "doc.text") }
            }
            Section("帮助") {
                Link(destination: supportURL) { Label("支持与反馈", systemImage: "questionmark.circle") }
            }
        }
        .navigationTitle("关于课间册")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPolicyView: View {
    private var blocks: [String] {
        guard let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("# ") }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, paragraph in
                    if paragraph.hasPrefix("## ") {
                        Text(paragraph.dropFirst(3)).font(.headline).accessibilityAddTraits(.isHeader)
                    } else {
                        Text(LocalizedStringKey(paragraph)).font(.body)
                    }
                }
                Link("在浏览器中查看隐私政策", destination: AboutView.privacyURL)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}
