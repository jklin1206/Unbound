import XCTest
@testable import UNBOUND

final class LastPerformanceLookupTests: XCTestCase {
    private func set(_ n: Int, kg: Double? = nil, reps: Int = 0, hold: Int? = nil, warmup: Bool = false) -> SetLog {
        SetLog(id: "s\(n)", setNumber: n, weightKg: kg, reps: reps, rpe: nil,
               isWarmup: warmup, durationSeconds: hold, qualityFlags: nil, notes: nil)
    }
    private func entry(name: String, movementId: String? = nil, skipped: Bool = false, sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(id: "e-\(name)", exerciseName: name, movementId: movementId,
                         rankStandardMovementId: nil, plannedSets: sets.count, plannedReps: "",
                         sets: sets, skipped: skipped, notes: nil)
    }
    private func log(id: String, at: Date, entries: [ExerciseLogEntry]) -> WorkoutLog {
        WorkoutLog(id: id, userId: "u", programId: "p", dayNumber: 1, plannedWorkoutName: "",
                   startedAt: at, completedAt: at, exerciseEntries: entries, overallNotes: nil,
                   overallRPE: nil, durationMinutes: nil)
    }
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func test_returnsMostRecentPriorWorkingSetByMovementId() {
        let older = log(id: "old", at: t0, entries: [entry(name: "Bench", movementId: "m1", sets: [set(1, kg: 100, reps: 8)])])
        let newer = log(id: "new", at: t0.addingTimeInterval(86_400),
                        entries: [entry(name: "Bench", movementId: "m1", sets: [set(1, kg: 110, reps: 8)])])
        let lookup = LastPerformanceLookup(logs: [older, newer], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "m1", exerciseName: "Bench", workingIndex: 0)?.weightKg, 110)
    }

    func test_movementIdWinsOverName_andNameFallbackWhenNoId() {
        let l = log(id: "a", at: t0, entries: [entry(name: "Pull-Up", sets: [set(1, reps: 12)])])
        let lookup = LastPerformanceLookup(logs: [l], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: nil, exerciseName: "pull-up ", workingIndex: 0)?.reps, 12)  // normalized
        XCTAssertNil(lookup.lastWorkingSet(movementId: "missing", exerciseName: "Other", workingIndex: 0))
    }

    func test_workingIndexSkipsWarmups_andMissingLaterSetIsNil() {
        let l = log(id: "a", at: t0, entries: [entry(name: "Squat", movementId: "m", sets: [
            set(1, kg: 60, reps: 5, warmup: true), set(2, kg: 140, reps: 5), set(3, kg: 140, reps: 4)
        ])])
        let lookup = LastPerformanceLookup(logs: [l], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "m", exerciseName: "Squat", workingIndex: 0)?.weightKg, 140)  // first WORKING
        XCTAssertNil(lookup.lastWorkingSet(movementId: "m", exerciseName: "Squat", workingIndex: 2))                   // only 2 working
    }

    func test_holdsAndSkippedAndExclusion() {
        let hold = log(id: "h", at: t0, entries: [entry(name: "Plank", movementId: "pl", sets: [set(1, hold: 45)])])
        let skip = log(id: "s", at: t0.addingTimeInterval(86_400),
                       entries: [entry(name: "Plank", movementId: "pl", skipped: true, sets: [set(1, hold: 9)])])
        let lookup = LastPerformanceLookup(logs: [skip, hold], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "pl", exerciseName: "Plank", workingIndex: 0)?.durationSeconds, 45)  // skipped ignored
        let selfExcluded = LastPerformanceLookup(logs: [hold], excludingLogId: "h")
        XCTAssertNil(selfExcluded.lastWorkingSet(movementId: "pl", exerciseName: "Plank", workingIndex: 0))
    }
}
