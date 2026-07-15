import XCTest
@testable import UNBOUND

/// TrainingPrescriptionResolver must write resolved targets/weights THROUGH to
/// materialized set plans — the active session builds from `effectiveSetPlans`,
/// so a summary-only rewrite silently no-ops for editor-touched loadouts.
/// Hand-customized per-set programming must be left alone.
final class TrainingPrescriptionResolverTests: XCTestCase {
    private func state(
        exercise: String,
        weightKg: Double = 60,
        repMin: Int = 6,
        repMax: Int = 8,
        lastReps: Int? = 6
    ) -> ProgressionState {
        var seeded = ProgressionState.seed(
            userId: "test-user",
            exercise: exercise,
            startingWeightKg: weightKg
        )
        seeded.targetRepMin = repMin
        seeded.targetRepMax = repMax
        seeded.lastSessionReps = lastReps
        return seeded
    }

    private func draft(with prescription: TrainingBlockPrescription) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: "test-user",
            source: .custom,
            title: "Loadout",
            estimatedMinutes: 30,
            blocks: [
                TrainingBlock(kind: .strength, title: "Main", prescriptions: [prescription])
            ]
        )
    }

    func testResolvedTargetWritesThroughUniformSetPlans() {
        var prescription = TrainingBlockPrescription(
            exerciseName: "Bench Press",
            sets: 3,
            target: .repsRange(6, 8),
            restSeconds: 120
        )
        prescription.materializeSetPlans()
        XCTAssertEqual(prescription.setPlans?.count, 3)

        let progression = state(exercise: "bench press", lastReps: 6)
        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft(with: prescription),
            progressionStates: [MovementCatalog.normalized("bench press"): progression]
        )

        let out = resolved.blocks[0].prescriptions[0]
        // Summary carries the climbing target (last 6 → ask 7)…
        XCTAssertEqual(out.target, .reps(progression.currentTargetReps))
        // …and every uniform set plan follows, so the session actually sees it.
        XCTAssertEqual(out.setPlans?.count, 3)
        for plan in out.setPlans ?? [] {
            XCTAssertEqual(plan.target, .reps(progression.currentTargetReps))
            XCTAssertEqual(plan.suggestedWeightKg, out.suggestedWeightKg)
        }
        XCTAssertNotNil(out.suggestedWeightKg)
    }

    func testCustomSetPlansAreLeftAlone() {
        var prescription = TrainingBlockPrescription(
            exerciseName: "Bench Press",
            sets: 3,
            target: .repsRange(6, 8),
            restSeconds: 120
        )
        prescription.materializeSetPlans()
        // Hand-tune one set — deliberate per-set programming.
        prescription.setPlans?[2].target = .reps(3)

        let customPlans = prescription.setPlans
        XCTAssertTrue(prescription.hasCustomSetPlanValues)

        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft(with: prescription),
            progressionStates: [MovementCatalog.normalized("bench press"): state(exercise: "bench press")]
        )

        XCTAssertEqual(resolved.blocks[0].prescriptions[0].setPlans, customPlans)
    }

    func testNoProgressionStateLeavesPrescriptionUntouched() {
        var prescription = TrainingBlockPrescription(
            exerciseName: "Obscure Movement",
            sets: 2,
            target: .repsRange(5, 8),
            restSeconds: 90
        )
        prescription.materializeSetPlans()

        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft(with: prescription),
            progressionStates: [MovementCatalog.normalized("bench press"): state(exercise: "bench press")]
        )

        XCTAssertEqual(resolved.blocks[0].prescriptions[0], prescription)
    }

    func testCurrentProgressionWeightReplacesStaleGeneratedSuggestion() {
        let prescription = TrainingBlockPrescription(
            exerciseName: "Bench Press",
            sets: 3,
            target: .reps(8),
            restSeconds: 120,
            suggestedWeightKg: 60
        )
        let progression = state(exercise: "bench press", weightKg: 80)

        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft(with: prescription),
            progressionStates: ["bench press": progression]
        )

        XCTAssertEqual(
            resolved.blocks[0].prescriptions[0].suggestedWeightKg,
            WeightPlatePolicy.snappedSuggestionKilograms(80)
        )
    }

    func testProgramDeloadWaveReducesCurrentLoad() {
        let prescription = TrainingBlockPrescription(
            exerciseName: "Bench Press",
            sets: 3,
            target: .reps(8),
            restSeconds: 120,
            suggestedWeightKg: 100
        )
        var programDraft = draft(with: prescription)
        programDraft.source = .program
        programDraft.dayNumber = 26

        let resolved = TrainingPrescriptionResolver.resolve(
            draft: programDraft,
            progressionStates: ["bench press": state(exercise: "bench press", weightKg: 100)]
        )

        XCTAssertEqual(ProgramTrainingWave.forDay(26), .deload)
        XCTAssertEqual(
            resolved.blocks[0].prescriptions[0].suggestedWeightKg,
            WeightPlatePolicy.snappedSuggestionKilograms(
                WeightPlatePolicy.snappedSuggestionKilograms(100)
                    * ProgramTrainingWave.deload.loadFactor
            )
        )
    }

    func testTimedHoldStateStaysSecondsBased() {
        var progression = state(exercise: "plank", weightKg: 0)
        progression.targetDurationSeconds = 30
        let prescription = TrainingBlockPrescription(
            exerciseName: "Plank",
            sets: 3,
            target: .holdSeconds(20),
            restSeconds: 60
        )

        let resolved = TrainingPrescriptionResolver.resolve(
            draft: draft(with: prescription),
            progressionStates: ["plank": progression]
        )

        XCTAssertEqual(resolved.blocks[0].prescriptions[0].target, .holdSeconds(30))
    }
}
