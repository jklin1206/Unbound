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

    func testBodyweightProgressionsDoNotClassifyAsLoadedCompounds() {
        XCTAssertEqual(ExerciseClassification.classify(exerciseKey: "bodyweight squat"), .bodyweightSkill)
        XCTAssertEqual(ExerciseClassification.classify(exerciseKey: "l sit"), .bodyweightSkill)
        XCTAssertEqual(ExerciseClassification.classify(exerciseKey: "tuck front lever"), .bodyweightSkill)
        XCTAssertEqual(ExerciseClassification.classify(exerciseKey: "back squat"), .lowerCompound)
        XCTAssertEqual(ExerciseClassification.classify(exerciseKey: "weighted pullup"), .upperCompound)
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

    @MainActor
    func testSavedVariantRankStandardIdSeedsCanonicalProgressionState() async {
        let userId = "variant-standard-\(UUID().uuidString)"
        let log = neutralLatPulldownLog(
            id: "neutral-pulldown-saved-\(UUID().uuidString)",
            userId: userId,
            at: Date(timeIntervalSince1970: 2_000),
            exerciseName: "Saved Pulldown Label",
            movementId: "exercise.lat-pulldown-neutral",
            rankStandardMovementId: "exercise.lat-pulldown-neutral"
        )

        await ProgressionEngine.shared.ingest(log: log, mode: .advance)

        let canonicalState: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):lat pulldown"
        )
        let variantState: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):lat pulldown neutral"
        )

        XCTAssertEqual(canonicalState?.displayName, "Lat Pulldown (Bar)")
        XCTAssertNil(variantState)
    }

    @MainActor
    func testGrindyRPEDoesNotAdvanceProgressionCounterOrWeight() async {
        let userId = "grindy-rpe-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 3_000)

        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "bench-grind-1-\(UUID().uuidString)",
                userId: userId,
                exerciseName: "bench press",
                reps: 10,
                weightKg: 60,
                rpe: 9,
                at: startedAt
            ),
            mode: .advance
        )
        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "bench-grind-2-\(UUID().uuidString)",
                userId: userId,
                exerciseName: "bench press",
                reps: 10,
                weightKg: 60,
                rpe: 9,
                at: startedAt.addingTimeInterval(86_400)
            ),
            mode: .advance
        )

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(state?.consecutiveSessionsAtTarget, 0)
        XCTAssertEqual(state?.currentWorkingWeightKg, 60)
    }

    @MainActor
    func testAccessoryProgressionCapsRepRangeThenBumpsLoad() async {
        let userId = "accessory-cap-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 4_000)
        let repTargets = [15, 15, 17, 17, 19, 19, 20, 20]

        for (index, reps) in repTargets.enumerated() {
            await ProgressionEngine.shared.ingest(
                log: progressionLog(
                    id: "curl-\(index)-\(UUID().uuidString)",
                    userId: userId,
                    exerciseName: "cable curl",
                    reps: reps,
                    weightKg: 10,
                    rpe: 7,
                    at: startedAt.addingTimeInterval(Double(index) * 86_400)
                ),
                mode: .advance
            )
        }

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):cable curl"
        )
        XCTAssertEqual(state?.targetRepMax, 15)
        XCTAssertEqual(state?.consecutiveSessionsAtTarget, 0)
        XCTAssertGreaterThan(state?.currentWorkingWeightKg ?? 0, 10)
    }

    private func neutralLatPulldownLog(
        id: String,
        userId: String,
        at date: Date,
        exerciseName: String = "Lat Pulldown (Neutral)",
        movementId: String = "exercise.lat-pulldown-neutral",
        rankStandardMovementId: String = "exercise.lat-pulldown"
    ) -> WorkoutLog {
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
                    exerciseName: exerciseName,
                    movementId: movementId,
                    rankStandardMovementId: rankStandardMovementId,
                    plannedSets: 1,
                    plannedReps: "10",
                    sets: [
                        SetLog(
                            id: "set-\(id)",
                            setNumber: 1,
                            weightKg: 70,
                            reps: 10,
                            rpe: 7,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ]
        )
    }

    private func progressionLog(
        id: String,
        userId: String,
        exerciseName: String,
        reps: Int,
        weightKg: Double,
        rpe: Int,
        at date: Date
    ) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: "program-progression-regression",
            dayNumber: 1,
            plannedWorkoutName: "Progression Regression",
            startedAt: date,
            completedAt: date.addingTimeInterval(1_800),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "entry-\(id)",
                    exerciseName: exerciseName,
                    plannedSets: 1,
                    plannedReps: "\(reps)",
                    sets: [
                        SetLog(
                            id: "set-\(id)",
                            setNumber: 1,
                            weightKg: weightKg,
                            reps: reps,
                            rpe: rpe,
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
