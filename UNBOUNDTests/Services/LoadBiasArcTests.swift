import XCTest
@testable import UNBOUND

final class LoadBiasArcTests: XCTestCase {

    private func makeProgram() -> TrainingProgram {
        ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Push", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 2, label: "Pull", role: .pull, muscleGroups: [.back, .lats])
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
    }

    /// Total prescribed working sets across the Arc's main exercises.
    private func totalMainSets(_ program: TrainingProgram) -> Int {
        program.days.reduce(0) { sum, day in
            sum + (day.workout?.mainExercises.reduce(0) { $0 + $1.sets } ?? 0)
        }
    }

    // MARK: - Kickoff proof: recovery Checkpoint lowers next-Arc volume

    func testRecoveryCheckpointLowersNextArcVolume() {
        let program = makeProgram()

        let neutral = ArcGenerator.generateNextArc(from: program, checkpoint: .skipped)
        let recovery = ArcGenerator.generateNextArc(
            from: program,
            checkpoint: .completed(CheckpointSignals(loadAdjustmentBias: -0.4, recoveryStateHint: .accumulated))
        )

        let neutralVolume = totalMainSets(neutral)
        let recoveryVolume = totalMainSets(recovery)

        XCTAssertGreaterThan(neutralVolume, 0)
        XCTAssertLessThan(recoveryVolume, neutralVolume,
                          "Recovery Checkpoint must deload next-Arc volume, not just change copy")
        // Split shape is preserved (this was the only behavior before).
        XCTAssertEqual(Array(recovery.days.map(\.sessionRole).prefix(2)), [.push, .pull])
        XCTAssertEqual(recovery.rationale?.decisions.first?.reasonCategory, .loadLowered)
    }

    func testPushCheckpointRaisesNextArcVolume() {
        let program = makeProgram()

        let neutral = ArcGenerator.generateNextArc(from: program, checkpoint: .skipped)
        let push = ArcGenerator.generateNextArc(
            from: program,
            checkpoint: .completed(CheckpointSignals(loadAdjustmentBias: 0.4, recoveryStateHint: .wellRecovered))
        )

        XCTAssertGreaterThan(totalMainSets(push), totalMainSets(neutral),
                             "Push Checkpoint must raise next-Arc volume")
        XCTAssertEqual(push.rationale?.decisions.first?.reasonCategory, .loadRaised)
    }

    func testNeutralBiasLeavesVolumeUnchanged() {
        let program = makeProgram()
        let baseline = ArcGenerator.generateNextArc(from: program, checkpoint: .skipped)
        let neutral = ArcGenerator.generateNextArc(
            from: program,
            checkpoint: .completed(CheckpointSignals(loadAdjustmentBias: 0.02))
        )
        XCTAssertEqual(totalMainSets(neutral), totalMainSets(baseline),
                       "A bias inside the neutral band must not change prescriptions")
    }

    // MARK: - Pure applier units

    func testApplierIsMonotoneAndBoundedAndRPEAware() {
        let exercise = Exercise(
            id: "e", name: "Bench", muscleGroups: [.chest],
            sets: 4, reps: "5", restSeconds: 120, rpe: 8
        )
        let workout = Workout(
            name: "Push", targetMuscleGroups: [.chest], warmup: [],
            mainExercises: [exercise], cooldown: [], estimatedMinutes: 40, notes: nil, blockType: .accumulation
        )

        let deloaded = LoadBiasApplier.apply(to: workout, bias: -0.5).mainExercises[0]
        let pushed = LoadBiasApplier.apply(to: workout, bias: 0.5).mainExercises[0]
        let neutral = LoadBiasApplier.apply(to: workout, bias: 0.0).mainExercises[0]

        XCTAssertLessThan(deloaded.sets, exercise.sets)
        XCTAssertGreaterThan(pushed.sets, exercise.sets)
        XCTAssertEqual(neutral.sets, exercise.sets)
        XCTAssertEqual(deloaded.rpe, 7) // lowered
        XCTAssertEqual(pushed.rpe, 9)   // raised
        XCTAssertGreaterThanOrEqual(deloaded.sets, 1) // floor at 1

        // Factor stays inside the clamp even for extreme bias.
        XCTAssertEqual(LoadBiasApplier.volumeFactor(for: -1.0), 0.75, accuracy: 0.001)
        XCTAssertEqual(LoadBiasApplier.volumeFactor(for: 1.0), 1.2, accuracy: 0.001)
    }
}
