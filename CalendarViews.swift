import SwiftUI

struct CalendarGrid: View {
    @ObservedObject var store: PlannerStore
    let days: [Date]
    @Binding var selectedDay: Date
    var hourHeight: CGFloat = 56
    var compact = false
    var onEntry: (CalendarEntry) -> Void
    var onNew: (Date) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let interval = DateInterval(start: days[0], end: PlanLogic.dayInterval(days.last!).end)
            let entries = PlanLogic.entries(in: interval, data: store.data)
            VStack(spacing: 0) {
                if !compact {
                    HStack(spacing: 0) {
                        Text("GMT+8").font(.system(size: 8)).foregroundStyle(.secondary).frame(width: 43)
                        ForEach(days, id: \.self) { day in
                            Button { selectedDay = day } label: {
                                VStack(spacing: 3) {
                                    Text(PlanLogic.label(day, format: "EEE").uppercased()).font(.system(size: 9, weight: .semibold))
                                    Text(PlanLogic.label(day, format: "d")).font(.system(size: 17, weight: .semibold))
                                        .frame(width: 29, height: 27)
                                        .background(PlanLogic.calendar.isDate(day, inSameDayAs: selectedDay) ? paper : .clear, in: RoundedRectangle(cornerRadius: 8))
                                    let due = store.pending.filter { $0.due.map { PlanLogic.calendar.isDate($0, inSameDayAs: day) } == true }.count
                                    Text(due > 0 ? "\(due) due" : " ").font(.system(size: 8)).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity).padding(.vertical, 7).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                    Divider()
                }
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(0..<24) { hour in
                                    Text(String(format: "%02d:00", hour)).font(.system(size: compact ? 9 : 8, design: .monospaced))
                                        .foregroundStyle(.secondary).frame(width: 43, height: hourHeight, alignment: .top)
                                        .id("hour-\(hour)")
                                }
                            }.frame(width: 43, height: hourHeight * 24, alignment: .topLeading)
                            ForEach(days, id: \.self) { day in
                                CalendarDayColumn(store: store, day: day, entries: entries, now: context.date,
                                    hourHeight: hourHeight, compact: compact, onEntry: onEntry, onNew: onNew)
                            }
                        }.padding(.top, 6).coordinateSpace(name: "calendar-canvas")
                    }
                    .onAppear { scrollToTime(reader, now: context.date) }
                    .onChange(of: days) { _, _ in scrollToTime(reader, now: context.date) }
                }
            }
        }.background(canvas).clipShape(RoundedRectangle(cornerRadius: compact ? 0 : 12))
            .overlay { if !compact { RoundedRectangle(cornerRadius: 12).strokeBorder(outline).allowsHitTesting(false) } }
    }
    private func scrollToTime(_ reader: ScrollViewProxy, now: Date) {
        let includesToday = days.contains { PlanLogic.calendar.isDate($0, inSameDayAs: now) }
        let hour = includesToday ? max(0, PlanLogic.calendar.component(.hour, from: now) - 1) : 8
        reader.scrollTo("hour-\(hour)", anchor: .top)
    }
}

private struct CalendarDayColumn: View {
    @ObservedObject var store: PlannerStore
    let day: Date
    let entries: [CalendarEntry]
    let now: Date
    let hourHeight: CGFloat
    let compact: Bool
    let onEntry: (CalendarEntry) -> Void
    let onNew: (Date) -> Void
    @State private var dropTarget = false
    @State private var draggingID: String?
    @State private var translation: CGSize = .zero
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(dropTarget ? blue.opacity(0.07) : .white)
                ForEach(0..<24) { hour in
                    Rectangle().fill(outline).frame(height: 0.5).offset(y: CGFloat(hour) * hourHeight)
                    Rectangle().fill(outline.opacity(0.4)).frame(height: 0.5).offset(y: (CGFloat(hour) + 0.5) * hourHeight)
                }
                Rectangle().fill(outline).frame(width: 0.5)
                ForEach(PlanLogic.placements(entries, on: day)) { placement in
                    let width = max(15, (geometry.size.width - 5) / CGFloat(placement.laneCount))
                    let height = max(25, (placement.endMinute - placement.startMinute) / 60 * hourHeight - 2)
                    eventButton(placement.entry, height: height)
                        .frame(width: max(12, width - 2), height: height, alignment: .topLeading)
                        .clipped()
                        .offset(x: 3 + CGFloat(placement.lane) * width + (draggingID == placement.id ? translation.width : 0),
                                y: placement.startMinute / 60 * hourHeight + (draggingID == placement.id ? translation.height : 0))
                        .zIndex(draggingID == placement.id ? 10 : 1)
                        .highPriorityGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("calendar-canvas"))
                            .onChanged { value in
                                draggingID = placement.id; translation = value.translation
                            }
                            .onEnded { value in
                                draggingID = nil; translation = .zero
                                let dayDelta = Int((value.translation.width / geometry.size.width).rounded())
                                let base = PlanLogic.calendar.date(byAdding: .day, value: dayDelta, to: placement.entry.start)!
                                let target = base.addingTimeInterval(value.translation.height / hourHeight * 3600)
                                let start = PlanLogic.calendar.startOfDay(for: target)
                                let minute = Int((target.timeIntervalSince(start) / 60 / 15).rounded()) * 15
                                _ = store.move(placement.entry.dragToken, to: PlanLogic.atMinute(minute, on: start))
                            }, including: compact || placement.entry.crossedOut ? .none : .all)
                }
                if PlanLogic.calendar.isDate(now, inSameDayAs: day) {
                    let minute = now.timeIntervalSince(PlanLogic.calendar.startOfDay(for: day)) / 60
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Now " + PlanLogic.label(now, format: "HH:mm"))
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .foregroundStyle(.white).background(blue, in: Capsule())
                        Rectangle().fill(blue).frame(height: 1.5)
                    }.offset(y: max(0, minute / 60 * hourHeight - 14)).allowsHitTesting(false)
                }
            }.contentShape(Rectangle())
                .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                    guard !compact else { return }; onNew(date(at: value.location.y))
                })
                .dropDestination(for: String.self) { items, location in
                    guard !compact, let token = items.first else { return false }
                    return store.move(token, to: date(at: location.y))
                } isTargeted: { dropTarget = $0 && !compact }
        }.frame(maxWidth: .infinity).frame(height: hourHeight * 24)
    }
    private func date(at y: CGFloat) -> Date {
        let minute = min(1425, max(0, Int((y / hourHeight * 60 / 15).rounded()) * 15))
        return PlanLogic.atMinute(minute, on: day)
    }
    private func eventButton(_ entry: CalendarEntry, height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(entry.kind == .task ? blue : paper).frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.system(size: compact ? 11 : 10, weight: .semibold))
                        .lineLimit(height > 48 ? 2 : 1).strikethrough(entry.crossedOut || entry.done)
                    if height > 32 {
                        Text(PlanLogic.label(entry.start, format: "HH:mm") + "–" + PlanLogic.label(entry.end, format: "HH:mm"))
                            .font(.system(size: 8, design: .monospaced)).lineLimit(1)
                    }
                    if height > 58 {
                        Text(entry.badge).font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }.padding(4).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(entry.crossedOut ? Color.gray.opacity(0.08) : entry.kind == .task ? blue.opacity(0.10) : paper.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(entry.crossedOut ? outline : entry.kind == .changed ? blue : .clear, style: StrokeStyle(lineWidth: 1, dash: entry.crossedOut ? [3, 2] : [])))
                .foregroundStyle(entry.crossedOut ? ink.opacity(0.5) : ink)
            .contentShape(Rectangle())
            .onTapGesture { onEntry(entry) }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onEntry(entry) }
            .help("\(entry.title)\n\(PlanLogic.label(entry.start, format: "EEE MMM d, HH:mm"))–\(PlanLogic.label(entry.end, format: "HH:mm"))\n\(entry.badge)\n\(entry.nextStep)")
            .accessibilityLabel("\(entry.title), \(PlanLogic.label(entry.start, format: "EEE d HH:mm")), \(entry.badge)")
    }
}
