import XCTest
@testable import DeskTodoBuddy

@MainActor
final class TodoStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDesktopBuddyTests-\(UUID().uuidString)", isDirectory: true)
        AppPaths.supportDirectoryOverride = temporaryDirectory
        AppPreferences.remindedTodoIDs = []
        AppPreferences.iconWindowOrigin = nil
        AppPreferences.isIconHidden = false
    }

    override func tearDown() async throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        AppPaths.supportDirectoryOverride = nil
        AppPreferences.remindedTodoIDs = []
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testAddTrimsTitleAndIgnoresEmptyInput() {
        let store = TodoStore()

        store.add(title: "  写测试  ", reminderDate: nil)
        store.add(title: "   ", reminderDate: nil)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.title, "写测试")
    }

    func testToggleDoneClearsReminderAndMarksItemReminded() throws {
        let reminder = Date().addingTimeInterval(300)
        let store = TodoStore()
        store.add(title: "带提醒的任务", reminderDate: reminder)
        let item = try XCTUnwrap(store.items.first)

        store.toggle(item)

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertTrue(updated.isDone)
        XCTAssertNil(updated.reminderDate)
        XCTAssertTrue(AppPreferences.remindedTodoIDs.contains(updated.id))
    }

    func testToggleUndoneClearsRemindedMarker() throws {
        let store = TodoStore()
        store.add(title: "恢复任务", reminderDate: nil)
        let item = try XCTUnwrap(store.items.first)

        store.toggle(item)
        let doneItem = try XCTUnwrap(store.items.first)
        store.toggle(doneItem)

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertFalse(updated.isDone)
        XCTAssertFalse(AppPreferences.remindedTodoIDs.contains(updated.id))
    }

    func testUpdateReminderClearsRemindedMarkerSoRescheduledItemCanFire() throws {
        let store = TodoStore()
        store.add(title: "重新设置提醒", reminderDate: nil)
        let item = try XCTUnwrap(store.items.first)
        AppPreferences.remindedTodoIDs.insert(item.id)

        let newReminder = Date().addingTimeInterval(600)
        store.updateReminder(for: item, reminderDate: newReminder)

        let updated = try XCTUnwrap(store.items.first)
        XCTAssertEqual(updated.reminderDate, newReminder)
        XCTAssertFalse(AppPreferences.remindedTodoIDs.contains(item.id))
    }

    func testDueItemsExcludeCompletedItemsAndFutureReminders() throws {
        let now = Date()
        let store = TodoStore()
        store.add(title: "到期", reminderDate: now.addingTimeInterval(-1))
        store.add(title: "未来", reminderDate: now.addingTimeInterval(60))
        store.add(title: "无提醒", reminderDate: nil)

        let due = store.dueItems(now: now)

        XCTAssertEqual(due.map(\.title), ["到期"])
    }

    func testPersistenceRoundTripLoadsSavedItems() {
        let firstStore = TodoStore()
        firstStore.add(title: "持久化任务", reminderDate: nil)

        let secondStore = TodoStore()

        XCTAssertEqual(secondStore.items.count, 1)
        XCTAssertEqual(secondStore.items.first?.title, "持久化任务")
    }
}
