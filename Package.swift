// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ScheduleCore", platforms: [.macOS(.v14)], products: [.library(name: "ScheduleCore", targets: ["ScheduleCore"])], targets: [
    .target(name: "ScheduleCore", path: "Shared", exclude: ["SystemSnapshot.swift", "WidgetContent.swift", "CampusIllustration.swift", "CourseLiveContent.swift", "CourseActivityIntents.swift"]),
    .testTarget(name: "ScheduleCoreTests", dependencies: ["ScheduleCore"], path: "Tests")
])
