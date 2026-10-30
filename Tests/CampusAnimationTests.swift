import Testing
@testable import ScheduleCore

@Suite struct CampusAnimationTests {
    @Test func standsThroughIntermediatePoses() {
        let plan = CampusAnimationPlan.make(.stand, from: .seatedReading)
        #expect(plan.frames == [0, 1, 2, 3, 4, 5, 6])
        #expect(plan.destination == .standingEmpty)
    }
    @Test func sitsWithEmptyHands() {
        let plan = CampusAnimationPlan.make(.sit, from: .standingReading)
        #expect(plan.frames.starts(with: [9, 8, 7, 6]))
        #expect(plan.frames.contains(14))
        #expect(plan.destination == .seatedEmpty)
    }
    @Test func bookActionsWorkWhileSeatedAndStanding() {
        for state in [CampusCharacterState.seatedEmpty, .standingEmpty] {
            let pick = CampusAnimationPlan.make(.pickUpBook, from: state)
            #expect(pick.destination.hasBook)
            #expect(pick.destination.isSeated == state.isSeated)
            let put = CampusAnimationPlan.make(.putDownBook, from: pick.destination)
            #expect(put.destination == state)
        }
    }
    @Test func walkingPutsBookDownAndUsesAllStrideFrames() {
        let plan = CampusAnimationPlan.make(.walk, from: .seatedReading)
        #expect(plan.frames.starts(with: [0, 1, 2, 3, 4, 5, 6]))
        for frame in 10...13 { #expect(plan.frames.filter { $0 == frame }.count == 3) }
        #expect(plan.destination == .standingEmpty)
    }
    @Test func unavailableActionsDoNotChangeStableState() {
        #expect(CampusAnimationPlan.make(.stand, from: .standingReading).frames.isEmpty)
        #expect(CampusAnimationPlan.make(.sit, from: .seatedReading).destination == .seatedReading)
        #expect(CampusAnimationPlan.make(.pickUpBook, from: .standingReading).frames.isEmpty)
    }
    @Test func everyTransitionUsesValidFramesAndCourseTapKeepsBook() {
        for state in CampusCharacterState.allCases {
            for action in CampusCharacterAction.allCases {
                #expect(CampusAnimationPlan.make(action, from: state).frames.allSatisfy { (0..<16).contains($0) })
            }
            #expect(CampusAnimationPlan.make(.prepareCourse, from: state).destination == .standingReading)
        }
    }
}
