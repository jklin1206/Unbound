import XCTest
@testable import UNBOUND

final class TierCriterionEvaluatorTests: XCTestCase {

    // MARK: - .reps

    func testReps_emptyHistoryReturnsFalse() {
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [],
            bodyweightKg: 70
        ))
    }

    func testReps_warmupOnlyDoesNotSatisfy() {
        let entry = makeEntry(exerciseName: "pull-up", sets: [makeSet(reps: 10, isWarmup: true)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testReps_exactBoundaryPasses() {
        let entry = makeEntry(exerciseName: "pull-up", sets: [makeSet(reps: 8)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testReps_wrongExerciseNameNoMatch() {
        let entry = makeEntry(exerciseName: "chin-up", sets: [makeSet(reps: 20)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testReps_caseInsensitiveMatch() {
        let entry = makeEntry(exerciseName: "Pull-Up", sets: [makeSet(reps: 10)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    // MARK: - .seconds (always false — see evaluator note)

    func testSeconds_alwaysFalse() {
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .seconds(30),
            history: [],
            bodyweightKg: 70
        ))
    }

    // MARK: - .weightKg

    func testWeightKg_belowFails() {
        let entry = makeEntry(exerciseName: "bench press", sets: [makeSet(weightKg: 99, reps: 1)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .weightKg(100),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testWeightKg_atOrAbovePasses() {
        let entry = makeEntry(exerciseName: "bench press", sets: [makeSet(weightKg: 100, reps: 1)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .weightKg(100),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    // MARK: - .exerciseWeightKg

    func testExerciseWeightKg_ignoresUnrelatedHeavyLift() {
        let bench = makeEntry(exerciseName: "bench press", sets: [makeSet(weightKg: 80, reps: 1)])
        let deadlift = makeEntry(exerciseName: "deadlift", sets: [makeSet(weightKg: 160, reps: 1)])

        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .exerciseWeightKg(85, exerciseName: "bench press"),
            history: [bench, deadlift],
            bodyweightKg: 70
        ))
    }

    func testExerciseWeightKg_atOrAbovePasses() {
        let entry = makeEntry(exerciseName: "Bench Press", sets: [makeSet(weightKg: 85, reps: 1)])

        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .exerciseWeightKg(85, exerciseName: "bench press"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    // MARK: - .bodyweightRatio

    func testBodyweightRatio_belowFails() {
        let entry = makeEntry(exerciseName: "back squat", sets: [makeSet(weightKg: 100, reps: 1)])
        // 100 / 70 = 1.428 < 1.5
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .bodyweightRatio(1.5),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testBodyweightRatio_atOrAbovePasses() {
        let entry = makeEntry(exerciseName: "back squat", sets: [makeSet(weightKg: 105, reps: 1)])
        // 105 / 70 = 1.5
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .bodyweightRatio(1.5),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    // MARK: - .exerciseBodyweightRatio

    func testExerciseBodyweightRatio_ignoresUnrelatedHeavyLift() {
        let pull = makeEntry(exerciseName: "weighted pullup", sets: [makeSet(weightKg: 10, reps: 1)])
        let squat = makeEntry(exerciseName: "back squat", sets: [makeSet(weightKg: 120, reps: 5)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup"),
            history: [pull, squat],
            bodyweightKg: 80
        ))
    }

    func testExerciseBodyweightRatio_atOrAbovePasses() {
        let pull = makeEntry(exerciseName: "Weighted Pullup", sets: [makeSet(weightKg: 40, reps: 1)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup"),
            history: [pull],
            bodyweightKg: 80
        ))
    }

    // MARK: - .variant

    func testVariant_anyLoggedMatchPasses() {
        let entry = makeEntry(exerciseName: "muscle-up", sets: [makeSet(reps: 1)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testVariant_caseInsensitive() {
        let entry = makeEntry(exerciseName: "Muscle-Up", sets: [makeSet(reps: 1)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    func testVariant_noMatch() {
        let entry = makeEntry(exerciseName: "pull-up", sets: [makeSet(reps: 20)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        ))
    }

    // MARK: - .compound

    func testCompound_allPassReturnsTrue() {
        let pull = makeEntry(exerciseName: "pull-up", sets: [makeSet(reps: 10)])
        let bench = makeEntry(exerciseName: "bench press", sets: [makeSet(weightKg: 100, reps: 5)])
        XCTAssertTrue(TierCriterionEvaluator.satisfied(
            criterion: .compound([
                .reps(8, exerciseName: "pull-up"),
                .weightKg(100)
            ]),
            history: [pull, bench],
            bodyweightKg: 70
        ))
    }

    func testCompound_anyFailReturnsFalse() {
        let pull = makeEntry(exerciseName: "pull-up", sets: [makeSet(reps: 10)])
        XCTAssertFalse(TierCriterionEvaluator.satisfied(
            criterion: .compound([
                .reps(8, exerciseName: "pull-up"),
                .weightKg(100)
            ]),
            history: [pull],
            bodyweightKg: 70
        ))
    }

    // MARK: helpers

    private func makeEntry(exerciseName: String, sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: exerciseName,
            plannedSets: sets.count,
            plannedReps: "1",
            sets: sets,
            skipped: false,
            notes: nil
        )
    }

    private func makeSet(weightKg: Double? = nil, reps: Int = 0, isWarmup: Bool = false) -> SetLog {
        SetLog(
            id: UUID().uuidString,
            setNumber: 1,
            weightKg: weightKg,
            reps: reps,
            rpe: nil,
            isWarmup: isWarmup
        )
    }
}
