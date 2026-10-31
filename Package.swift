// swift-tools-version: 6.0
import PackageDescription

// 学校目录既被 App 打包，也被单元测试读取；放到 target resources 里让两条路径共用同一份数据。
let package = Package(
    name: "ScheduleCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ScheduleCore", targets: ["ScheduleCore"])],
    targets: [
        .target(
            name: "ScheduleCore",
            path: "Shared",
            exclude: ["SystemSnapshot.swift", "WidgetContent.swift", "CampusIllustration.swift",
                      "CourseLiveContent.swift", "CourseActivityIntents.swift"],
            resources: [.copy("schools.json")]
        ),
        .testTarget(name: "ScheduleCoreTests", dependencies: ["ScheduleCore"], path: "Tests")
    ]
)
