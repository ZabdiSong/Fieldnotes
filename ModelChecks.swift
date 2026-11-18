import Foundation

@main
enum ModelChecks {
    static func main() throws {
        let now = PlanLogic.date("2026-11-18T23:30:00+08:00")!
        let days = PlanLogic.days(from: now)
        precondition(days.count == 7 && PlanLogic.label(days[0], format: "yyyy-MM-dd HH:mm") == "2026-11-18 00:00")
        precondition(PlanLogic.label(days[6], format: "yyyy-MM-dd") == "2026-11-24")
        precondition(PlanLogic.date("2026-11-18T10:00:00.123+08:00") != nil)
        precondition(PlanLogic.date("2026-11-18T23:30:00") == now)
        precondition(PlanLogic.date("2026-11-18T23:30:00.000") == now)
        precondition(PlanLogic.date("not a date") == nil)
        let a = PlanTask(title: "Read", due: days[1], planned: days[0], minutes: 45)
        let b = PlanTask(title: "Finished", planned: days[0], minutes: 90, done: true)
        let c = PlanTask(title: "Unplanned", due: days[0], minutes: 60)
        precondition(PlanLogic.workload([a, b, c], day: days[0]) == 45)
        precondition(PlanLogic.workload([a, b, c], day: days[1]) == 0)
        let report = Data(#"{"tasks":[{"id":"open","title":"Lab report","subject":"Biology","kind":"assignment","status":"状态未知","submission_state":2,"due":"2026-11-20T18:00:00+08:00"},{"id":"submitted","title":"Done","subject":"Biology","kind":"assignment","status":"状态未知","submission_state":"3"},{"id":"record","title":"Notice","subject":"Biology","kind":"record"},{"id":"closed","title":"Closed","subject":"Biology","kind":"assignment","submission_closed":true},{"id":"graded","title":"Graded","subject":"Biology","kind":"assignment","grade":{"score":100}}]}"#.utf8)
        var state = PlannerData()
        precondition(tryImport(report, into: &state) == 1)
        precondition(state.tasks[0].planned == nil)
        state.tasks[0].nextStep = "Explain the control"
        state.tasks[0].minutes = 75
        state.tasks[0].done = true
        state.priorityID = state.tasks[0].id
        precondition(tryImport(report, into: &state) == 0)
        precondition(state.tasks.count == 1 && state.tasks[0].done && state.tasks[0].minutes == 75)
        precondition(state.tasks[0].nextStep == "Explain the control")
        let saved = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(PlannerData.self, from: saved)
        precondition(restored.tasks == state.tasks && restored.priorityID == state.priorityID)
        do { _ = try PlanLogic.importReport(Data("broken".utf8), into: &state); fatalError("Accepted corrupt data") }
        catch { precondition(state.tasks.count == 1) }
        try recurrenceChecks()
        print("Passed: date parsing, workload, imports, persistence, old-data migration, weekly recurrence, exceptions, restoration, cross-week drag, deadlines, overlap lanes, overnight events, and end dates.")
    }
    static func recurrenceChecks() throws {
        let legacy = try JSONDecoder().decode(PlannerData.self, from: Data(#"{"tasks":[],"priorityID":null}"#.utf8))
        precondition(legacy.arrangements.isEmpty && legacy.exceptions.isEmpty)
        let monday = PlanLogic.date("2026-11-16T00:00:00")!
        let nextMonday = PlanLogic.calendar.date(byAdding: .day, value: 7, to: monday)!
        let thisWeek = DateInterval(start: monday, end: nextMonday)
        let nextWeek = DateInterval(start: nextMonday, end: PlanLogic.calendar.date(byAdding: .day, value: 7, to: nextMonday)!)
        precondition(PlanLogic.weekStart(PlanLogic.date("2026-11-22T23:59:00")!) == monday)
        var data = PlannerData()
        let series = RegularArrangement(title: "Night study", weekday: 3, startMinute: 17 * 60,
                                        minutes: 180, startDate: monday)
        data.arrangements = [series]
        let regular = PlanLogic.entries(in: thisWeek, data: data)
        precondition(regular.count == 1 && regular[0].start == PlanLogic.date("2026-11-17T17:00:00")!)
        let token = regular[0].dragToken
        let changedStart = PlanLogic.date("2026-11-25T18:15:00")!
        precondition(PlanLogic.move(token, to: changedStart, data: &data))
        let originals = PlanLogic.entries(in: thisWeek, data: data)
        precondition(originals.count == 1 && originals[0].kind == .movedOriginal)
        let following = PlanLogic.entries(in: nextWeek, data: data)
        precondition(following.count == 2)
        precondition(following.contains { $0.start == changedStart && $0.kind == .changed })
        precondition(following.contains { $0.originalDay == "2026-11-24" && $0.kind == .regular })
        // Moving a changed instance edits its override instead of adding another instance.
        precondition(PlanLogic.move(token, to: changedStart.addingTimeInterval(900), data: &data))
        precondition(data.exceptions.count == 1)
        var skipped = data.exceptions[0]; skipped.skipped = true
        PlanLogic.setException(skipped, data: &data)
        precondition(PlanLogic.entries(in: thisWeek, data: data)[0].kind == .skipped)
        precondition(PlanLogic.entries(in: nextWeek, data: data).count == 1)
        precondition(!PlanLogic.move(token, to: changedStart, data: &data))
        data.exceptions = []
        precondition(PlanLogic.entries(in: thisWeek, data: data)[0].kind == .regular)
        let task = PlanTask(title: "Report", due: changedStart, planned: nil, minutes: 60)
        data.tasks = [task]
        precondition(PlanLogic.move("task/" + task.id, to: regular[0].start, data: &data))
        precondition(data.tasks[0].due == changedStart)
        precondition(!PlanLogic.move("unknown/123", to: changedStart, data: &data))
        let entries = PlanLogic.entries(in: thisWeek, data: data)
        let lanes = PlanLogic.placements(entries, on: regular[0].start)
        precondition(lanes.count == 2 && lanes.allSatisfy { $0.laneCount == 2 })
        precondition(Set(lanes.map(\.lane)).count == 2)
        data.arrangements[0].endDate = PlanLogic.date("2026-11-17T00:00:00")!
        precondition(PlanLogic.entries(in: nextWeek, data: data).isEmpty)
        precondition(PlanLogic.entries(in: thisWeek, data: data).count == 2)
        var overnight = task
        overnight.planned = PlanLogic.date("2026-11-18T23:30:00")!; overnight.minutes = 120
        data.tasks = [overnight]; data.arrangements = []
        let thursday = PlanLogic.date("2026-11-19T00:00:00")!
        let overnightEntries = PlanLogic.entries(in: PlanLogic.dayInterval(thursday), data: data)
        let overnightLayout = PlanLogic.placements(overnightEntries, on: thursday)
        precondition(overnightLayout.count == 1 && overnightLayout[0].startMinute == 0 && overnightLayout[0].endMinute == 90)
        data.arrangements = [series]
        precondition(PlanLogic.move(token, to: changedStart, data: &data))
        let restored = try JSONDecoder().decode(PlannerData.self, from: JSONEncoder().encode(data))
        precondition(restored.arrangements == data.arrangements && restored.exceptions == data.exceptions)
        precondition(PlanLogic.entries(in: nextWeek, data: restored).contains { $0.kind == .changed })
    }
    static func tryImport(_ data: Data, into state: inout PlannerData) -> Int {
        do { return try PlanLogic.importReport(data, into: &state) }
        catch { fatalError("Import failed: \(error)") }
    }
}
