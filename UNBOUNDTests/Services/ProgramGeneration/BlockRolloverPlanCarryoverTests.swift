import XCTest
@testable import UNBOUND

/// Locks the rollover contract for user-authored plans: future plans re-key to
/// the new arc's program id, and a weekday the user repeatedly overrode gets
/// its workout stamped across the new arc — never overwriting explicit plans.
final class BlockRolloverPlanCarryoverTests: XCTestCase {
    private let calendar = Calendar.current
    private let userId = "user-1"
    private let oldProgramId = "program-old"
    private let newProgramId = "program-new"

    // Mon Jun 1 2026 → 30-day window Jun 1 ..< Jul 1.
    private var previousStart: Date { date(2026, 6, 1) }
    // Wed Jul 1 2026 → 30-day window Jul 1 ..< Jul 31.
    private var newStart: Date { date(2026, 7, 1) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func savedOccurrence(
        on date: Date,
        savedWorkoutId: UUID,
        title: String = "Push Day",
        programId: String? = "program-old"
    ) -> ProgramScheduleOccurrence {
        ProgramScheduleOccurrence(
            userId: userId,
            programId: programId,
            date: date,
            kind: .saved,
            title: title,
            savedWorkoutId: savedWorkoutId
        )
    }

    private func builtDraft(title: String) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: title,
            estimatedMinutes: 30,
            blocks: [TrainingBlock(kind: .strength, title: "Main Work", prescriptions: [])]
        )
    }

    private func plan(
        occurrences: [ProgramScheduleOccurrence],
        previousUserOwnedDays: [ProgramDay] = []
    ) -> BlockRolloverPlanCarryover.Plan {
        BlockRolloverPlanCarryover.plan(
            previousStart: previousStart,
            previousDurationDays: 30,
            previousUserOwnedDays: previousUserOwnedDays,
            previousProgramId: oldProgramId,
            occurrences: occurrences,
            userId: userId,
            newProgramId: newProgramId,
            newStart: newStart,
            newDurationDays: 30,
            calendar: calendar,
            now: newStart
        )
    }

    func testRepeatedWeekdayLoadoutStampsEveryMatchingDayOfNewArc() {
        let loadoutId = UUID()
        let result = plan(occurrences: [
            savedOccurrence(on: date(2026, 6, 8), savedWorkoutId: loadoutId),   // Mon
            savedOccurrence(on: date(2026, 6, 15), savedWorkoutId: loadoutId)   // Mon
        ])

        // Mondays inside Jul 1 ..< Jul 31: 6, 13, 20, 27.
        XCTAssertEqual(
            result.stamped.map { calendar.component(.day, from: $0.date) }.sorted(),
            [6, 13, 20, 27]
        )
        for occurrence in result.stamped {
            XCTAssertEqual(occurrence.programId, newProgramId)
            XCTAssertEqual(occurrence.savedWorkoutId, loadoutId)
            XCTAssertEqual(occurrence.kind, .saved)
            XCTAssertEqual(occurrence.title, "Push Day")
            XCTAssertTrue(occurrence.adaptsWithProgression)
        }
    }

    func testOneOffOccurrenceDoesNotBecomeAPattern() {
        let result = plan(occurrences: [
            savedOccurrence(on: date(2026, 6, 10), savedWorkoutId: UUID())      // single Wed
        ])
        XCTAssertTrue(result.stamped.isEmpty)
    }

    func testFuturePlannedOccurrenceRekeysAndBlocksPatternStamp() {
        let patternId = UUID()
        let explicitId = UUID()
        let future = savedOccurrence(
            on: date(2026, 7, 3),                                               // Fri, next arc
            savedWorkoutId: explicitId,
            title: "Deadlift Day"
        )
        let result = plan(occurrences: [
            savedOccurrence(on: date(2026, 6, 5), savedWorkoutId: patternId),   // Fri
            savedOccurrence(on: date(2026, 6, 12), savedWorkoutId: patternId),  // Fri
            future
        ])

        XCTAssertEqual(result.rekeyed.count, 1)
        XCTAssertEqual(result.rekeyed.first?.id, future.id)
        XCTAssertEqual(result.rekeyed.first?.programId, newProgramId)

        // Fridays inside the new window: 3, 10, 17, 24 — Jul 3 is claimed by
        // the explicit plan, so only the remaining Fridays get stamped.
        XCTAssertEqual(
            result.stamped.map { calendar.component(.day, from: $0.date) }.sorted(),
            [10, 17, 24]
        )
        XCTAssertTrue(result.stamped.allSatisfy { $0.savedWorkoutId == patternId })
    }

    func testBuiltPatternCarriesDraft() {
        let draft = builtDraft(title: "My Upper Day")
        let occurrences = [date(2026, 6, 9), date(2026, 6, 16)].map { day in  // Tuesdays
            ProgramScheduleOccurrence(
                userId: userId,
                programId: oldProgramId,
                date: day,
                kind: .built,
                title: "My Upper Day",
                draft: draft
            )
        }
        let result = plan(occurrences: occurrences)

        XCTAssertFalse(result.stamped.isEmpty)
        for occurrence in result.stamped {
            XCTAssertEqual(occurrence.kind, .built)
            XCTAssertEqual(occurrence.draft?.title, "My Upper Day")
        }
    }

    func testRestAndExtraOccurrencesNeverStamp() {
        let rest = ProgramScheduleOccurrence(
            userId: userId, programId: oldProgramId,
            date: date(2026, 6, 4), kind: .rest, title: "Rest"
        )
        let rest2 = ProgramScheduleOccurrence(
            userId: userId, programId: oldProgramId,
            date: date(2026, 6, 11), kind: .rest, title: "Rest"
        )
        let extra = ProgramScheduleOccurrence(
            userId: userId, programId: oldProgramId,
            date: date(2026, 6, 6), kind: .extra, title: "Extra"
        )
        let extra2 = ProgramScheduleOccurrence(
            userId: userId, programId: oldProgramId,
            date: date(2026, 6, 13), kind: .extra, title: "Extra"
        )
        let result = plan(occurrences: [rest, rest2, extra, extra2])
        XCTAssertTrue(result.stamped.isEmpty)
    }

    func testUserOwnedProgramDaysCountTowardPattern() {
        let loadoutId = UUID()
        // Day numbers 2 and 9 from a Jun 1 start = Jun 2 + Jun 9 (Tuesdays).
        let ownedDays = [2, 9].map { dayNumber in
            ProgramDay(
                id: "day-\(dayNumber)",
                dayNumber: dayNumber,
                label: "My Pull Day",
                isRestDay: false,
                workout: nil,
                savedWorkoutId: loadoutId,
                nutritionOverride: nil,
                recoveryActivities: []
            )
        }
        let result = plan(occurrences: [], previousUserOwnedDays: ownedDays)

        // Tuesdays inside Jul 1 ..< Jul 31: 7, 14, 21, 28.
        XCTAssertEqual(
            result.stamped.map { calendar.component(.day, from: $0.date) }.sorted(),
            [7, 14, 21, 28]
        )
        XCTAssertTrue(result.stamped.allSatisfy { $0.savedWorkoutId == loadoutId })
    }

    func testNoPreviousProgramYieldsEmptyPlan() {
        let result = BlockRolloverPlanCarryover.plan(
            previousStart: nil,
            previousDurationDays: 0,
            previousUserOwnedDays: [],
            previousProgramId: nil,
            occurrences: [savedOccurrence(on: date(2026, 6, 8), savedWorkoutId: UUID())],
            userId: userId,
            newProgramId: newProgramId,
            newStart: newStart,
            newDurationDays: 30,
            calendar: calendar,
            now: newStart
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testSameDateTwiceIsNotAPattern() {
        let loadoutId = UUID()
        let result = plan(occurrences: [
            savedOccurrence(on: date(2026, 6, 8), savedWorkoutId: loadoutId),
            savedOccurrence(on: date(2026, 6, 8), savedWorkoutId: loadoutId)
        ])
        XCTAssertTrue(result.stamped.isEmpty)
    }
}
