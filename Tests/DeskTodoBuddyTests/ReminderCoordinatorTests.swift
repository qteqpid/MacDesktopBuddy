import XCTest
@testable import DeskTodoBuddy

@MainActor
final class ReminderCoordinatorTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDesktopBuddyReminderTests-\(UUID().uuidString)", isDirectory: true)
        AppPaths.supportDirectoryOverride = temporaryDirectory
        AppPreferences.remindedTodoIDs = []
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

    func testDueTaskReminderReturnsFreshDueItemAndMarksItReminded() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let store = TodoStore()
        store.add(title: "喝水", reminderDate: now.addingTimeInterval(-20))
        let item = try XCTUnwrap(store.items.first)
        let coordinator = ReminderCoordinator(store: store, autoStart: false)

        let reminder = coordinator.dueTaskReminder(now: now)

        XCTAssertEqual(reminder, "喝水")
        XCTAssertTrue(AppPreferences.remindedTodoIDs.contains(item.id))
    }

    func testStaleDueTaskReminderDoesNotWritePermanentRemindedMarker() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let store = TodoStore()
        store.add(title: "旧提醒", reminderDate: now.addingTimeInterval(-121))
        let item = try XCTUnwrap(store.items.first)
        let coordinator = ReminderCoordinator(store: store, autoStart: false)

        let reminder = coordinator.dueTaskReminder(now: now)

        XCTAssertNil(reminder)
        XCTAssertFalse(AppPreferences.remindedTodoIDs.contains(item.id))
    }
}
