import Foundation

/// 归档格式与内部模型之间转换时用到的校验。
///
/// `PreviewStore` 里的转换需要接触 App 层的类型（`DemoCourse`、`CourseColor`），
/// 无法整体搬进 Shared；但其中的**判断规则**可以。集中在这里后，Store 只负责
/// 按结论写入状态，规则本身可以单独测试。
public enum ArchiveMapping {

    /// 把「第 n 节」映射为时间。节次编号不连续时返回 nil，而不是按下标猜。
    public static func time(period index: Int, in periods: [ArchivedPeriod], isStart: Bool) -> String? {
        guard let period = periods.first(where: { $0.index == index }) else { return nil }
        return isStart ? period.start : period.end
    }

    /// 节次编号是否从 1 连续，且数量在支持范围内。
    ///
    /// 网格靠下标定位，编号有空洞会让课程画到错误位置，因此宁可整体拒绝。
    public static func periodsAreContiguous(_ periods: [ArchivedPeriod], range: ClosedRange<Int>) -> Bool {
        let sorted = periods.map(\.index).sorted()
        // 空表直接拒绝：Array(1...0) 会因区间下界大于上界而崩溃。
        guard !sorted.isEmpty else { return false }
        return sorted == Array(1...sorted.count) && range.contains(sorted.count)
    }

    /// 收窄周数时裁剪课程周次，并移除裁空的课程。
    ///
    /// 返回 (保留的课程, 被移除的数量)。纯函数，便于验证「缩短学期后导出仍然合法」。
    public static func clampWeeks<T>(_ items: [T], totalWeeks: Int,
                                     weeksOf: (T) -> Set<Int>,
                                     apply: (T, Set<Int>) -> T) -> (kept: [T], removedCount: Int) {
        var kept: [T] = []
        var removed = 0
        for item in items {
            let clamped = weeksOf(item).filter { $0 >= 1 && $0 <= totalWeeks }
            if clamped.isEmpty { removed += 1; continue }
            kept.append(apply(item, clamped))
        }
        return (kept, removed)
    }
}
