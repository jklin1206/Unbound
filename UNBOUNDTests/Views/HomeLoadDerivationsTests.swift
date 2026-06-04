import XCTest
@testable import UNBOUND

final class HomeLoadDerivationsTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        let c = cal()
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_weekSessionDays_mapsCurrentWeekToMondayIndex() {
        let now = date(2026, 5, 13)            // Wednesday
        let starts = [
            date(2026, 5, 11),                 // Mon  -> 1
            date(2026, 5, 13),                 // Wed  -> 3
            date(2026, 5, 17),                 // Sun  -> 7
            date(2026, 5, 8)                   // prev week -> excluded
        ]
        let days = HomeLoadDerivations.weekSessionDays(starts, now: now, calendar: cal())
        XCTAssertEqual(days, [1, 3, 7])
    }

    func test_weekSessionDays_empty() {
        XCTAssertEqual(
            HomeLoadDerivations.weekSessionDays([], now: date(2026, 5, 13), calendar: cal()),
            [])
    }

    func test_lastLog_and_hasLogged() {
        let logs: [WorkoutLog] = []
        XCTAssertNil(HomeLoadDerivations.lastLog(logs))
        XCTAssertFalse(HomeLoadDerivations.hasLogged(logs))
    }

    func test_bodyRegionLoads_mapsRecentLoggedSetsToCatalogRegions() {
        let now = date(2026, 5, 13)
        let logs = [
            log(
                startedAt: now,
                entries: [
                    entry("Bench Press", completedSets: 3, rpe: 8),
                    entry("Romanian Deadlift", plannedSets: 2, completedSets: 0)
                ]
            )
        ]

        let loads = HomeLoadDerivations.bodyRegionLoads(logs, now: now, calendar: cal())

        XCTAssertGreaterThan(loads[.chest] ?? 0, 0)
        XCTAssertGreaterThan(loads[.hamstrings] ?? 0, 0)
        XCTAssertGreaterThan(loads[.glutes] ?? 0, 0)
    }

    func test_bodyRegionLoads_ignoresLogsOutsideRecentWindow() {
        let now = date(2026, 5, 13)
        let logs = [
            log(startedAt: date(2026, 5, 4), entries: [entry("Bench Press", completedSets: 4)])
        ]

        let loads = HomeLoadDerivations.bodyRegionLoads(logs, now: now, calendar: cal())

        XCTAssertEqual(loads[.chest] ?? 0, 0, accuracy: 0.001)
    }

    private func log(startedAt: Date, entries: [ExerciseLogEntry]) -> WorkoutLog {
        WorkoutLog(
            id: UUID().uuidString,
            userId: "test-user",
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Test",
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(1800),
            exerciseEntries: entries,
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 30
        )
    }

    private func entry(_ name: String,
                       plannedSets: Int = 3,
                       completedSets: Int = 3,
                       rpe: Int? = nil,
                       skipped: Bool = false) -> ExerciseLogEntry {
        let loggedSets = completedSets > 0
            ? (1...completedSets).map { index in
                SetLog(
                    id: UUID().uuidString,
                    setNumber: index,
                    weightKg: nil,
                    reps: 8,
                    rpe: rpe,
                    isWarmup: false
                )
            }
            : []

        return ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: name,
            plannedSets: plannedSets,
            plannedReps: "8",
            sets: loggedSets,
            skipped: skipped,
            notes: nil
        )
    }
}
