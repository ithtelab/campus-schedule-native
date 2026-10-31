import Foundation

/// 教务系统的类型。用于决定用哪个解析器，也用于向用户说明兼容程度。
public enum AcademicSystem: String, Codable, Sendable, CaseIterable {
    case zhengfang, qiangzhi, kingosoftNew, kingosoftSelected, wisedu, southSoft
    case chaoxing, chaoxingShare, chengfang, shuwei, shuweiEasy, shuweiMobile, shuweiNew
    case urp, urpNew, xbell, umooc, yilian, aic, vatuu, eams, topology

    public var displayName: String {
        switch self {
        case .zhengfang: "正方教务"
        case .qiangzhi: "强智教务"
        case .kingosoftNew, .kingosoftSelected: "金智教务"
        case .wisedu: "智慧树 / 今日校园"
        case .southSoft: "南软教务"
        case .chaoxing: "超星教务"
        case .chaoxingShare: "超星分享课表"
        case .chengfang: "程方教务"
        case .shuwei, .shuweiEasy, .shuweiMobile, .shuweiNew: "树维教务"
        case .urp, .urpNew: "URP 教务"
        case .xbell: "凌展教务"
        case .umooc: "优慕课"
        case .yilian: "亿联教务"
        case .aic: "AIC 教务"
        case .vatuu: "Vatuu 教务"
        case .eams: "EAMS 教务"
        case .topology: "通用教务"
        }
    }

    /// 目录里的原始 profile 字符串。
    public var profileKey: String {
        switch self {
        case .zhengfang: "zhengfang"
        case .qiangzhi: "qiangzhi"
        case .kingosoftNew: "kingosoft_new"
        case .kingosoftSelected: "kingosoft_selected"
        case .wisedu: "wisedu"
        case .southSoft: "south_soft"
        case .chaoxing: "chaoxing"
        case .chaoxingShare: "chaoxing_share"
        case .chengfang: "chengfang"
        case .shuwei: "shuwei"
        case .shuweiEasy: "shuwei_easy"
        case .shuweiMobile: "shuwei_mobile"
        case .shuweiNew: "shuwei_new"
        case .urp: "urp"
        case .urpNew: "urp_new"
        case .xbell: "xbell"
        case .umooc: "umooc"
        case .yilian: "yilian"
        case .aic: "aic"
        case .vatuu: "vatuu"
        case .eams: "eams"
        case .topology: "topology"
        }
    }

    public init?(profileKey: String) {
        guard let match = Self.allCases.first(where: { $0.profileKey == profileKey }) else { return nil }
        self = match
    }

    /// 是否已有专用解析器；其余走通用结构解析。
    public var hasDedicatedParser: Bool {
        switch self {
        case .zhengfang, .qiangzhi, .kingosoftNew, .kingosoftSelected, .wisedu,
             .southSoft, .chaoxing, .chaoxingShare, .chengfang,
             .shuwei, .shuweiEasy, .shuweiMobile, .shuweiNew,
             .urp, .urpNew, .xbell, .umooc, .yilian, .aic, .vatuu, .eams:
            true
        case .topology:
            false
        }
    }
}

/// 目录中的一所学校。
public struct SchoolEntry: Sendable, Identifiable, Equatable {
    public var id: String { name + "|" + url }
    public var name: String
    public var url: String
    public var system: AcademicSystem?
    /// 目录提供的兼容性标注。
    public var confidence: Int

    public init(name: String, url: String, system: AcademicSystem?, confidence: Int) {
        self.name = name
        self.url = url
        self.system = system
        self.confidence = confidence
    }

    public var confidenceText: String {
        switch confidence {
        case 3: "已验证"
        case 2: "可用"
        case 1: "实验性"
        default: "需适配"
        }
    }
}

/// 学校目录。数据来自 wakeup 开放目录（MIT），只读且有版本号。
public struct SchoolDirectory: Sendable {
    public private(set) var entries: [SchoolEntry]
    public private(set) var schemaVersion: Int

    public init(entries: [SchoolEntry], schemaVersion: Int = 1) {
        self.entries = entries
        self.schemaVersion = schemaVersion
    }

    public var count: Int { entries.count }

    /// 紧凑的目录编码，字段名压到最短以控制包体。
    ///
    /// 每行是 `[名称, URL, profile 索引, 置信度]`，后两项是数字而前两项是字符串，
    /// 因此元素用自适应类型读取，而不是假定全为字符串。
    private struct Stored: Decodable {
        let v: Int
        let profiles: [String]
        let e: [[Scalar]]

        enum Scalar: Decodable {
            case text(String)
            case number(Int)

            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(Int.self) { self = .number(value); return }
                if let value = try? container.decode(String.self) { self = .text(value); return }
                throw DecodingError.typeMismatch(
                    Scalar.self, .init(codingPath: decoder.codingPath, debugDescription: "目录字段既不是字符串也不是整数")
                )
            }

            var intValue: Int? { if case .number(let value) = self { value } else { nil } }
            var stringValue: String? { if case .text(let value) = self { value } else { nil } }
        }
    }

    /// 从打包资源解析。任何结构问题都明确失败，不产出半个目录。
    public static func decode(_ data: Data) throws -> SchoolDirectory {
        let stored = try JSONDecoder().decode(Stored.self, from: data)
        var entries: [SchoolEntry] = []
        entries.reserveCapacity(stored.e.count)
        for row in stored.e {
            let name = row.count > 0 ? (row[0].stringValue ?? "") : ""
            guard row.count >= 4,
                  let url = row[1].stringValue,
                  let index = row[2].intValue,
                  let confidence = row[3].intValue else {
                throw DirectoryError.malformedRow(name)
            }
            let key = index >= 0 && index < stored.profiles.count ? stored.profiles[index] : ""
            entries.append(SchoolEntry(name: name, url: url,
                                       system: AcademicSystem(profileKey: key),
                                       confidence: confidence))
        }
        return SchoolDirectory(entries: entries, schemaVersion: stored.v)
    }

    public enum DirectoryError: LocalizedError {
        case malformedRow(String)

        public var errorDescription: String? {
            switch self {
            case .malformedRow(let name): "学校目录数据损坏（\(name)）。请重新安装 App。"
            }
        }
    }

    /// 按名称搜索。空白查询返回全部，供界面逐步加载。
    public func search(_ query: String, limit: Int = 60) -> [SchoolEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // 空查询给出置信度最高的若干所，而不是全部 2862 条。
            return Array(entries.sorted(by: Self.byConfidence).prefix(limit))
        }
        let matches = entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(trimmed)
                || entry.url.localizedCaseInsensitiveContains(trimmed)
                || (entry.system?.displayName.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
        return Array(matches.sorted(by: Self.byConfidence).prefix(limit))
    }

    /// 置信度高优先；同级按名称排序，保证结果稳定。
    private static func byConfidence(_ lhs: SchoolEntry, _ rhs: SchoolEntry) -> Bool {
        if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
        return lhs.name < rhs.name
    }

    /// 目录覆盖统计，用于向用户说明兼容情况。
    public var summary: (verified: Int, usable: Int, experimental: Int, needsAdapter: Int) {
        var result = (verified: 0, usable: 0, experimental: 0, needsAdapter: 0)
        for entry in entries {
            switch entry.confidence {
            case 3: result.verified += 1
            case 2: result.usable += 1
            case 1: result.experimental += 1
            default: result.needsAdapter += 1
            }
        }
        return result
    }
}
