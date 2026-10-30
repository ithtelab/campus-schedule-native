import Foundation

enum CampusCharacterState: String, CaseIterable, Sendable {
    case seatedReading, seatedEmpty, standingEmpty, standingReading

    var frame: Int {
        switch self {
        case .seatedReading: 0
        case .seatedEmpty: 3
        case .standingEmpty: 6
        case .standingReading: 9
        }
    }
    var isSeated: Bool { self == .seatedReading || self == .seatedEmpty }
    var hasBook: Bool { self == .seatedReading || self == .standingReading }
}

enum CampusCharacterAction: String, CaseIterable, Sendable {
    case stand, sit, pickUpBook, putDownBook, walk, stretch, prepareCourse, turnPage, rest
    var title: String {
        switch self {
        case .stand: "站起来"
        case .sit: "坐下"
        case .pickUpBook: "拿起书"
        case .putDownBook: "放下书"
        case .walk: "走一走"
        case .stretch: "伸个懒腰"
        case .prepareCourse: "准备上课"
        case .turnPage: "翻一页"
        case .rest: "歇一歇"
        }
    }
}

struct CampusAnimationPlan: Equatable, Sendable {
    var frames: [Int]
    var destination: CampusCharacterState
    var frameSeconds: Double = 0.14

    static func make(_ action: CampusCharacterAction, from state: CampusCharacterState) -> Self {
        let close: [Int] = state == .seatedReading ? [0, 1, 2, 3] : state == .standingReading ? [9, 8, 7, 6] : []
        let stand = state.isSeated ? close + [4, 5, 6] : close
        switch action {
        case .stand:
            return .init(frames: state.isSeated ? stand : [], destination: state.isSeated ? .standingEmpty : state)
        case .sit:
            return .init(frames: state.isSeated ? [] : close + [6, 5, 4, 14, 3], destination: state.isSeated ? state : .seatedEmpty)
        case .pickUpBook:
            return .init(frames: state.hasBook ? [] : state.isSeated ? [3, 2, 1, 0] : [6, 7, 8, 9],
                         destination: state.hasBook ? state : state.isSeated ? .seatedReading : .standingReading)
        case .putDownBook:
            return .init(frames: close, destination: state.isSeated ? .seatedEmpty : .standingEmpty)
        case .walk:
            return .init(frames: stand + Array(repeating: [10, 11, 12, 13], count: 3).flatMap { $0 } + [6],
                         destination: .standingEmpty, frameSeconds: 0.11)
        case .stretch:
            return .init(frames: stand + [6, 15, 15, 15, 6], destination: .standingEmpty)
        case .prepareCourse:
            // Course taps are a visual response; they never complete, mute or reschedule a lesson.
            return .init(frames: state == .standingReading ? [9, 8, 9] : stand + [6, 7, 8, 9], destination: .standingReading)
        case .turnPage:
            return .init(frames: state == .seatedReading ? [0, 1, 0] : state == .standingReading ? [9, 8, 9] : [], destination: state)
        case .rest:
            return .init(frames: state == .seatedEmpty ? [3, 14, 3] : [], destination: state)
        }
    }
}
