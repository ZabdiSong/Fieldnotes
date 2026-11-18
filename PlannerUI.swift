import SwiftUI

struct PlannerView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedDay = PlanLogic.calendar.startOfDay(for: Date())
    @State private var dayMode = false
    @State private var taskFilter = "Inbox"
    private let filters = ["Inbox", "All", "Done"]

    private var visibleDays: [Date] { dayMode ? [selectedDay] : PlanLogic.days(from: PlanLogic.weekStart(selectedDay)) }
    private var tasks: [PlanTask] {
        if taskFilter == "Done" { return store.data.tasks.filter(\.done) }
        if taskFilter == "Inbox" { return store.pending.filter { $0.planned == nil } }
        return store.pending
    }
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 22).padding(.vertical, 16)
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 242)
                Divider()
                calendar.padding(18)
            }
        }
        .frame(minWidth: 860, minHeight: 610)
        .background(canvas).foregroundStyle(ink).tint(blue)
        .background(PlannerWindowSetup())
        .overlay(alignment: .topTrailing) {
            if let moment = store.completion {
                CompletionAnimation(title: moment.title).id(moment.id).padding(.top, 70).padding(.trailing, 22)
                    .transition(.move(edge: .top).combined(with: .opacity))

            }
        }
        .onChange(of: store.jumpDate) { _, date in
            if let date { selectedDay = PlanLogic.calendar.startOfDay(for: date); dayMode = true }
        }
        .sheet(item: $store.editor) { editor in
            Group {
                switch editor {
                case .task(let task): TaskEditor(store: store, task: task)
                case .regular(let series): RegularEditor(store: store, series: series)
                case .occurrence(let entry): OccurrenceEditor(store: store, entry: entry)
                }
            }.preferredColorScheme(.light).fontDesign(.rounded)
                .environment(\.timeZone, PlanLogic.calendar.timeZone)
                .environment(\.calendar, PlanLogic.calendar)
        }
        .alert("Fieldnotes", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fieldnotes").font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(blue)
                Text("A place for your days, duties & ideas").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { store.desktopVisible.toggle() } label: {
                Label("Today widget", systemImage: store.desktopVisible ? "rectangle.inset.filled" : "rectangle")
            }.help("Show or hide today's calendar on your desktop")
            Button { store.importSchool() } label: { Label("Import", systemImage: "arrow.down.to.line") }
            Button { store.editor = .regular(RegularArrangement(startDate: selectedDay)) } label: {
                Label("Weekly arrangement", systemImage: "repeat")
            }
            Button { newTask(at: PlanLogic.atMinute(17 * 60, on: selectedDay)) } label: {
                Label("Add task", systemImage: "plus")
            }.buttonStyle(.borderedProminent)
        }.buttonStyle(.bordered).font(.system(size: 11))
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Label { Text("MAIN FOCUS").tracking(1) } icon: { Image(systemName: "star.fill").foregroundStyle(paper) }
                    .font(.system(size: 10, weight: .semibold))
                if let focus = store.pending.first(where: { $0.id == store.data.priorityID }) {
                    Button { store.editor = .task(focus) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(focus.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                            Text(focus.nextStep.isEmpty ? "Add a next step →" : focus.nextStep)
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                } else {
                    Text("Star a task to focus on it.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(outline))
            HStack {
                Text("Your tasks").font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(tasks.count)").font(.caption).foregroundStyle(blue)
            }
            Picker("Tasks", selection: $taskFilter) {
                ForEach(filters, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            Text("Drag a task into the calendar. Click to edit.").font(.system(size: 10)).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if tasks.isEmpty {
                        Text(taskFilter == "Inbox" ? "All caught up. Add a task or import schoolwork." : "No tasks in this view.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 15)
                    }
                    ForEach(tasks) { task in
                        sidebarTask(task).draggable("task/" + task.id)
                    }
                }
            }.frame(maxHeight: .infinity)
            Divider()
            HStack {
                Label("Weekly arrangements", systemImage: "repeat").font(.system(size: 11, weight: .semibold))
                Spacer()
                Button { store.editor = .regular(RegularArrangement(startDate: selectedDay)) } label: { Image(systemName: "plus") }
                    .buttonStyle(.plain).help("Add a recurring arrangement")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    if store.data.arrangements.isEmpty {
                        Text("For classes, night study or any weekly routine.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    ForEach(store.data.arrangements) { series in
                        Button { store.editor = .regular(series) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(series.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text(weekdayName(series.weekday) + " · " + minuteLabel(series.startMinute))
                                        .font(.system(size: 10)).foregroundStyle(blue)
                                }
                                Spacer(minLength: 2)
                                Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(blue)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain).help("Edit weekly schedule")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: store.data.arrangements.isEmpty ? 32 : min(105, CGFloat(store.data.arrangements.count) * 43))
            Label("Saved on this Mac · Beijing time", systemImage: "internaldrive")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }.padding(16)
    }
    private func sidebarTask(_ task: PlanTask) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Button { store.toggle(task) } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle").font(.system(size: 16))
            }.buttonStyle(.plain).help(task.done ? "Reopen" : "Mark complete locally")
            Button { store.editor = .task(task) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.subject).font(.system(size: 9, weight: .semibold)).foregroundStyle(blue)
                    Text(task.title).font(.system(size: 12, weight: .medium)).lineLimit(2).strikethrough(task.done)
                    Text(task.planned.map { PlanLogic.label($0, format: "EEE d · HH:mm") } ?? "Unplanned · \(task.minutes) min")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    if let due = task.due {
                        Text("Due " + PlanLogic.label(due, format: "MMM d, HH:mm"))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button { store.prioritize(task) } label: {
                Image(systemName: store.data.priorityID == task.id ? "star.fill" : "star")
                    .foregroundStyle(store.data.priorityID == task.id ? paper : blue)
            }.buttonStyle(.plain).help("Set main focus")
        }.padding(10).background(canvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(outline))
    }
    private var calendar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(PlanLogic.label(selectedDay, format: "MMMM yyyy")).font(.system(size: 20, weight: .bold))
                    Text(dayMode ? PlanLogic.label(selectedDay, format: "EEEE, MMM d") : "Week of " + PlanLogic.label(visibleDays[0], format: "MMM d"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { navigate(-1) } label: { Image(systemName: "chevron.left") }.help("Previous")
                Button("Today") { selectedDay = PlanLogic.calendar.startOfDay(for: Date()) }
                Button { navigate(1) } label: { Image(systemName: "chevron.right") }.help("Next")
                Picker("Calendar", selection: $dayMode) {
                    Text("Week").tag(false); Text("Day").tag(true)
                }.pickerStyle(.segmented).frame(width: 112).labelsHidden()
            }.buttonStyle(.bordered).font(.system(size: 11))
            CalendarGrid(store: store, days: visibleDays, selectedDay: $selectedDay,
                         onEntry: { store.edit($0) }, onNew: { newTask(at: $0) })
            HStack(spacing: 12) {
                Label("Tasks", systemImage: "square.fill").foregroundStyle(blue)
                Label("Weekly", systemImage: "repeat").foregroundStyle(ink)
                Label("Exception", systemImage: "arrow.triangle.branch").foregroundStyle(ink)
                Spacer()
                Text("Drag to move · double-click to add · 15-minute steps").foregroundStyle(.secondary)
            }.font(.system(size: 9))
        }
    }
    private func navigate(_ direction: Int) {
        selectedDay = PlanLogic.calendar.date(byAdding: .day, value: direction * (dayMode ? 1 : 7), to: selectedDay)!
    }
    private func newTask(at date: Date) { store.editor = .task(PlanTask(planned: date)) }
}

func weekdayName(_ day: Int) -> String { ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][max(0, min(6, day - 1))] }
func minuteLabel(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
