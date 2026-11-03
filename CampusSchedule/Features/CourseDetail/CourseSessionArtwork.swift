import SwiftUI

enum CourseSketchPhase: Equatable, Sendable {
    case beforeClass, inClass, finished
}

/// Original vector artwork for the course ticket: a classroom, chalkboard and campus cat.
/// The scene follows this lesson's state and contains no reused character sprite.
struct CourseClassroomSketch: View {
    let phase: CourseSketchPhase

    var body: some View {
        Canvas { context, size in
            var ink = context
            ink.scaleBy(x: size.width / 160, y: size.height / 150)
            let pen = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            func stroke(_ points: [CGPoint], width: CGFloat = 2.4) {
                var path = Path()
                path.addLines(points)
                ink.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            // Slightly uneven chalkboard and its chalk ledge.
            var board = Path()
            board.addLines([.init(x: 10, y: 16), .init(x: 112, y: 13), .init(x: 114, y: 73), .init(x: 12, y: 76)])
            board.closeSubpath()
            ink.fill(board, with: .color(.primary))
            ink.stroke(board, with: .color(.primary), style: pen)
            stroke([.init(x: 7, y: 79), .init(x: 119, y: 77)])
            var chalk = Path()
            chalk.move(to: .init(x: 24, y: 34))
            chalk.addCurve(to: .init(x: 83, y: 32), control1: .init(x: 45, y: 29), control2: .init(x: 57, y: 37))
            if phase == .inClass {
                chalk.move(to: .init(x: 24, y: 47)); chalk.addLine(to: .init(x: 95, y: 46))
                chalk.move(to: .init(x: 25, y: 60)); chalk.addLine(to: .init(x: 65, y: 58))
            } else if phase == .finished {
                chalk.move(to: .init(x: 39, y: 52))
                chalk.addLine(to: .init(x: 46, y: 59)); chalk.addLine(to: .init(x: 60, y: 44))
            } else {
                chalk.move(to: .init(x: 25, y: 49)); chalk.addLine(to: .init(x: 59, y: 48))
            }
            ink.stroke(chalk, with: .color(Color(uiColor: .systemBackground)), style: pen)
            // A wall clock, left deliberately without numerals.
            ink.stroke(Path(ellipseIn: .init(x: 128, y: 21, width: 22, height: 22)), with: .color(.primary), style: pen)
            stroke([.init(x: 139, y: 25), .init(x: 139, y: 32), .init(x: 144, y: 35)], width: 1.7)
            // Desk, open book, and a bag hooked to its side.
            stroke([.init(x: 23, y: 110), .init(x: 98, y: 108), .init(x: 99, y: 114), .init(x: 23, y: 116), .init(x: 23, y: 110)])
            stroke([.init(x: 30, y: 116), .init(x: 28, y: 142)])
            stroke([.init(x: 90, y: 115), .init(x: 92, y: 142)])
            if phase == .finished {
                ink.fill(Path(roundedRect: .init(x: 44, y: 99, width: 31, height: 8), cornerRadius: 2), with: .color(.primary))
            } else {
                stroke([.init(x: 39, y: 98), .init(x: 58, y: 101), .init(x: 79, y: 95),
                        .init(x: 78, y: 105), .init(x: 58, y: 110), .init(x: 40, y: 107), .init(x: 39, y: 98)], width: 1.9)
                stroke([.init(x: 58, y: 101), .init(x: 58, y: 109)], width: 1.5)
            }
            var bag = Path()
            bag.move(to: .init(x: 95, y: 119))
            bag.addQuadCurve(to: .init(x: 110, y: 120), control: .init(x: 105, y: 110))
            bag.addLines([.init(x: 115, y: 137), .init(x: 98, y: 140), .init(x: 95, y: 119)])
            ink.stroke(bag, with: .color(.primary), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            // A new little campus cat waits by the desk, naps during class, and perks up after class.
            var cat = Path()
            cat.addLines([.init(x: 122, y: 116), .init(x: 120, y: 104), .init(x: 127, y: 108), .init(x: 137, y: 108), .init(x: 145, y: 103), .init(x: 144, y: 118)])
            cat.addQuadCurve(to: .init(x: 144, y: 139), control: .init(x: 154, y: 130))
            cat.addQuadCurve(to: .init(x: 122, y: 139), control: .init(x: 135, y: 145))
            cat.addQuadCurve(to: .init(x: 122, y: 116), control: .init(x: 115, y: 130))
            ink.stroke(cat, with: .color(.primary), style: pen)
            var tail = Path()
            tail.move(to: .init(x: 145, y: 137))
            tail.addCurve(to: .init(x: 153, y: phase == .finished ? 115 : 133),
                          control1: .init(x: 158, y: 146), control2: .init(x: 161, y: 123))
            ink.stroke(tail, with: .color(.primary), style: pen)
            if phase == .inClass {
                stroke([.init(x: 126, y: 117), .init(x: 129, y: 118)], width: 1.6)
                stroke([.init(x: 136, y: 118), .init(x: 139, y: 117)], width: 1.6)
            } else {
                for x in [126.0, 137.0] {
                    ink.fill(Path(ellipseIn: .init(x: x, y: 116, width: 2.8, height: 3.5)), with: .color(.primary))
                }
            }
            stroke([.init(x: 131, y: 123), .init(x: 133, y: 124), .init(x: 135, y: 122)], width: 1.4)
            stroke([.init(x: 14, y: 145), .init(x: 80, y: 144), .init(x: 152, y: 146)], width: 1.4)
        }
        .accessibilityHidden(true)
    }
}

struct CourseTicketPaper: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 17
        var path = Path()
        path.move(to: .init(x: r, y: 1))
        path.addLine(to: .init(x: rect.maxX - r, y: 0))
        path.addQuadCurve(to: .init(x: rect.maxX, y: r), control: .init(x: rect.maxX, y: 0))
        path.addLine(to: .init(x: rect.maxX, y: rect.maxY - 7))
        let steps = max(2, Int(rect.width / 12))
        for index in 0...steps {
            let x = rect.maxX - rect.width * CGFloat(index) / CGFloat(steps)
            path.addLine(to: .init(x: x, y: rect.maxY - (index.isMultiple(of: 2) ? 5 : 1)))
        }
        path.addLine(to: .init(x: 0, y: r))
        path.addQuadCurve(to: .init(x: r, y: 1), control: .init(x: 0, y: 1))
        path.closeSubpath()
        return path
    }
}

struct CoursePaperPlane: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines([.init(x: rect.minX, y: rect.height * 0.42), .init(x: rect.maxX, y: rect.minY), .init(x: rect.width * 0.69, y: rect.maxY),
                       .init(x: rect.width * 0.46, y: rect.height * 0.6), .init(x: rect.minX, y: rect.height * 0.42)])
        path.move(to: .init(x: rect.width * 0.46, y: rect.height * 0.6))
        path.addLine(to: .init(x: rect.maxX, y: rect.minY))
        return path
    }
}
