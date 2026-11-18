import Foundation

struct RegularArrangement: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title = ""
    var subject = "Personal"
    var nextStep = ""
    var weekday = 3 // Calendar: Sunday = 1, Tuesday = 3.
    var startMinute = 17 * 60
    var minutes = 120
    var startDate = PlanLogic.calendar.startOfDay(for: Date())
    var endDate: Date? = nil
}

struct ArrangementException: Codable, Identifiable, Equatable {
    var seriesID: String
    var originalDay: String
    var skipped = false
    var replacementStart: Date? = nil
    var title: String? = nil
    var nextStep: String? = nil
    var minutes: Int? = nil
    var done = false
    var id: String { seriesID + "/" + originalDay }
    var isChanged: Bool { replacementStart != nil || title != nil || nextStep != nil || minutes != nil }
}

struct CalendarEntry: Identifiable, Equatable {
    enum Kind { case task, regular, changed, movedOriginal, skipped }
    var id: String
    var title: String
    var subject: String
    var nextStep: String
    var start: Date
    var minutes: Int
    var done: Bool
    var kind: Kind
    var taskID: String? = nil
    var seriesID: String? = nil
    var originalDay: String? = nil
    var end: Date { start.addingTimeInterval(Double(minutes) * 60) }
    var crossedOut: Bool { kind == .movedOriginal || kind == .skipped }
    var dragToken: String {
        if let taskID { return "task/" + taskID }
        return "regular/" + (seriesID ?? "") + "/" + (originalDay ?? "")
    }
    var badge: String {
        switch kind {
        case .task: return done ? "Done" : "Task"
        case .regular: return done ? "Done · weekly" : "Weekly"
        case .changed: return done ? "Done · exception" : "This date only"
        case .movedOriginal: return "Changed · original"
        case .skipped: return "Skipped this date"
        }
    }
}

struct CalendarPlacement: Identifiable {
    let entry: CalendarEntry
    let startMinute: Double
    let endMinute: Double
    var lane: Int
    var laneCount: Int
    var id: String { entry.id }
}

extension PlanLogic {
    static func dayKey(_ date: Date) -> String { label(date, format: "yyyy-MM-dd") }
    static func dayDate(_ key: String) -> Date? { date(key + "T00:00:00") }
    static func weekStart(_ date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)!
    }
    static func atMinute(_ minute: Int, on day: Date) -> Date {
        calendar.startOfDay(for: day).addingTimeInterval(Double(minute) * 60)
    }
    static func matches(_ series: RegularArrangement, day: Date) -> Bool {
        let day = calendar.startOfDay(for: day)
        return calendar.component(.weekday, from: day) == series.weekday
            && day >= calendar.startOfDay(for: series.startDate)
            && (series.endDate.map { day <= calendar.startOfDay(for: $0) } ?? true)
    }
    static func entries(in interval: DateInterval, data: PlannerData) -> [CalendarEntry] {
        var result: [CalendarEntry] = []
        func overlaps(_ entry: CalendarEntry) -> Bool { entry.start < interval.end && entry.end > interval.start }
        for task in data.tasks {
            guard let start = task.planned else { continue }
            let entry = CalendarEntry(id: "task/" + task.id, title: task.title, subject: task.subject,
                nextStep: task.nextStep, start: start, minutes: task.minutes, done: task.done, kind: .task, taskID: task.id)
            if overlaps(entry) { result.append(entry) }
        }
        let changes = Dictionary(data.exceptions.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for series in data.arrangements {
            var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: interval.start))!
            while day < interval.end {
                defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
                guard matches(series, day: day) else { continue }
                let key = dayKey(day)
                let change = changes[series.id + "/" + key]
                var entry = CalendarEntry(id: "regular/" + series.id + "/" + key,
                    title: series.title, subject: series.subject, nextStep: series.nextStep,
                    start: atMinute(series.startMinute, on: day), minutes: series.minutes,
                    done: change?.done ?? false, kind: .regular, seriesID: series.id, originalDay: key)
                if change?.skipped == true { entry.kind = .skipped; entry.done = false }
                else if change?.isChanged == true { entry.kind = .movedOriginal; entry.done = false }
                if overlaps(entry) { result.append(entry) }
            }
            // Iterate overrides separately: an occurrence can be moved into this week from any other week.
            for change in data.exceptions where change.seriesID == series.id && !change.skipped && change.isChanged {
                guard let original = dayDate(change.originalDay) else { continue }
                let entry = CalendarEntry(id: "exception/" + change.id,
                    title: change.title ?? series.title, subject: series.subject,
                    nextStep: change.nextStep ?? series.nextStep,
                    start: change.replacementStart ?? atMinute(series.startMinute, on: original),
                    minutes: change.minutes ?? series.minutes, done: change.done, kind: .changed,
                    seriesID: series.id, originalDay: change.originalDay)
                if overlaps(entry) { result.append(entry) }
            }
        }
        return result.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }
    static func dayInterval(_ day: Date) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!)
    }
    static func setException(_ change: ArrangementException, data: inout PlannerData) {
        data.exceptions.removeAll { $0.id == change.id }
        data.exceptions.append(change)
    }
    @discardableResult
    static func move(_ token: String, to date: Date, data: inout PlannerData) -> Bool {
        let parts = token.split(separator: "/").map(String.init)
        if parts.count == 2 && parts[0] == "task", let index = data.tasks.firstIndex(where: { $0.id == parts[1] }) {
            data.tasks[index].planned = date
            return true
        }
        if parts.count == 3 && parts[0] == "regular",
           let series = data.arrangements.first(where: { $0.id == parts[1] }),
           let original = dayDate(parts[2]), matches(series, day: original) || data.exceptions.contains(where: { $0.id == parts[1] + "/" + parts[2] }) {
            var change = data.exceptions.first { $0.id == parts[1] + "/" + parts[2] }
                ?? ArrangementException(seriesID: parts[1], originalDay: parts[2])
            guard !change.skipped else { return false }
            change.replacementStart = date
            setException(change, data: &data)
            return true
        }
        return false
    }
    static func placements(_ entries: [CalendarEntry], on day: Date) -> [CalendarPlacement] {
        let interval = dayInterval(day)
        let items = entries.filter { $0.start < interval.end && $0.end > interval.start }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
        var result: [CalendarPlacement] = []
        var laneEnds: [Date] = []
        var clusterStart = 0
        var clusterEnd = Date.distantPast
        func finishCluster() {
            guard clusterStart < result.count else { return }
            for i in clusterStart..<result.count { result[i].laneCount = laneEnds.count }
        }
        for entry in items {
            // Reserve a minimum visible slot for short events so their labels do not overlap.
            let visualEnd = max(entry.end, entry.start.addingTimeInterval(30 * 60))
            if entry.start >= clusterEnd {
                finishCluster(); clusterStart = result.count; laneEnds = []
            }
            let lane = laneEnds.firstIndex { $0 <= entry.start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(visualEnd) } else { laneEnds[lane] = visualEnd }
            clusterEnd = max(clusterEnd, visualEnd)
            result.append(CalendarPlacement(entry: entry,
                startMinute: max(0, entry.start.timeIntervalSince(interval.start) / 60),
                endMinute: min(1440, entry.end.timeIntervalSince(interval.start) / 60), lane: lane, laneCount: 1))
        }
        finishCluster()
        return result
    }
}
