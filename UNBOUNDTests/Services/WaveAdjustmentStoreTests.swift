import XCTest
@testable import UNBOUND

final class WaveAdjustmentStoreTests: XCTestCase {
    func testMarkRevertedPersistsPerUserAndProgram() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WaveAdjustmentStore(directory: directory)

        store.markReverted("arc-1:wave2:start:3", userId: "user-1", programId: "program-1")
        store.markReverted("arc-1:wave2:start:4", userId: "user-1", programId: "program-1")
        store.markReverted("arc-2:wave2:start:1", userId: "user-1", programId: "program-2")

        let reloaded = WaveAdjustmentStore(directory: directory)

        XCTAssertEqual(
            reloaded.revertedAdjustmentIDs(userId: "user-1", programId: "program-1"),
            ["arc-1:wave2:start:3", "arc-1:wave2:start:4"]
        )
        XCTAssertEqual(
            reloaded.revertedAdjustmentIDs(userId: "user-1", programId: "program-2"),
            ["arc-2:wave2:start:1"]
        )
    }

    func testClearRemovesOnlyMatchingRecord() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WaveAdjustmentStore(directory: directory)

        store.markReverted("a", userId: "user-1", programId: "program-1")
        store.markReverted("b", userId: "user-1", programId: "program-2")
        store.clear(userId: "user-1", programId: "program-1")

        XCTAssertTrue(store.revertedAdjustmentIDs(userId: "user-1", programId: "program-1").isEmpty)
        XCTAssertEqual(store.revertedAdjustmentIDs(userId: "user-1", programId: "program-2"), ["b"])
    }
}

final class ProgramTrainingContextStoreTests: XCTestCase {
    func testTodayOnlyContextPersistsForOneDay() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let today = date(year: 2026, month: 6, day: 5, calendar: calendar)
        let tomorrow = date(year: 2026, month: 6, day: 6, calendar: calendar)

        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .todayOnly,
                mode: .calisthenics,
                equipment: [.bodyweight, .pullupBar]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: today,
            calendar: calendar
        )

        let reloaded = ProgramTrainingContextStore(directory: directory)
        XCTAssertEqual(
            reloaded.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: today,
                calendar: calendar
            )?.selection.mode,
            .calisthenics
        )
        XCTAssertNil(
            reloaded.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: tomorrow,
                calendar: calendar
            )
        )
    }

    func testThisWeekContextAppliesAcrossCalendarWeek() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let friday = date(year: 2026, month: 6, day: 5, calendar: calendar)
        let sunday = date(year: 2026, month: 6, day: 7, calendar: calendar)
        let nextMonday = date(year: 2026, month: 6, day: 8, calendar: calendar)

        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .thisWeek,
                mode: .lifting,
                equipment: [.dumbbells, .bench]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: friday,
            calendar: calendar
        )

        XCTAssertEqual(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: sunday,
                calendar: calendar
            )?.selection.mode,
            .lifting
        )
        XCTAssertNil(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: nextMonday,
                calendar: calendar
            )
        )
    }

    func testTodayContextWinsOverWeekEvenWhenWeekIsSavedLater() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let friday = date(year: 2026, month: 6, day: 5, calendar: calendar)
        let saturday = date(year: 2026, month: 6, day: 6, calendar: calendar)

        let today = store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .todayOnly,
                mode: .calisthenics,
                equipment: [.bodyweight, .pullupBar]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: friday,
            calendar: calendar
        )
        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .thisWeek,
                mode: .lifting,
                equipment: [.barbell, .dumbbells, .bench]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: friday,
            calendar: calendar
        )

        XCTAssertEqual(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: friday,
                calendar: calendar
            )?.id,
            today.id
        )
        XCTAssertEqual(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: saturday,
                calendar: calendar
            )?.selection.mode,
            .lifting
        )
    }

    func testClearingTodayRevealsUnderlyingWeekContext() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let friday = date(year: 2026, month: 6, day: 5, calendar: calendar)

        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .thisWeek,
                mode: .lifting,
                equipment: [.barbell, .dumbbells, .bench]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: friday,
            calendar: calendar
        )
        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .todayOnly,
                mode: .calisthenics,
                equipment: [.bodyweight, .bands]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: friday,
            calendar: calendar
        )

        XCTAssertTrue(
            store.clearActiveDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: friday,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: friday,
                calendar: calendar
            )?.selection.mode,
            .lifting
        )
    }

    func testPendingNextBlockContextReplacesAndConsumes() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)

        store.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .calisthenics,
                equipment: [.bodyweight, .rings]
            ),
            userId: "user-1",
            programId: "program-1"
        )
        store.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .machines,
                equipment: [.machines]
            ),
            userId: "user-1",
            programId: "program-1"
        )

        XCTAssertEqual(
            store.pendingNextBlockContext(userId: "user-1", programId: "program-1")?.selection.mode,
            .machines
        )

        store.consumePendingNextBlockContext(userId: "user-1", programId: "program-1")

        XCTAssertNil(store.pendingNextBlockContext(userId: "user-1", programId: "program-1"))
    }

    func testClearActiveDailyContextPreservesPendingNextBlockQueue() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let today = date(year: 2026, month: 6, day: 5, calendar: calendar)

        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .thisWeek,
                mode: .calisthenics,
                equipment: [.bodyweight, .bands]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: today,
            calendar: calendar
        )
        store.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .lifting,
                equipment: [.barbell, .dumbbells, .bench]
            ),
            userId: "user-1",
            programId: "program-1"
        )

        XCTAssertTrue(
            store.clearActiveDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: today,
                calendar: calendar
            )
        )

        XCTAssertNil(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: today,
                calendar: calendar
            )
        )
        XCTAssertEqual(
            store.pendingNextBlockContext(userId: "user-1", programId: "program-1")?.selection.mode,
            .lifting
        )
    }

    func testClearActiveDailyContextReturnsFalseWhenOnlyPendingExists() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let today = date(year: 2026, month: 6, day: 5, calendar: calendar)

        store.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .lifting,
                equipment: [.barbell, .dumbbells, .bench]
            ),
            userId: "user-1",
            programId: "program-1"
        )

        XCTAssertFalse(
            store.clearActiveDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: today,
                calendar: calendar
            )
        )
        XCTAssertNotNil(store.pendingNextBlockContext(userId: "user-1", programId: "program-1"))
    }

    func testClearPendingNextBlockPreservesDailyContext() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgramTrainingContextStore(directory: directory)
        let calendar = gregorianCalendar
        let today = date(year: 2026, month: 6, day: 5, calendar: calendar)

        store.saveDailyContext(
            selection: ProgramTrainingContextSelection(
                scope: .todayOnly,
                mode: .calisthenics,
                equipment: [.bodyweight, .pullupBar]
            ),
            userId: "user-1",
            programId: "program-1",
            anchorDate: today,
            calendar: calendar
        )
        store.savePendingNextBlockContext(
            selection: ProgramTrainingContextSelection(
                scope: .nextBlock,
                mode: .machines,
                equipment: [.machines]
            ),
            userId: "user-1",
            programId: "program-1"
        )

        XCTAssertTrue(store.clearPendingNextBlockContext(userId: "user-1", programId: "program-1"))

        XCTAssertNil(store.pendingNextBlockContext(userId: "user-1", programId: "program-1"))
        XCTAssertEqual(
            store.activeDailyContext(
                userId: "user-1",
                programId: "program-1",
                date: today,
                calendar: calendar
            )?.selection.mode,
            .calisthenics
        )
    }

    private var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
