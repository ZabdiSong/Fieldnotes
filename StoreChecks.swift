import Foundation

@main
enum StoreChecks {
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("fieldnotes-store-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PlannerStore(directory: folder, completionDuration: 0.15)
        var first = PlanTask(title: "Completion timeout test")
        store.put(first)
        precondition(store.completion == nil)
        first.done = true
        store.put(first)
        precondition(store.completion?.title == first.title)
        try await Task.sleep(nanoseconds: 250_000_000)
        precondition(store.completion == nil, "Completion banner failed to expire")
        store.put(first)
        precondition(store.completion == nil, "Saving a completed task replayed the animation")

        first.done = false; store.put(first)
        first.done = true; store.put(first)
        try await Task.sleep(nanoseconds: 100_000_000)
        let second = PlanTask(title: "Newer completion", done: true)
        store.put(second)
        let newerID = store.completion!.id
        try await Task.sleep(nanoseconds: 90_000_000)
        precondition(store.completion?.id == newerID, "Older expiry cleared a newer completion")
        try await Task.sleep(nanoseconds: 150_000_000)
        precondition(store.completion == nil)
        let reopened = PlannerStore(directory: folder)
        precondition(reopened.completion == nil && reopened.data.tasks.count == 2)
        print("Passed: automatic banner dismissal, rapid completions, no replay on save, and persistence without transient banners.")
    }
}
