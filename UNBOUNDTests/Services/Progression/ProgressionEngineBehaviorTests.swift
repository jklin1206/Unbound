import XCTest
@testable import UNBOUND

final class ProgressionEngineBehaviorTests: XCTestCase {

    // Smoke test: the `mode:` parameter exists and defaults to .advance,
    // so existing callers that don't pass it still compile.
    func testIngestAcceptsModeParameter() async {
        let log = WorkoutLog(
            id: "log-1",
            userId: "u-\(UUID().uuidString)",
            programId: "p-1",
            dayNumber: 1,
            plannedWorkoutName: "Test",
            startedAt: Date(),
            completedAt: Date(),
            exerciseEntries: []
        )
        // Preserve mode — should not crash on empty log.
        await ProgressionEngine.shared.ingest(log: log, mode: .preserve)
        // Advance mode explicit.
        await ProgressionEngine.shared.ingest(log: log, mode: .advance)
        // Default (.advance via default param) — backward-compat.
        await ProgressionEngine.shared.ingest(log: log)
    }

    // Silent feedback mode: targetRPE should end up at 0 on newly-seeded
    // ProgressionState when the user's feedbackMode is .silent. This means
    // the engine's `hitTargetRPE` check always passes (sets without RPE
    // values count as at-target).
    @MainActor
    func testSilentFeedbackModeYieldsZeroTargetRPE() async {
        // Dedicated user id so no prior state exists for this run.
        let userId = "silent-\(UUID().uuidString)"
        let entry = ExerciseLogEntry(
            id: "entry-\(UUID().uuidString)",
            exerciseName: "bench press",
            plannedSets: 1,
            plannedReps: "10",
            sets: [SetLog(
                id: "set-\(UUID().uuidString)",
                setNumber: 1,
                weightKg: 60,
                reps: 10,
                rpe: nil,
                isWarmup: false
            )],
            skipped: false,
            notes: nil
        )
        let log = WorkoutLog(
            id: "log-silent-\(UUID().uuidString)",
            userId: userId,
            programId: "p-1",
            dayNumber: 1,
            plannedWorkoutName: "Test",
            startedAt: Date(),
            completedAt: Date(),
            exerciseEntries: [entry]
        )
        await ProgressionEngine.shared.ingest(log: log, mode: .advance, feedbackMode: .silent)

        // The seeded state should have targetRPE == 0.
        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(state?.targetRPE, 0, "Silent feedback mode should seed targetRPE=0")
    }

    @MainActor
    func testTierUnlockResolvesLegacySavedExerciseNamesThroughMovementCatalog() async {
        let userId = "legacy-tier-\(UUID().uuidString)"
        let startedAt = Date()
        await ProgressionStateStore.shared.saveFamilyState(ProgressionFamilyState(
            userId: userId,
            family: "pull",
            unlockedTier: 1,
            currentTier: 1,
            updatedAt: startedAt
        ))

        let firstLog = makeSingleExerciseLog(
            userId: userId,
            exerciseName: "Band-Assisted Pull-Up",
            reps: 12,
            startedAt: startedAt
        )
        let secondLog = makeSingleExerciseLog(
            userId: userId,
            exerciseName: "Band-Assisted Pull-Up",
            reps: 12,
            startedAt: startedAt.addingTimeInterval(86_400)
        )

        await ProgressionEngine.shared.ingest(log: firstLog, mode: .advance, feedbackMode: .silent)
        await ProgressionEngine.shared.ingest(log: secondLog, mode: .advance, feedbackMode: .silent)

        let familyState = await ProgressionStateStore.shared.familyState(userId: userId, family: "pull")
        XCTAssertEqual(familyState?.unlockedTier, 2)
    }

    private func makeSingleExerciseLog(
        userId: String,
        exerciseName: String,
        reps: Int,
        startedAt: Date
    ) -> WorkoutLog {
        let entry = ExerciseLogEntry(
            id: "entry-\(UUID().uuidString)",
            exerciseName: exerciseName,
            plannedSets: 1,
            plannedReps: "\(reps)",
            sets: [SetLog(
                id: "set-\(UUID().uuidString)",
                setNumber: 1,
                weightKg: 0,
                reps: reps,
                rpe: nil,
                isWarmup: false
            )],
            skipped: false,
            notes: nil
        )

        return WorkoutLog(
            id: "log-\(UUID().uuidString)",
            userId: userId,
            programId: "p-1",
            dayNumber: 1,
            plannedWorkoutName: "Test",
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(1_800),
            exerciseEntries: [entry]
        )
    }
}
