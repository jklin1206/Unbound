import XCTest
@testable import UNBOUND

final class ProgressionEngineBehaviorTests: XCTestCase {

    func testMovementCatalogProgressionDefinitionsAreSortedCatalogDefinitions() {
        let pullDefinitions = MovementCatalog.progressionDefinitions(family: "pull", maxTier: 4)

        XCTAssertEqual(pullDefinitions.compactMap(\.progressionTier), [0, 1, 2, 3, 4])
        XCTAssertEqual(pullDefinitions.last?.id, "exercise.lat-pulldown-neutral")
        XCTAssertEqual(pullDefinitions.last?.rankStandardMovementId, "exercise.lat-pulldown")
        XCTAssertTrue(pullDefinitions.allSatisfy { $0.role == .canonicalExercise })
        XCTAssertTrue(pullDefinitions.allSatisfy { $0.progressionFamily == "pull" })
    }

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
    func testVariantProgressionUnlockUsesExactMovementCatalogDefinitionWhenStateRollsIntoRankStandard() async {
        let userId = "variant-unlock-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 1_000)
        await ProgressionStateStore.shared.saveFamilyState(
            ProgressionFamilyState(
                userId: userId,
                family: "pull",
                unlockedTier: 4,
                currentTier: 4,
                updatedAt: startedAt
            )
        )

        let first = neutralLatPulldownLog(
            id: "neutral-pulldown-1-\(UUID().uuidString)",
            userId: userId,
            at: startedAt
        )
        await ProgressionEngine.shared.ingest(log: first, mode: .advance)

        let afterFirst = await ProgressionStateStore.shared.familyState(userId: userId, family: "pull")
        XCTAssertEqual(afterFirst?.unlockedTier, 4)

        let second = neutralLatPulldownLog(
            id: "neutral-pulldown-2-\(UUID().uuidString)",
            userId: userId,
            at: startedAt.addingTimeInterval(86_400)
        )
        await ProgressionEngine.shared.ingest(log: second, mode: .advance)

        let family = await ProgressionStateStore.shared.familyState(userId: userId, family: "pull")
        XCTAssertEqual(family?.unlockedTier, 5)

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):lat pulldown"
        )
        XCTAssertEqual(state?.displayName, "Lat Pulldown (Bar)")
    }

    private func neutralLatPulldownLog(id: String, userId: String, at date: Date) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: "program-catalog-regression",
            dayNumber: 1,
            plannedWorkoutName: "Pull",
            startedAt: date,
            completedAt: date.addingTimeInterval(1_800),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "entry-\(id)",
                    exerciseName: "Lat Pulldown (Neutral)",
                    movementId: "exercise.lat-pulldown-neutral",
                    rankStandardMovementId: "exercise.lat-pulldown",
                    plannedSets: 1,
                    plannedReps: "10",
                    sets: [
                        SetLog(
                            id: "set-\(id)",
                            setNumber: 1,
                            weightKg: 70,
                            reps: 10,
                            rpe: 8,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ]
        )
    }
}
