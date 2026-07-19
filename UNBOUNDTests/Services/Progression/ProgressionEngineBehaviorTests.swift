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
    func testGrindyTopOfRangeSetsDoNotAdvanceLoad() async {
        let userId = "rep-advance-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 3_000)

        // Fresh bench press seeds at accumulation range 8...10 → top of range = 10.
        // Two sessions at 10 reps above the planned effort should hold the load.
        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "bench-rep-1-\(UUID().uuidString)",
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
                id: "bench-rep-2-\(UUID().uuidString)",
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
        XCTAssertEqual(state?.currentWorkingWeightKg, 60)
        XCTAssertEqual(state?.consecutiveSessionsAtTarget, 0)
        XCTAssertEqual(state?.lastSessionReps, 10)
        XCTAssertEqual(state?.lastSessionRPE, 9)
        XCTAssertEqual(state?.lastSessionHitTarget, false)
        XCTAssertEqual(state?.lastSessionWasGrindy, true)
        XCTAssertEqual(state?.prescriptionBias, .easier)
    }

    @MainActor
    func testLowRPEOverPerformanceAdvancesAfterOneSession() async {
        let userId = "over-performance-\(UUID().uuidString)"
        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "easy-bench-\(UUID().uuidString)",
                userId: userId,
                exerciseName: "bench press",
                reps: 12,
                plannedReps: 8,
                weightKg: 60,
                rpe: 7,
                at: Date(timeIntervalSince1970: 3_250)
            ),
            mode: .advance
        )

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertGreaterThan(state?.currentWorkingWeightKg ?? 0, 60)
        // The bump clears rep history so the ask restarts at the bottom of
        // the window at the new, heavier load.
        XCTAssertNil(state?.lastSessionReps)
        XCTAssertEqual(state?.currentTargetReps, state?.targetRepMin)
        XCTAssertEqual(state?.lastSessionRPE, 7)
        XCTAssertEqual(state?.prescriptionBias, .harder)
    }

    @MainActor
    func testTimedHoldOverPerformanceAdvancesSecondsLadder() async {
        let userId = "hold-over-performance-\(UUID().uuidString)"
        let date = Date(timeIntervalSince1970: 3_300)
        let log = WorkoutLog(
            id: "hold-log-\(UUID().uuidString)",
            userId: userId,
            programId: "program-hold",
            dayNumber: 1,
            plannedWorkoutName: "Core",
            startedAt: date,
            completedAt: date.addingTimeInterval(600),
            exerciseEntries: [
                ExerciseLogEntry(
                    id: "hold-entry",
                    exerciseName: "Plank",
                    plannedSets: 1,
                    plannedReps: "20s hold",
                    sets: [
                        SetLog(
                            id: "hold-set",
                            setNumber: 1,
                            weightKg: nil,
                            reps: 0,
                            rpe: 7,
                            isWarmup: false,
                            durationSeconds: 30
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            ]
        )

        await ProgressionEngine.shared.ingest(log: log, mode: .advance)

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):plank"
        )
        XCTAssertEqual(state?.lastSessionDurationSeconds, 30)
        XCTAssertNil(state?.lastSessionReps)
        XCTAssertGreaterThan(state?.currentTargetDurationSeconds ?? 0, 30)
        XCTAssertEqual(state?.prescriptionBias, .harder)
    }

    func testRepCalibrationSeedsFromDemonstratedCapacity() throws {
        let baseline = CalibrationBaseline(
            userId: "calibration-user",
            exerciseKey: "pushup",
            displayName: "Pushup",
            kind: .reps,
            value: 12,
            unit: "reps",
            isKnown: true
        )
        let state = try XCTUnwrap(ProgressionState.calibrated(
            userId: baseline.userId,
            baseline: baseline
        ))

        XCTAssertEqual(state.currentWorkingWeightKg, 0)
        XCTAssertEqual(state.targetRepMin, 7)
        XCTAssertEqual(state.targetRepMax, 9)
        XCTAssertEqual(state.currentTargetReps, 7)
    }

    @MainActor
    func testTargetRPE9CountsAsCleanWhenBlockCallsForIt() async {
        let userId = "realization-rpe-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 3_500)
        var seeded = ProgressionState.seed(
            userId: userId,
            exercise: "bench press",
            startingWeightKg: 80,
            block: .realization
        )
        seeded.targetRepMin = 3
        seeded.targetRepMax = 5
        seeded.targetRPE = 9
        try? await DatabaseService.shared.create(
            seeded,
            collection: "progression_states",
            documentId: seeded.id
        )

        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "bench-realization-\(UUID().uuidString)",
                userId: userId,
                exerciseName: "bench press",
                reps: 5,
                weightKg: 80,
                rpe: 9,
                at: startedAt
            ),
            mode: .advance
        )

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(state?.lastSessionHitTarget, true)
        XCTAssertEqual(state?.lastSessionWasGrindy, false)
        XCTAssertEqual(state?.underTargetSessionCount, 0)
        XCTAssertEqual(state?.prescriptionBias, .hold)
    }

    @MainActor
    func testAccessoryProgressionCapsRepRangeThenBumpsLoad() async {
        let userId = "accessory-cap-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 4_000)
        // The 10...15 accessory window tops out at the 15-rep ceiling, so two
        // clean top-range sessions move load instead of inflating reps to 17+.
        let repTargets = [15, 15]

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
        // The load bump clears rep history so the ask restarts at the bottom.
        XCTAssertNil(state?.lastSessionReps)
        XCTAssertEqual(state?.currentTargetReps, 10)
    }

    @MainActor
    func testBodyweightCeilingHoldsAskInsteadOfCollapsing() async {
        let userId = "bw-hold-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 4_500)

        // Push-up rides the 5...12 bodyweight window. Hitting the top twice
        // has no load to bump, so the ask must hold at 12 - not collapse to 5.
        for (index, reps) in [12, 12].enumerated() {
            await ProgressionEngine.shared.ingest(
                log: progressionLog(
                    id: "pushup-\(index)-\(UUID().uuidString)",
                    userId: userId,
                    exerciseName: "push-up",
                    reps: reps,
                    weightKg: 0,
                    rpe: 7,
                    at: startedAt.addingTimeInterval(Double(index) * 86_400)
                ),
                mode: .advance
            )
        }

        // The engine canonicalizes "push-up" to the catalog key "pushup".
        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):pushup"
        )
        XCTAssertEqual(state?.classification, .bodyweightSkill)
        XCTAssertEqual(state?.lastSessionReps, 12)
        XCTAssertEqual(state?.currentTargetReps, state?.targetRepMax)
    }

    // (b) A deloaded lift exits back to accumulation after the bounded number
    // of deload sessions, with counters reset and the rep ask resumed at the
    // restored accumulation floor — never pinned at the deload minimum.
    @MainActor
    func testDeloadExitsToAccumulationAfterBoundedSessions() async {
        let userId = "deload-exit-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 10_000)

        // Seed a deload exactly as the auto/coach deload path would.
        let seeded = DeloadPlanner.shared.planDeload(for: [
            ProgressionState.seed(userId: userId, exercise: "bench press", startingWeightKg: 60)
        ])[0]
        XCTAssertEqual(seeded.blockType, .deload)
        try? await DatabaseService.shared.create(
            seeded, collection: "progression_states", documentId: seeded.id
        )

        for i in 0..<DeloadPolicy.sessionsInDeload {
            await ProgressionEngine.shared.ingest(
                log: progressionLog(
                    id: "deload-\(i)-\(UUID().uuidString)",
                    userId: userId,
                    exerciseName: "bench press",
                    reps: 8,
                    weightKg: 50,
                    rpe: 6,
                    at: startedAt.addingTimeInterval(Double(i) * 86_400)
                ),
                mode: .advance
            )
        }

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        let accumRange = ExerciseClassification.upperCompound.defaultRepRange(for: .accumulation)
        let deloadFloor = ExerciseClassification.upperCompound.defaultRepRange(for: .deload).lowerBound
        XCTAssertEqual(state?.blockType, .accumulation, "Deload must exit after the bounded session count")
        XCTAssertEqual(state?.targetRepMin, accumRange.lowerBound)
        XCTAssertEqual(state?.targetRepMax, accumRange.upperBound)
        XCTAssertNil(state?.lastSessionReps, "Exit clears rep history so the ask restarts at the restored floor")
        XCTAssertEqual(state?.currentTargetReps, accumRange.lowerBound, "Resumed target sits at the accumulation floor")
        XCTAssertGreaterThan(state?.currentTargetReps ?? 0, deloadFloor, "Resumed target climbs off the deload minimum")
        XCTAssertEqual(state?.deloadCooldownRemaining, DeloadPolicy.postDeloadCooldownSessions, "Exit arms the anti-thrash cooldown")
        XCTAssertNil(state?.deloadSessionsCompleted, "Deload counter clears on exit")
    }

    // (c) End-to-end freeze regression: the old trap deloaded a lift and never
    // reset `blockType`, pinning `currentTargetReps` at the deload floor
    // forever. Replay that sequence and assert the target is NOT frozen: after
    // exit the ask climbs with logged reps instead of sticking at the floor.
    @MainActor
    func testStickyDeloadNoLongerFreezesRepTarget() async {
        let userId = "deload-freeze-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 11_000)

        let seeded = DeloadPlanner.shared.planDeload(for: [
            ProgressionState.seed(userId: userId, exercise: "bench press", startingWeightKg: 60)
        ])[0]
        try? await DatabaseService.shared.create(
            seeded, collection: "progression_states", documentId: seeded.id
        )
        let deloadFloor = ExerciseClassification.upperCompound.defaultRepRange(for: .deload).lowerBound
        // The trap starting point: while deloaded the shown target is the floor.
        XCTAssertEqual(seeded.currentTargetReps, deloadFloor)

        // Train through the deload (exits after the bounded count), then keep
        // training in accumulation.
        for i in 0..<DeloadPolicy.sessionsInDeload {
            await ProgressionEngine.shared.ingest(
                log: progressionLog(
                    id: "freeze-deload-\(i)-\(UUID().uuidString)",
                    userId: userId,
                    exerciseName: "bench press",
                    reps: 6,
                    weightKg: 50,
                    rpe: 6,
                    at: startedAt.addingTimeInterval(Double(i) * 86_400)
                ),
                mode: .advance
            )
        }
        // One post-exit accumulation session with mid-range reps: the ask should
        // climb to last+1, proving the target is no longer pinned.
        await ProgressionEngine.shared.ingest(
            log: progressionLog(
                id: "freeze-accum-\(UUID().uuidString)",
                userId: userId,
                exerciseName: "bench press",
                reps: 9,
                weightKg: 50,
                rpe: 7,
                at: startedAt.addingTimeInterval(Double(DeloadPolicy.sessionsInDeload + 1) * 86_400)
            ),
            mode: .advance
        )

        let state: ProgressionState? = try? await DatabaseService.shared.read(
            collection: "progression_states",
            documentId: "\(userId):bench press"
        )
        XCTAssertEqual(state?.blockType, .accumulation, "The lift must not stay stuck in deload")
        XCTAssertEqual(state?.lastSessionReps, 9)
        XCTAssertEqual(state?.currentTargetReps, 10, "The ask climbs to last+1 within the restored window")
        XCTAssertGreaterThan(state?.currentTargetReps ?? 0, deloadFloor, "Target is not frozen at the deload floor")
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
        plannedReps: Int? = nil,
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
                    plannedReps: "\(plannedReps ?? reps)",
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
