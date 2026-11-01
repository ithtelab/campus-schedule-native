import Foundation
import Testing
@testable import ScheduleCore

struct ArchiveMappingTests {

    func periods(_ indices: [Int]) -> [ArchivedPeriod] {
        indices.map { ArchivedPeriod(index: $0, start: "08:00", end: "08:45") }
    }

    // MARK: 节次连续性

    @Test func acceptsContiguousFromOne() {
        #expect(ArchiveMapping.periodsAreContiguous(periods([1, 2, 3, 4]), range: 1...20))
        #expect(ArchiveMapping.periodsAreContiguous(periods([1, 2, 3, 4, 5, 6, 7, 8]), range: 1...20))
    }

    @Test func rejectsGapInNumbering() {
        // 缺第 3 节：网格按下标定位会画错位置。
        #expect(!ArchiveMapping.periodsAreContiguous(periods([1, 2, 4, 5]), range: 1...20))
    }

    @Test func rejectsNotStartingAtOne() {
        #expect(!ArchiveMapping.periodsAreContiguous(periods([2, 3, 4]), range: 1...20))
    }

    @Test func rejectsCountOutsideRange() {
        #expect(!ArchiveMapping.periodsAreContiguous(periods([1]), range: 8...20))
        let many = Array(1...21)
        #expect(!ArchiveMapping.periodsAreContiguous(periods(many), range: 1...20))
    }

    @Test func acceptsEmptyWithinRangeCheckFails() {
        // 空作息表没有可用节次，应当被拒绝。
        #expect(!ArchiveMapping.periodsAreContiguous([], range: 1...20))
    }

    // MARK: 节次时间

    @Test func mapsIndexToTime() {
        let table = periods([1, 2])
        #expect(ArchiveMapping.time(period: 1, in: table, isStart: true) == "08:00")
        #expect(ArchiveMapping.time(period: 1, in: table, isStart: false) == "08:45")
    }

    @Test func missingIndexReturnsNil() {
        #expect(ArchiveMapping.time(period: 9, in: periods([1, 2]), isStart: true) == nil)
    }

    // MARK: 周次裁剪

    @Test func clampsWeeksAndKeepsCoursesWithRemainingWeeks() {
        let input: [(String, Set<Int>)] = [("a", [1, 2, 18]), ("b", [1])]
        let result = ArchiveMapping.clampWeeks(
            input, totalWeeks: 16, weeksOf: { $0.1 }, apply: { ($0.0, $0.1) }
        )
        #expect(result.kept.count == 2)
        #expect(result.kept[0].1 == [1, 2])
        #expect(result.removedCount == 0)
    }

    @Test func removesCourseWhoseWeeksAllFallOutside() {
        let input: [(String, Set<Int>)] = [("早课", [1]), ("晚课", [18, 19])]
        let result = ArchiveMapping.clampWeeks(
            input, totalWeeks: 16, weeksOf: { $0.1 }, apply: { ($0.0, $0.1) }
        )
        #expect(result.kept.count == 1)
        #expect(result.kept[0].0 == "早课")
        #expect(result.removedCount == 1)
    }

    @Test func clampingToSameLengthChangesNothing() {
        let input: [(String, Set<Int>)] = [("a", [1, 20])]
        let result = ArchiveMapping.clampWeeks(
            input, totalWeeks: 20, weeksOf: { $0.1 }, apply: { ($0.0, $0.1) }
        )
        #expect(result.kept[0].1 == [1, 20])
        #expect(result.removedCount == 0)
    }

    @Test func emptyInputStaysEmpty() {
        let result = ArchiveMapping.clampWeeks(
            [] as [(String, Set<Int>)], totalWeeks: 20, weeksOf: { $0.1 }, apply: { ($0.0, $0.1) }
        )
        #expect(result.kept.isEmpty)
        #expect(result.removedCount == 0)
    }
}
