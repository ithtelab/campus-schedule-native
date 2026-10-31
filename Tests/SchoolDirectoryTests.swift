import Foundation
import Testing
@testable import ScheduleCore

struct SchoolDirectoryTests {
    /// 与打包资源同构的最小目录：行内数值与字符串混排。
    let sample = """
    {"v":1,"profiles":["zhengfang","qiangzhi","topology"],
     "e":[["清华大学","https://jw.tsinghua.edu.cn",0,3],
          ["北京大学","https://dean.pku.edu.cn",0,2],
          ["某职业技术学院","http://jw.example.cn",1,1],
          ["通用导入","",2,0]]}
    """.data(using: .utf8)!

    @Test func decodesMixedTypes() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.schemaVersion == 1)
        #expect(directory.count == 4)
    }

    @Test func mapsProfileIndexToSystem() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.entries[0].system == .zhengfang)
        #expect(directory.entries[2].system == .qiangzhi)
        #expect(directory.entries[3].system == .topology)
    }

    @Test func keepsConfidence() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.entries[0].confidence == 3)
        #expect(directory.entries[0].confidenceText == "已验证")
        #expect(directory.entries[2].confidenceText == "实验性")
        #expect(directory.entries[3].confidenceText == "需适配")
    }

    @Test func unknownProfileIndexBecomesNilSystem() throws {
        let data = #"{"v":1,"profiles":[],"e":[["学校","http://x.cn",5,2]]}"#.data(using: .utf8)!
        let directory = try SchoolDirectory.decode(data)
        #expect(directory.entries[0].system == nil)
    }

    @Test func rejectsMalformedRow() {
        let data = #"{"v":1,"profiles":[],"e":[["学校","http://x.cn"]]}"#.data(using: .utf8)!
        #expect(throws: SchoolDirectory.DirectoryError.self) { try SchoolDirectory.decode(data) }
    }

    @Test func rejectsTruncatedJSON() {
        let data = Data(#"{"v":1,"profiles":["#.utf8)
        #expect(throws: (any Error).self) { try SchoolDirectory.decode(data) }
    }

    @Test func searchMatchesName() throws {
        let directory = try SchoolDirectory.decode(sample)
        let results = directory.search("清华")
        #expect(results.count == 1)
        #expect(results[0].name == "清华大学")
    }

    @Test func searchMatchesURL() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.search("pku").first?.name == "北京大学")
    }

    @Test func searchMatchesSystemName() throws {
        let directory = try SchoolDirectory.decode(sample)
        let results = directory.search("强智")
        #expect(results.contains { $0.name == "某职业技术学院" })
    }

    @Test func searchIsCaseInsensitive() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.search("PKU").count == 1)
    }

    @Test func emptyQueryReturnsHighestConfidenceFirst() throws {
        let directory = try SchoolDirectory.decode(sample)
        let results = directory.search("")
        #expect(results.first?.confidence == 3)
        // 结果按置信度降序。
        #expect(results.map(\.confidence) == results.map(\.confidence).sorted(by: >))
    }

    @Test func emptyQueryRespectsLimit() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.search("", limit: 2).count == 2)
    }

    @Test func searchRespectsLimit() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.search("大学", limit: 1).count == 1)
    }

    @Test func noMatchesReturnsEmpty() throws {
        let directory = try SchoolDirectory.decode(sample)
        #expect(directory.search("不存在的学校").isEmpty)
    }

    @Test func summaryCountsByConfidence() throws {
        let directory = try SchoolDirectory.decode(sample)
        let summary = directory.summary
        #expect(summary.verified == 1)
        #expect(summary.usable == 1)
        #expect(summary.experimental == 1)
        #expect(summary.needsAdapter == 1)
    }

    // MARK: 系统枚举

    @Test func everySystemHasAProfileKey() {
        for system in AcademicSystem.allCases {
            #expect(AcademicSystem(profileKey: system.profileKey) == system)
        }
    }

    @Test func allSystemsHaveDisplayNames() {
        for system in AcademicSystem.allCases {
            #expect(!system.displayName.isEmpty)
        }
    }

    @Test func dedicatedParserFlagsAreExplicit() {
        #expect(AcademicSystem.zhengfang.hasDedicatedParser)
        #expect(AcademicSystem.qiangzhi.hasDedicatedParser)
        #expect(!AcademicSystem.topology.hasDedicatedParser)
    }

    // MARK: 打包资源

    @Test func bundledDirectoryLoadsAndCoversManySchools() throws {
        // 资源缺失会让导入功能整体不可用，因此必须验证打包数据本身可解析。
        let url = try #require(SchoolDirectory.bundleURLForTesting(),
                               "schools.json 未打包进测试目标")
        let directory = try SchoolDirectory.decode(Data(contentsOf: url))
        #expect(directory.count > 2500)
        #expect(directory.summary.verified > 0)
        #expect(directory.entries.allSatisfy { !$0.name.isEmpty })
    }
}

extension SchoolDirectory {
    /// 包内资源定位。测试与 App 使用同一份数据。
    static func bundleURLForTesting() -> URL? {
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: "schools", withExtension: "json")
        #else
        return Bundle.main.url(forResource: "schools", withExtension: "json")
        #endif
    }
}
