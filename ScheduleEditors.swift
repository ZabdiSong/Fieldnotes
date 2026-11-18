import SwiftUI

struct TaskEditor: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State var task: PlanTask
    @State private var deleting = false
    private var existing: Bool { store.data.tasks.contains { $0.id == task.id } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing ? "Edit task" : "Add a task").font(.system(size: 24, weight: .bold))
            Form {
                Section("What to work on") {
                    TextField("Task", text: $task.title)
                    TextField("Subject / interest", text: $task.subject)
                    TextField("Next small step", text: $task.nextStep, axis: .vertical).lineLimit(2...3)
                }
                Section("Calendar time") {
                    Toggle("Schedule this task", isOn: Binding(get: { task.planned != nil }, set: { task.planned = $0 ? PlanLogic.atMinute(17 * 60, on: Date()) : nil }))
                    if task.planned != nil {
                        DatePicker("Start", selection: Binding(get: { task.planned ?? Date() }, set: { task.planned = $0 }))
                    }
                    Stepper("Duration: \(task.minutes) minutes", value: $task.minutes, in: 15...1440, step: 15)
                }
                Section("Submission deadline") {
                    Toggle("Has a deadline", isOn: Binding(get: { task.due != nil }, set: { task.due = $0 ? Date() : nil }))
                    if task.due != nil { DatePicker("Due", selection: Binding(get: { task.due ?? Date() }, set: { task.due = $0 })) }
                    Toggle("Completed in planner", isOn: $task.done)
                }
            }.formStyle(.grouped).frame(height: 380)
            Text("Calendar time is when you plan to work. Moving it does not change the submission deadline.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                if existing { Button("Delete…", role: .destructive) { deleting = true } }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save task") {
                    task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.put(task); dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 460).background(canvas).tint(blue)
            .confirmationDialog("Delete this task from your planner?", isPresented: $deleting) {
                Button("Delete task", role: .destructive) { store.remove(task); dismiss() }
            }
    }
}

struct RegularEditor: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State var series: RegularArrangement
    @State private var deleting = false
    private var existing: Bool { store.data.arrangements.contains { $0.id == series.id } }
    private var valid: Bool {
        !series.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (series.endDate.map { PlanLogic.calendar.startOfDay(for: $0) >= PlanLogic.calendar.startOfDay(for: series.startDate) } ?? true)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(existing ? "Weekly arrangement" : "Add a weekly arrangement", systemImage: "repeat")
                .font(.system(size: 22, weight: .bold))
            Text("You are editing the weekly schedule. These changes apply to the routine; saved one-date exceptions are kept.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Form {
                Section("Arrangement") {
                    TextField("Title", text: $series.title, prompt: Text("Night study"))
                    TextField("Category", text: $series.subject)
                    TextField("Notes / next step", text: $series.nextStep, axis: .vertical).lineLimit(2...3)
                }
                Section("Repeat every week") {
                    Picker("Every", selection: $series.weekday) {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in Text(weekdayName(day)).tag(day) }
                    }
                    DatePicker("Start time", selection: Binding(get: {
                        PlanLogic.atMinute(series.startMinute, on: series.startDate)
                    }, set: {
                        let c = PlanLogic.calendar.dateComponents([.hour, .minute], from: $0)
                        series.startMinute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                    }), displayedComponents: .hourAndMinute)
                    Stepper("Duration: \(series.minutes) minutes", value: $series.minutes, in: 15...1440, step: 15)
                    DatePicker("Starting from", selection: $series.startDate, displayedComponents: .date)
                    Toggle("Has an end date", isOn: Binding(get: { series.endDate != nil }, set: { series.endDate = $0 ? series.startDate : nil }))
                    if series.endDate != nil {
                        DatePicker("Last date", selection: Binding(get: { series.endDate ?? series.startDate }, set: { series.endDate = $0 }), in: series.startDate..., displayedComponents: .date)
                    }
                }
            }.formStyle(.grouped).frame(height: 375)
            Text("Every \(weekdayName(series.weekday)) at \(minuteLabel(series.startMinute)) · \(series.minutes) min · Beijing time")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(blue)
            if !valid && !series.title.isEmpty { Text("The end date must be on or after the start date.").font(.caption).foregroundStyle(.red) }
            HStack {
                if existing { Button("Delete series…", role: .destructive) { deleting = true } }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save arrangement") {
                    series.title = series.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.put(series); dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }.padding(24).frame(width: 480).background(canvas).tint(blue)
            .confirmationDialog("Delete the weekly arrangement and all of its exceptions?", isPresented: $deleting) {
                Button("Delete arrangement", role: .destructive) { store.remove(series); dismiss() }
            }
    }
}

struct OccurrenceEditor: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    let entry: CalendarEntry
    @State private var title: String
    @State private var nextStep: String
    @State private var start: Date
    @State private var minutes: Int
    @State private var done: Bool
    init(store: PlannerStore, entry: CalendarEntry) {
        self.store = store; self.entry = entry
        let change = store.data.exceptions.first { $0.seriesID == entry.seriesID && $0.originalDay == entry.originalDay }
        _title = State(initialValue: change?.title ?? entry.title)
        _nextStep = State(initialValue: change?.nextStep ?? entry.nextStep)
        _start = State(initialValue: change?.replacementStart ?? entry.start)
        _minutes = State(initialValue: change?.minutes ?? entry.minutes)
        _done = State(initialValue: change?.done ?? entry.done)
    }
    private var exception: ArrangementException {
        ArrangementException(seriesID: entry.seriesID!, originalDay: entry.originalDay!, replacementStart: start,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), nextStep: nextStep, minutes: minutes, done: done)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Change this date").font(.system(size: 23, weight: .bold))
                Spacer()
                if let series = store.data.arrangements.first(where: { $0.id == entry.seriesID }) {
                    Button("Edit weekly schedule") { store.editor = .regular(series) }
                        .buttonStyle(.bordered).font(.system(size: 11))
                }
            }
            Text("Original date: \(entry.originalDay ?? "") · The rest of the weekly arrangement stays unchanged.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Form {
                Section("Temporary arrangement") {
                    TextField("Title", text: $title)
                    DatePicker("New start", selection: $start)
                    Stepper("Duration: \(minutes) minutes", value: $minutes, in: 15...1440, step: 15)
                    TextField("Notes", text: $nextStep, axis: .vertical).lineLimit(2...3)
                    Toggle("Completed", isOn: $done)
                }
            }.formStyle(.grouped).frame(height: 285)
            Text("Saving crosses out the original slot and adds your temporary change. You can restore the regular occurrence at any time.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Skip this date") {
                    var change = exception; change.skipped = true; change.done = false
                    store.change(change); dismiss()
                }.buttonStyle(.bordered)
                if store.data.exceptions.contains(where: { $0.seriesID == entry.seriesID && $0.originalDay == entry.originalDay }) {
                    Button("Restore regular") { store.restore(entry); dismiss() }.buttonStyle(.bordered)
                }
                Spacer()
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save temporary change") { store.change(exception); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 470).background(canvas).tint(blue)
    }
}
