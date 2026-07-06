import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("DeskTodoBuddy notification authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func schedule(items: [TodoItem]) {
        center.removeAllPendingNotificationRequests()

        let upcoming = items.filter { item in
            guard let reminderDate = item.reminderDate, !item.isDone else { return false }
            return reminderDate > Date()
        }

        for item in upcoming {
            guard let reminderDate = item.reminderDate else { continue }
            let content = UNMutableNotificationContent()
            content.title = "待办提醒"
            content.body = item.title
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: item),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func remove(item: TodoItem) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: item)])
    }

    private func notificationIdentifier(for item: TodoItem) -> String {
        "todo-\(item.id.uuidString)"
    }
}
