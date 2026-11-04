import SwiftUI

/// System surfaces open this read-only view; editing remains in the app's course management flow.
struct CourseNowView: View {
    let course: DemoCourse
    var occurrenceID: String?
    var onClose: () -> Void
    @Environment(PreviewStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    private var blueTheme: Bool { store.appearance.theme == .blueStickers }
    private var themeAccent: Color { blueTheme ? CampusStickerMark.accent : .primary }
    private var occurrence: CourseOccurrence? {
        CourseDeepLink.occurrence(for: .init(courseID: course.id, termID: store.activeTermID, occurrenceID: occurrenceID),
                                  in: store.occurrences, now: store.now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let item = occurrence {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let now = store.isPreview ? store.now : context.date
                            lessonTicket(item, now: now)
                        }
                        if item.wasRescheduled {
                            Label("本次已调课，以上为最新时间和地点", systemImage: "calendar.badge.clock")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        ContentUnavailableView(occurrenceID == nil ? "暂无待上的安排" : "本次安排已更新",
                            systemImage: "calendar.badge.clock",
                            description: Text("请返回课表查看 \(course.title) 的最新安排。"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .frame(maxWidth: 540, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(DesignSystem.background)
            .navigationTitle("本次课程").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", action: onClose) } }
            .accessibilityIdentifier("course.now")
        }
    }

    private func lessonTicket(_ item: CourseOccurrence, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("课堂入场券").font(DesignSystem.hand(28))
                Spacer(minLength: 12)
                Text("第 \(ScheduleRules.week(on: item.start, semesterStart: store.semesterStart)) 周")
                    .font(.caption.weight(.medium).monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(status(item, now: now))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(themeAccent, lineWidth: 1.3))
                            .foregroundStyle(themeAccent)
                            .rotationEffect(.degrees(-2))
                        Text(item.title).font(.largeTitle.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("course.now.title")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize && store.appearance.density.showsCharacter {
                        Group {
                            if store.appearance.showsBlueStickers {
                                let phase = sketchPhase(item, now: now)
                                CampusStickerStudent(frame: phase == .finished ? 3 : phase == .inClass ? 0 : 9,
                                                     wearsCap: store.appearance.persona != .boy)
                                    .padding(.horizontal, 20)
                            } else {
                                CourseClassroomSketch(phase: sketchPhase(item, now: now))
                            }
                        }
                            .frame(width: 132, height: 138)
                    }
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("上课教室").font(.caption).opacity(0.75)
                        Text(item.room.isEmpty ? "地点待确认" : item.room)
                            .font(.title2.weight(.bold)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if !typeSize.isAccessibilitySize {
                        Image(systemName: "door.left.hand.open").font(.title2).accessibilityHidden(true)
                    }
                }
                .padding(16)
                .foregroundStyle(blueTheme ? Color.white : Color(uiColor: .systemBackground))
                .background(blueTheme ? CampusStickerMark.blue : .primary, in: RoundedRectangle(cornerRadius: 8))
                Text(item.start, format: .dateTime.year().month().day().weekday(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
                Path { path in
                    path.move(to: .zero); path.addLine(to: .init(x: 500, y: 0))
                }
                .stroke(.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                .frame(height: 1).clipped().accessibilityHidden(true)
                lessonTimeline(item, now: now)
                HStack(alignment: .top) {
                    if !course.teacher.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("任课教师").font(.caption).foregroundStyle(.secondary)
                            Text(course.teacher).font(.subheadline.weight(.medium))
                        }
                    }
                    Spacer(minLength: 12)
                    Text("第 \(course.startPeriod)–\(course.endPeriod) 节")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        .rotationEffect(.degrees(2))
                }
            }
            .padding(20).padding(.bottom, 10)
            .background(DesignSystem.surface.opacity(0.45), in: CourseTicketPaper())
            .overlay(CourseTicketPaper().stroke(themeAccent.opacity(0.8), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round)))
        }
    }

    private func lessonTimeline(_ item: CourseOccurrence, now: Date) -> some View {
        let duration = max(1, item.end.timeIntervalSince(item.start))
        let progress = CGFloat(min(1, max(0, now.timeIntervalSince(item.start) / duration)))
        let timeLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline))
        return VStack(alignment: .leading, spacing: 14) {
            timeLayout {
                VStack(alignment: .leading, spacing: 5) {
                    Text("上课").font(.caption).foregroundStyle(.secondary)
                    Text(ScheduleRules.time(item.start)).font(.title.weight(.semibold).monospacedDigit())
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 5) {
                    Text("下课").font(.caption).foregroundStyle(.secondary)
                    Text(ScheduleRules.time(item.end)).font(.title.weight(.semibold).monospacedDigit())
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.13)).frame(height: 2)
                    Capsule().fill(themeAccent).frame(width: proxy.size.width * progress, height: 2)
                    CoursePaperPlane().fill(DesignSystem.background)
                        .overlay(CoursePaperPlane().stroke(themeAccent, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)))
                        .frame(width: 25, height: 20)
                        .offset(x: max(0, proxy.size.width - 25) * progress, y: -3)
                }.frame(maxHeight: .infinity)
            }
            .frame(height: 22).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("本次上课进度").font(.caption).foregroundStyle(.secondary)
                Text(timingNote(item, now: now)).font(.subheadline.weight(.medium))
            }
        }
    }

    private func sketchPhase(_ item: CourseOccurrence, now: Date) -> CourseSketchPhase {
        now >= item.end ? .finished : now >= item.start ? .inClass : .beforeClass
    }

    private func timingNote(_ item: CourseOccurrence, now: Date) -> String {
        if now >= item.end { return "本次已结束" }
        if now >= item.start { return "还有 \(max(1, Int(ceil(item.end.timeIntervalSince(now) / 60)))) 分钟下课" }
        if ScheduleRules.calendar.isDate(now, inSameDayAs: item.start) {
            return "尚未开始 · \(max(1, Int(ceil(item.start.timeIntervalSince(now) / 60)))) 分钟后上课"
        }
        return "尚未开始"
    }

    private func status(_ item: CourseOccurrence, now: Date) -> String {
        if now >= item.end { return "本次已结束" }
        if now >= item.start { return "正在上课" }
        return ScheduleRules.calendar.isDate(item.start, inSameDayAs: now) ? "即将上课" : "课程安排"
    }
}
