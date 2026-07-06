import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var createdAt: Date
    var reminderDate: Date?
    var isDone: Bool

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        createdAt: Date = Date(),
        reminderDate: Date? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.reminderDate = reminderDate
        self.isDone = isDone
    }
}

struct BuddyMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let createdAt = Date()
}

enum AppPaths {
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DeskTodoBuddy", isDirectory: true)
    }

    static var todosURL: URL {
        supportDirectory.appendingPathComponent("todos.json")
    }
}

enum AppPreferences {
    private enum Keys {
        static let iconWindowOrigin = "iconWindowOrigin"
        static let isIconHidden = "isIconHidden"
        static let remindedTodoIDs = "remindedTodoIDs"
    }

    static var iconWindowOrigin: NSPoint? {
        get {
            let value = UserDefaults.standard.string(forKey: Keys.iconWindowOrigin) ?? ""
            guard !value.isEmpty else { return nil }
            return NSPointFromString(value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(NSStringFromPoint(newValue), forKey: Keys.iconWindowOrigin)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.iconWindowOrigin)
            }
        }
    }

    static var isIconHidden: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isIconHidden) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.isIconHidden) }
    }

    static var remindedTodoIDs: Set<UUID> {
        get {
            let values = UserDefaults.standard.stringArray(forKey: Keys.remindedTodoIDs) ?? []
            return Set(values.compactMap(UUID.init(uuidString:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.uuidString), forKey: Keys.remindedTodoIDs)
        }
    }
}
