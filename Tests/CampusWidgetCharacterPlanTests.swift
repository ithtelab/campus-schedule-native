import Foundation
import Testing
@testable import ScheduleCore

struct CampusWidgetCharacterPlanTests {
    let now = Date(timeIntervalSince1970: 1788739200)

    @Test func interactionFollowsScheduleAndTogglesBack() {
        let context = CampusScheduleContext(phase: .inClass, occurrenceID: "lesson-a", room: "A302")
        #expect(CampusWidgetCharacterPlan.frame(context: context, now: now, interaction: nil) == 0)
        let tapped = CampusWidgetCharacterPlan.toggled(context: context, now: now, previous: nil)
        #expect(CampusWidgetCharacterPlan.frame(context: context, now: now, interaction: tapped) == 1)
        let again = CampusWidgetCharacterPlan.toggled(context: context, now: now, previous: tapped)
        #expect(CampusWidgetCharacterPlan.frame(context: context, now: now, interaction: again) == 0)
    }

    @Test func responseCannotLeakIntoAnotherLessonPhaseOrDay() {
        let context = CampusScheduleContext(phase: .preparing, occurrenceID: "lesson-a", room: "A302")
        let tapped = CampusWidgetCharacterPlan.toggled(context: context, now: now, previous: nil)
        for changed in [CampusScheduleContext(phase: .inClass, occurrenceID: "lesson-a", room: "A302"),
                        CampusScheduleContext(phase: .preparing, occurrenceID: "lesson-b", room: "B205")] {
            #expect(CampusWidgetCharacterPlan.frame(context: changed, now: now, interaction: tapped) == changed.stableState.frame)
        }
        #expect(CampusWidgetCharacterPlan.frame(context: context, now: now.addingTimeInterval(86400), interaction: tapped) == context.stableState.frame)
    }

    @Test func responsePosesAreExplicitForEverySchedulePhase() {
        let phases: [(CampusSchedulePhase, Int)] = [(.freeReading, 1), (.preparing, 8), (.moving, 10),
                                                   (.inClass, 1), (.betweenClasses, 14), (.finished, 15)]
        for (phase, expected) in phases {
            let context = CampusScheduleContext(phase: phase, occurrenceID: "lesson", room: "A302")
            let tapped = CampusWidgetCharacterPlan.toggled(context: context, now: now, previous: nil)
            #expect(CampusWidgetCharacterPlan.frame(context: context, now: now, interaction: tapped) == expected)
        }
    }

    @Test func timelineIncludesTheConfiguredPreparationBoundary() {
        let course = CourseOccurrence(id: "a", courseID: "a", title: "数学", room: "A302",
                                      start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
        let dates = WidgetTimelinePlan.dates(courses: [course], now: now, leadMinutes: 25)
        #expect(dates.contains(course.start.addingTimeInterval(-25 * 60)))
        #expect(!dates.contains(course.start.addingTimeInterval(-10 * 60)))
    }
}
