import XCTest
@testable import DeskTodoBuddy

final class ReminderTimingTests: XCTestCase {
    func testCustomReminderDateDropsSecondsForFutureSelection() throws {
        let calendar = gregorianShanghaiCalendar()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 15, minute: 8, second: 8)))
        let selection = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 15, minute: 16, second: 42)))

        let result = ReminderTiming.customReminderDate(from: selection, now: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: result), 15)
        XCTAssertEqual(calendar.component(.minute, from: result), 16)
        XCTAssertEqual(calendar.component(.second, from: result), 0)
    }

    func testCustomReminderDateMovesCurrentOrPastMinuteToNextMinute() throws {
        let calendar = gregorianShanghaiCalendar()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 15, minute: 8, second: 52)))
        let selection = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 15, minute: 8, second: 0)))

        let result = ReminderTiming.customReminderDate(from: selection, now: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: result), 15)
        XCTAssertEqual(calendar.component(.minute, from: result), 9)
        XCTAssertEqual(calendar.component(.second, from: result), 0)
    }

    func testCustomReminderDateMovesEarlierSameDaySelectionToNextMinute() throws {
        let calendar = gregorianShanghaiCalendar()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 19, minute: 20, second: 8)))
        let selection = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 19, minute: 16, second: 0)))

        let result = ReminderTiming.customReminderDate(from: selection, now: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.year, from: result), 2026)
        XCTAssertEqual(calendar.component(.month, from: result), 7)
        XCTAssertEqual(calendar.component(.day, from: result), 6)
        XCTAssertEqual(calendar.component(.hour, from: result), 19)
        XCTAssertEqual(calendar.component(.minute, from: result), 21)
        XCTAssertEqual(calendar.component(.second, from: result), 0)
    }

    func testTaskReminderDeliveryWindowAllowsOnlyDueItemsWithinTwoMinutes() throws {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(ReminderTiming.shouldDeliverTaskReminder(now: now, reminderDate: now.addingTimeInterval(-119)))
        XCTAssertTrue(ReminderTiming.shouldDeliverTaskReminder(now: now, reminderDate: now.addingTimeInterval(-120)))
        XCTAssertFalse(ReminderTiming.shouldDeliverTaskReminder(now: now, reminderDate: now.addingTimeInterval(-121)))
        XCTAssertFalse(ReminderTiming.shouldDeliverTaskReminder(now: now, reminderDate: now.addingTimeInterval(1)))
    }

    func testBreakIntervalIsClampedToSupportedRange() {
        XCTAssertEqual(ReminderTiming.normalizedBreakInterval(1), 15)
        XCTAssertEqual(ReminderTiming.normalizedBreakInterval(15), 15)
        XCTAssertEqual(ReminderTiming.normalizedBreakInterval(50), 50)
        XCTAssertEqual(ReminderTiming.normalizedBreakInterval(120), 120)
        XCTAssertEqual(ReminderTiming.normalizedBreakInterval(500), 120)
    }

    private func gregorianShanghaiCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
}
