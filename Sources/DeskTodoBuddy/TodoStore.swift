import Foundation

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published var lastError: String?

    var onItemsChanged: (([TodoItem]) -> Void)?

    init() {
        load()
    }

    var activeItems: [TodoItem] {
        sorted(items.filter { !$0.isDone })
    }

    var completedItems: [TodoItem] {
        sorted(items.filter(\.isDone))
    }

    func add(title: String, reminderDate: Date?) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let item = TodoItem(title: normalized, reminderDate: reminderDate)
        items.append(item)
        AppPreferences.remindedTodoIDs.remove(item.id)
        persistAndNotify()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        if items[index].isDone {
            items[index].reminderDate = nil
            AppPreferences.remindedTodoIDs.insert(items[index].id)
        } else {
            AppPreferences.remindedTodoIDs.remove(items[index].id)
        }
        persistAndNotify()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        AppPreferences.remindedTodoIDs.remove(item.id)
        persistAndNotify()
    }

    func updateTitle(for item: TodoItem, title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard items[index].title != normalized else { return }
        items[index].title = normalized
        persistAndNotify()
    }

    func updateReminder(for item: TodoItem, reminderDate: Date?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].reminderDate = reminderDate
        AppPreferences.remindedTodoIDs.remove(item.id)
        persistAndNotify()
    }

    func dueItems(now: Date = Date()) -> [TodoItem] {
        sorted(items.filter { item in
            guard let reminderDate = item.reminderDate, !item.isDone else { return false }
            return reminderDate <= now
        })
    }

    private func sorted(_ source: [TodoItem]) -> [TodoItem] {
        source.sorted { lhs, rhs in
            switch (lhs.reminderDate, rhs.reminderDate) {
            case let (left?, right?):
                if left != right { return left < right }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func load() {
        do {
            let url = AppPaths.todosURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                items = []
                return
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([TodoItem].self, from: data)
        } catch {
            lastError = "读取待办失败：\(error.localizedDescription)"
            items = []
        }
    }

    private func persistAndNotify() {
        save()
        onItemsChanged?(items)
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: AppPaths.supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: AppPaths.todosURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "保存待办失败：\(error.localizedDescription)"
        }
    }
}
