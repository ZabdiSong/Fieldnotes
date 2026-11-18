import Foundation

struct PlanTask: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title = ""
    var subject = "Biology"
    var nextStep = ""
    var due: Date? = nil
    var planned: Date? = nil
    var minutes = 30
    var done = false
    var sourceID: String? = nil
}

struct PlannerData: Codable {
    var tasks: [PlanTask] = []
    var priorityID: String? = nil
    var arrangements: [RegularArrangement] = []
    var exceptions: [ArrangementException] = []

    init() {}
    private enum CodingKeys: String, CodingKey { case tasks, priorityID, arrangements, exceptions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decodeIfPresent([PlanTask].self, forKey: .tasks) ?? []
        priorityID = try c.decodeIfPresent(String.self, forKey: .priorityID)
        arrangements = try c.decodeIfPresent([RegularArrangement].self, forKey: .arrangements) ?? []
        exceptions = try c.decodeIfPresent([ArrangementException].self, forKey: .exceptions) ?? []
    }
}

enum PlanLogic {
    static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return result
    }
    static func days(from date: Date) -> [Date] {
        let start = calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    static func workload(_ tasks: [PlanTask], day: Date) -> Int {
        tasks.filter { !$0.done && $0.planned.map { calendar.isDate($0, inSameDayAs: day) } == true }
            .reduce(0) { $0 + $1.minutes }
    }
    static func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        // The school's cached report uses timezone-free Beijing timestamps.
        let localPattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$"#
        let normalized = text.range(of: localPattern, options: .regularExpression) == nil ? text : text + "+08:00"
        let format = ISO8601DateFormatter()
        if let value = format.date(from: normalized) { return value }
        format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return format.date(from: normalized)
    }
    static func label(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    static func importReport(_ data: Data, into state: inout PlannerData) throws -> Int {
        struct Report: Decodable { let tasks: [SchoolTask] }
        struct SchoolTask: Decodable {
            let id: String
            let title: String
            let subject: String
            let due: String?
            let kind: String?
            let status: String?
            let submission_closed: Bool?
            let submissionState: String?
            let hasGrade: Bool

            enum CodingKeys: String, CodingKey {
                case id, title, subject, due, kind, status, submission_closed, submission_state, grade
            }
            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                id = try values.decode(String.self, forKey: .id)
                title = try values.decode(String.self, forKey: .title)
                subject = try values.decode(String.self, forKey: .subject)
                due = try values.decodeIfPresent(String.self, forKey: .due)
                kind = try values.decodeIfPresent(String.self, forKey: .kind)
                status = try values.decodeIfPresent(String.self, forKey: .status)
                submission_closed = try values.decodeIfPresent(Bool.self, forKey: .submission_closed)
                submissionState = (try? values.decode(String.self, forKey: .submission_state))
                    ?? (try? values.decode(Int.self, forKey: .submission_state)).map(String.init)
                hasGrade = try values.contains(.grade) && !values.decodeNil(forKey: .grade)
            }

            var isPending: Bool {
                guard submission_closed != true, !hasGrade else { return false }
                let status = self.status ?? "状态未知"
                if status == "状态未知", ["3", "4", "5"].contains(submissionState ?? "") { return false }
                return ["待提交", "未完成", "状态未知", "待确认完成"].contains(status)
            }
        }
        let report = try JSONDecoder().decode(Report.self, from: data)
        var added = 0
        for item in report.tasks where ["assignment", "confirm"].contains(item.kind ?? "") {
            // Import only open items. School status never overwrites local completion or planning.
            guard item.isPending else { continue }
            if let index = state.tasks.firstIndex(where: { $0.sourceID == item.id }) {
                state.tasks[index].title = item.title
                state.tasks[index].subject = item.subject
                state.tasks[index].due = date(item.due)
            } else {
                state.tasks.append(PlanTask(title: item.title, subject: item.subject,
                    due: date(item.due), sourceID: item.id))
                added += 1
            }
        }
        return added
    }
}
