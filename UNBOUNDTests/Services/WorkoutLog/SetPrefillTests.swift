import XCTest
@testable import UNBOUND

final class SetPrefillTests: XCTestCase {
    private func entry(_ name: String, _ sets: [(Double?, Int)]) -> ExerciseLogEntry {
        ExerciseLogEntry(id: "x", exerciseName: name, plannedSets: sets.count,
            plannedReps: "8",
            sets: sets.enumerated().map { (i, s) in
                SetLog(id: "s\(i)", setNumber: i + 1, weightKg: s.0, reps: s.1,
                       rpe: nil, isWarmup: false) },
            skipped: false, notes: nil)
    }
    func test_usesLastSessionMatchingSetIndex() {
        let history = [entry("Bench", [(80, 8), (82.5, 6)])]
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 1,
                                 priorEntries: history, workingWeightKg: 50)
        XCTAssertEqual(g?.weightKg, 82.5)
        XCTAssertEqual(g?.reps, 6)
    }
    func test_fallsBackToLastSetWhenIndexBeyondHistory() {
        let history = [entry("Bench", [(80, 8)])]
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 3,
                                 priorEntries: history, workingWeightKg: 50)
        XCTAssertEqual(g?.weightKg, 80)
        XCTAssertEqual(g?.reps, 8)
    }
    func test_fallsBackToWorkingWeightWhenNoHistory() {
        let g = SetPrefill.ghost(exerciseName: "Bench", setIndex: 0,
                                 priorEntries: [], workingWeightKg: 60)
        XCTAssertEqual(g?.weightKg, 60)
        XCTAssertNil(g?.reps)
    }
    func test_nilWhenNothingKnown() {
        XCTAssertNil(SetPrefill.ghost(exerciseName: "Bench", setIndex: 0,
                                      priorEntries: [], workingWeightKg: nil))
    }
    func test_caseInsensitiveNameMatch() {
        let history = [entry("bench press", [(100, 5)])]
        let g = SetPrefill.ghost(exerciseName: "Bench Press", setIndex: 0,
                                 priorEntries: history, workingWeightKg: nil)
        XCTAssertEqual(g?.weightKg, 100)
    }
}
