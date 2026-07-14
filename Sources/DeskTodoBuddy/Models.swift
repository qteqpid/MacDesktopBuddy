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

enum ReminderTiming {
    static let taskReminderGracePeriod: TimeInterval = 2 * 60

    static func normalizedBreakInterval(_ minutes: Int) -> Int {
        min(max(minutes, 15), 120)
    }

    static func customReminderDate(from selection: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let rounded = selection.removingSeconds(calendar: calendar)
        guard rounded <= now else { return rounded }
        return calendar.date(byAdding: .minute, value: 1, to: now.removingSeconds(calendar: calendar)) ?? selection
    }

    static func shouldDeliverTaskReminder(now: Date, reminderDate: Date, gracePeriod: TimeInterval = taskReminderGracePeriod) -> Bool {
        reminderDate <= now && now.timeIntervalSince(reminderDate) <= gracePeriod
    }
}

extension Date {
    func removingSeconds(calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return calendar.date(from: components) ?? self
    }
}

enum AppPaths {
    static var supportDirectoryOverride: URL?

    static var supportDirectory: URL {
        if let supportDirectoryOverride {
            return supportDirectoryOverride
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DeskTodoBuddy", isDirectory: true)
    }

    static var todosURL: URL {
        supportDirectory.appendingPathComponent("todos.json")
    }

    static var customLogoURL: URL {
        supportDirectory.appendingPathComponent("custom-logo.png")
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
