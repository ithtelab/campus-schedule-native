import Foundation
import Testing
@testable import ScheduleCore

struct AppearancePreferencesTests {
    @Test func defaultsToStudentAndPaper() {
        let preferences = AppearancePreferences()
        #expect(preferences.theme == .paper)
        #expect(preferences.density == .light)
        #expect(preferences.effects == .followSchedule)
    }

    @Test func roundTripsThroughJSON() throws {
        let preferences = AppearancePreferences(persona: .boy, theme: .paper,
                                               density: .off, effects: .staticOnly)
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppearancePreferences.self, from: data)
        #expect(decoded == preferences)
    }

    @Test func unknownEnumFallsBackInsteadOfFailing() throws {
        // 未来版本写入了当前不认识的枚举值，不能整份外观偏好失效。
        let json = """
        {"persona":"mecha","theme":"paper2","density":"light","effects":"followSchedule"}
        """
        let decoded = try JSONDecoder().decode(AppearancePreferences.self, from: Data(json.utf8))
        #expect(decoded.persona == .fallback)
        #expect(decoded.theme == .fallback)
    }

    @Test func missingFieldsUseDefaults() throws {
        let json = "{}"
        let decoded = try JSONDecoder().decode(AppearancePreferences.self, from: Data(json.utf8))
        #expect(decoded == AppearancePreferences())
    }

    @Test func unavailablePersonaIsNormalized() throws {
        // 即使有人手工把制作中的形象写进文件，也要退回可用形象，
        // 否则界面会去取不存在的图集。
        let json = """
        {"persona":"cat","theme":"paper","density":"light","effects":"followSchedule"}
        """
        let decoded = try JSONDecoder().decode(AppearancePreferences.self, from: Data(json.utf8))
        #expect(decoded.persona == .fallback)
    }

    @Test func onlyDrawnPersonasAreSelectable() {
        #expect(CampusPersona.girl.isAvailable)
        #expect(CampusPersona.boy.isAvailable)
        #expect(!CampusPersona.teacher.isAvailable)
        #expect(!CampusPersona.cat.isAvailable)
    }

    @Test func onlyPaperThemeIsSelectable() {
        #expect(CampusTheme.paper.isAvailable)
        #expect(!CampusTheme.notebook.isAvailable)
        #expect(!CampusTheme.chalkboard.isAvailable)
    }

    @Test func densityOffHidesCharacterButKeepsContent() {
        #expect(!DecorationDensity.off.showsCharacter)
        #expect(DecorationDensity.light.showsCharacter)
        #expect(DecorationDensity.rich.showsCharacter)
    }
}

struct MilestoneFormatTests {
    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        MilestoneCounter.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
    }

    @Test func todaySaysJustToday() {
        let item = Milestone(title: "毕业", date: day(2027, 6, 20))
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 20))
        #expect(MilestoneFormat.primary(item, reading: reading) == "就是今天")
        #expect(MilestoneFormat.number(reading) == "今天")
        #expect(MilestoneFormat.sentence(item, reading: reading) == "毕业就是今天")
    }

    @Test func countdownWording() {
        let item = Milestone(title: "毕业", date: day(2027, 6, 20))
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 10))
        #expect(MilestoneFormat.primary(item, reading: reading) == "10 天")
        #expect(MilestoneFormat.sentence(item, reading: reading) == "距毕业还有 10 天")
    }

    @Test func countUpWording() {
        let item = Milestone(title: "相识", date: day(2026, 6, 20), direction: .countUp)
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 20))
        #expect(MilestoneFormat.sentence(item, reading: reading) == "相识第 365 天")
    }

    @Test func archivedWordingUsesPastTense() {
        let item = Milestone(title: "入学", date: day(2024, 9, 1))
        let reading = MilestoneCounter.read(item, now: day(2027, 9, 2))
        #expect(MilestoneFormat.sentence(item, reading: reading).contains("已过去"))
    }

    @Test func dateTextAddsYearWhenNotThisYear() {
        let text = MilestoneFormat.dateText(day(2028, 3, 15), relativeTo: day(2027, 1, 1))
        #expect(text == "2028 年 3 月 15 日")
        let sameYear = MilestoneFormat.dateText(day(2027, 3, 15), relativeTo: day(2027, 1, 1))
        #expect(sameYear == "3 月 15 日")
    }

    @Test func emptyTitleGetsReadableFallback() {
        let item = Milestone(title: "", date: day(2027, 6, 20))
        let reading = MilestoneCounter.read(item, now: day(2027, 6, 19))
        #expect(MilestoneFormat.sentence(item, reading: reading) == "距这件事还有 1 天")
    }
}
