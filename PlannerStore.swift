import SwiftUI

enum PlannerEditor: Identifiable {
    case task(PlanTask), regular(RegularArrangement), occurrence(CalendarEntry)
    var id: String {
        switch self {
        case .task(let task): return "edit/" + task.id
        case .regular(let series): return "series/" + series.id
        case .occurrence(let entry): return "occurrence/" + entry.id
        }
    }
}

struct CompletionMoment: Identifiable {
    let id = UUID()
    let title: String
}

@MainActor
final class PlannerStore: ObservableObject {
    @Published var data = PlannerData()
    @Published var message: String?
    @Published var editor: PlannerEditor?
    @Published var jumpDate: Date?
    @Published var completion: CompletionMoment?
    @Published var desktopVisible: Bool = UserDefaults.standard.object(forKey: "todayCalendarVisible") as? Bool ?? true {
        didSet { UserDefaults.standard.set(desktopVisible, forKey: "todayCalendarVisible") }
    }
    private let file: URL
    private let completionDuration: TimeInterval
    private var readable = true

    init(directory: URL? = nil, completionDuration: TimeInterval = 2.2) {
        self.completionDuration = completionDuration
        let custom = ProcessInfo.processInfo.environment["FIELDNOTES_DATA_DIR"]
        let folder = directory ?? custom.map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Fieldnotes")
        file = folder.appendingPathComponent("planner.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do { data = try JSONDecoder().decode(PlannerData.self, from: Data(contentsOf: file)) }
            catch { readable = false; message = "Your saved planner could not be read. The original file has been preserved. \(error.localizedDescription)" }
        }
    }
    func save() {
        guard readable else { message = "Saving is paused because the existing planner file could not be read."; return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: file, options: .atomic)
        } catch { message = "Could not save your changes: \(error.localizedDescription)" }
    }
    private func celebrate(_ title: String) {
        let moment = CompletionMoment(title: title)
        completion = moment
        // The store owns expiration; view redraws and sheet transitions cannot restart it.
        DispatchQueue.main.asyncAfter(deadline: .now() + completionDuration) { [weak self] in
            guard let self, self.completion?.id == moment.id else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.completion = nil }
        }
    }
    func put(_ task: PlanTask) {
        let newlyCompleted = task.done && data.tasks.first(where: { $0.id == task.id })?.done != true
        if let index = data.tasks.firstIndex(where: { $0.id == task.id }) { data.tasks[index] = task }
        else { data.tasks.append(task) }
        save()
        if newlyCompleted { celebrate(task.title) }
    }
    func put(_ series: RegularArrangement) {
        if let index = data.arrangements.firstIndex(where: { $0.id == series.id }) { data.arrangements[index] = series }
        else { data.arrangements.append(series) }
        save()
    }
    func toggle(_ task: PlanTask) { var copy = task; copy.done.toggle(); put(copy) }
    func prioritize(_ task: PlanTask) { data.priorityID = data.priorityID == task.id ? nil : task.id; save() }
    func remove(_ task: PlanTask) {
        data.tasks.removeAll { $0.id == task.id }
        if data.priorityID == task.id { data.priorityID = nil }
        save()
    }
    func remove(_ series: RegularArrangement) {
        data.arrangements.removeAll { $0.id == series.id }
        data.exceptions.removeAll { $0.seriesID == series.id }
        save()
    }
    func change(_ exception: ArrangementException) {
        let newlyCompleted = exception.done && !exception.skipped && data.exceptions.first(where: { $0.id == exception.id })?.done != true
        PlanLogic.setException(exception, data: &data); save()
        if newlyCompleted {
            celebrate(exception.title ?? data.arrangements.first(where: { $0.id == exception.seriesID })?.title ?? "Arrangement")
        }
    }
    func restore(_ entry: CalendarEntry) {
        data.exceptions.removeAll { $0.seriesID == entry.seriesID && $0.originalDay == entry.originalDay }; save()
    }
    func move(_ token: String, to date: Date) -> Bool {
        guard PlanLogic.move(token, to: date, data: &data) else { return false }
        save(); return true
    }
    func edit(_ entry: CalendarEntry) {
        if let id = entry.taskID, let task = data.tasks.first(where: { $0.id == id }) { editor = .task(task) }
        else { editor = .occurrence(entry) }
    }
    func importSchool() {
        let report = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/作业速览/reports/latest.json")
        do {
            let added = try PlanLogic.importReport(Data(contentsOf: report), into: &data)
            save()
            if message == nil { message = "Imported \(added) new assignments and refreshed matching deadlines. Drag tasks from the list into the calendar to plan them. Sync 作业速览 first for current records; completion here does not submit schoolwork." }
        } catch { message = "Could not import school assignments. Open 作业速览 and sync first. \(error.localizedDescription)" }
    }
    var pending: [PlanTask] {
        data.tasks.filter { !$0.done }.sorted {
            if $0.due != $1.due { return ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}

