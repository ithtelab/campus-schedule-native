import SwiftUI

struct CourseLiveGallery: View {
    private let start = Date().addingTimeInterval(600)
    private var end: Date { start.addingTimeInterval(5700) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("复用真实扩展内容 · 非系统锁屏截图").font(.caption).foregroundStyle(.secondary)
                    Text("锁屏内容 · 课程名称优先").font(.headline)
                    card(title: "大学英语", room: "B楼 508")
                    Text("长课程名与教室").font(.headline)
                    card(title: "大学英语视听说与学术交流", room: "第二教学楼北区 1205")
                    Text("灵动岛紧凑区域 · 结束时刻").font(.headline)
                    HStack {
                        CampusBookMark().stroke(.white, lineWidth: 1.5).frame(width: 14, height: 17)
                        Spacer().frame(width: 76)
                        Text(CourseLivePlan.compactTime(end: end)).font(.system(size: 11, weight: .semibold).monospacedDigit()).frame(width: 36)
                    }.padding(10).foregroundStyle(.white).background(.black, in: Capsule())
                    Text("灵动岛展开内容").font(.headline)
                    CourseIslandExpanded(title: "大学英语", room: "B楼 508", start: start, end: end, nextTitle: "高等数学", nextRoom: "A楼 302")
                        .padding(14).background(.black, in: RoundedRectangle(cornerRadius: 20)).environment(\.colorScheme, .dark)
                }.padding(20)
            }
            .navigationTitle("实时活动布局验证").navigationBarTitleDisplayMode(.inline)
            .task { await verifyLayout() }
        }
    }
    private func card(title: String, room: String) -> some View {
        CourseLiveCard(title: title, room: room, start: start, end: end, nextRoom: "A楼 302")
            .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 24)).environment(\.colorScheme, .dark)
    }
    @MainActor private func verifyLayout() async {
        var results: [String] = []
        for size in [DynamicTypeSize.large, .accessibility1] {
            let view = CourseLiveCard(title: "大学英语视听说与学术交流", room: "第二教学楼北区 1205", start: start, end: end)
                .environment(\.dynamicTypeSize, size)
            let host = UIHostingController(rootView: view)
            let measured = host.sizeThatFits(in: CGSize(width: 292, height: 1000))
            results.append(measured.height <= 154 ? "PASS: live content height \(measured.height) at \(size)" : "FAIL: live content height \(measured.height) at \(size)")
        }
        try? results.joined(separator: "\n").write(to: URL.documentsDirectory.appendingPathComponent("live-layout-smoke.txt"), atomically: true, encoding: .utf8)
    }
}
