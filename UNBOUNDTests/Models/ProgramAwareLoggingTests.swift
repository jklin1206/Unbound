import XCTest
@testable import UNBOUND

@MainActor
final class ProgramAwareLoggingTests: XCTestCase {

    private func ex(_ name: String, sets: Int = 3, reps: String = "8-10",
                    rpe: Int? = 8, notes: String? = "Brace hard",
                    sub: String? = "Machine variant") -> Exercise {
        Exercise(id: UUID().uuidString, name: name, muscleGroups: [.chest],
                 sets: sets, reps: reps, restSeconds: 150, rpe: rpe,
                 notes: notes, substitution: sub)
    }

    private func workout(_ exs: [Exercise]) -> Workout {
        Workout(name: "Push Day", targetMuscleGroups: [.chest],
                warmup: [], mainExercises: exs, cooldown: [],
                estimatedMinutes: 50, notes: nil, blockType: nil)
    }

    func test_repRange_lowerBound() {
        XCTAssertEqual(RepRange.lowerBound("8-10"), 8)
        XCTAssertEqual(RepRange.lowerBound("8"), 8)
        XCTAssertEqual(RepRange.lowerBound("12 each side"), 12)
        XCTAssertEqual(RepRange.lowerBound("30s"), 30)
        XCTAssertNil(RepRange.lowerBound("AMRAP"))
        XCTAssertNil(RepRange.lowerBound(""))
    }

    func test_initWorkout_seedsSuggestionsAndCarriesPrescription() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        let e = s.exercises[0]
        XCTAssertEqual(e.targetRPE, 8)
        XCTAssertEqual(e.formCues, "Brace hard")
        XCTAssertEqual(e.substitution, "Machine variant")
        XCTAssertEqual(e.sets.count, 3)
        XCTAssertEqual(e.sets[0].suggestedReps, 8)
        XCTAssertEqual(e.sets[0].suggestedRPE, 8)
        XCTAssertNil(e.sets[0].suggestedWeightKg)
        XCTAssertFalse(e.sets[0].logged)
    }

    func test_trainingDraftSetPlansBecomeActiveSetSuggestions() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .custom,
            title: "Bench Dropset",
            estimatedMinutes: 35,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Bench",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Bench Press",
                            sets: 3,
                            target: .reps(5),
                            restSeconds: 150,
                            muscleGroups: [.chest],
                            rpe: 8,
                            suggestedWeightKg: 100,
                            setPlans: [
                                TrainingSetPlan(
                                    target: .reps(5),
                                    restSeconds: 150,
                                    rpe: 8,
                                    suggestedWeightKg: 100
                                ),
                                TrainingSetPlan(
                                    target: .reps(6),
                                    restSeconds: 45,
                                    rpe: 9,
                                    suggestedWeightKg: 80
                                ),
                                TrainingSetPlan(
                                    target: .reps(12),
                                    restSeconds: 0,
                                    rpe: 9,
                                    suggestedWeightKg: 60
                                )
                            ]
                        )
                    ]
                )
            ]
        )

        let session = ActiveWorkoutSession(trainingDraft: draft)
        let exercise = session.exercises[0]

        XCTAssertEqual(exercise.plannedSets, 3)
        XCTAssertEqual(exercise.plannedReps, "custom sets")
        XCTAssertEqual(exercise.restSeconds, 150)
        XCTAssertEqual(exercise.sets.map(\.suggestedReps), [5, 6, 12])
        XCTAssertEqual(exercise.sets.map(\.suggestedRestSeconds), [150, 45, 0])
        XCTAssertEqual(exercise.sets.map(\.suggestedRPE), [8, 9, 9])
        // Draft→session ingest snaps suggestions to loadable plate weights so
        // confirm-as-planned logs what the user actually lifts. Anchor to the
        // policy, never hardcoded snapped values (locale-dependent unit).
        let expectedWeights: [Double?] = [100, 80, 60].map {
            WeightPlatePolicy.snappedSuggestionKilograms($0)
        }
        XCTAssertEqual(exercise.sets.map(\.suggestedWeightKg), expectedWeights)
    }

    func test_confirmAsPlanned_copiesSuggestedToActualAndLogs() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        let set = s.exercises[0].sets[0]
        XCTAssertTrue(set.logged)
        XCTAssertEqual(set.weightKg, 60)
        XCTAssertEqual(set.reps, 8)
        XCTAssertEqual(set.rpe, 8)
    }

    func test_confirmAsPlanned_preservesManualValuesWhenCheckingSet() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.exercises[0].sets[0].weightKg = 62.5
        s.exercises[0].sets[0].reps = 9

        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)

        let set = s.exercises[0].sets[0]
        XCTAssertTrue(set.logged)
        XCTAssertEqual(set.weightKg, 62.5)
        XCTAssertEqual(set.reps, 9)
        XCTAssertEqual(set.rpe, 8)
    }

    func test_initWorkout_infersHoldMetricForBodyweightSkill() {
        let s = ActiveWorkoutSession(
            workout: workout([ex("Hollow Body Hold", sets: 2, reps: "20s", sub: nil)]),
            programId: "p",
            dayNumber: 1
        )

        let exercise = s.exercises[0]
        XCTAssertEqual(exercise.metricKind, .holdSeconds)
        XCTAssertTrue(exercise.tracksHold)
        XCTAssertEqual(exercise.sets[0].suggestedHoldSeconds, 20)
        XCTAssertNil(exercise.sets[0].suggestedReps)

        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)

        let set = s.exercises[0].sets[0]
        XCTAssertTrue(set.logged)
        XCTAssertEqual(set.holdSeconds, 20)
        XCTAssertNil(set.reps)

        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets[0].durationSeconds, 20)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].reps, 20)
    }

    func testReplaceExerciseRefreshesMovementMetadataForSwaps() throws {
        let s = ActiveWorkoutSession(
            workout: workout([ex("Bench Press")]),
            programId: "p",
            dayNumber: 1
        )
        let pushup = try XCTUnwrap(MovementCatalog.catalogExercise(named: "Pushup"))
        let expected = MovementResolver.resolve("Pushup")

        s.replaceExercise(at: 0, with: pushup)

        let exercise = s.exercises[0]
        XCTAssertEqual(exercise.name, "Pushup")
        XCTAssertEqual(exercise.movementId, expected.movementId)
        XCTAssertEqual(exercise.rankStandardMovementId, expected.rankStandardMovementId)
        XCTAssertEqual(exercise.muscleGroups, pushup.muscleGroups)
        XCTAssertEqual(exercise.substitution, "Swapped from Bench Press")

        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        let performanceLog = s.assemblePerformanceLog(userId: "u")
        let loggedExercise = try XCTUnwrap(performanceLog.blocks.first?.exercises.first)
        XCTAssertEqual(loggedExercise.name, "Pushup")
        XCTAssertEqual(loggedExercise.movementId, expected.movementId)
        XCTAssertEqual(loggedExercise.rankStandardMovementId, expected.rankStandardMovementId)
    }

    func testAppendCustomExerciseAddsLoggableSessionExercise() {
        let s = ActiveWorkoutSession(
            workout: workout([ex("Bench Press")]),
            programId: "p",
            dayNumber: 1
        )
        let custom = CustomExercise(
            name: "cable row custom",
            displayName: "Cable Row Custom",
            pattern: .pullHorizontal,
            classification: .accessory,
            defaultRepMin: 10,
            defaultRepMax: 12,
            notes: "Keep torso still",
            userId: "u"
        )

        s.appendCustomExercise(custom)

        let exercise = s.exercises[1]
        XCTAssertEqual(exercise.name, "Cable Row Custom")
        XCTAssertEqual(exercise.plannedSets, 2)
        XCTAssertEqual(exercise.plannedReps, "10-12")
        XCTAssertEqual(exercise.restSeconds, 75)
        XCTAssertEqual(exercise.muscleGroups, [.back, .arms])
        XCTAssertEqual(exercise.sets.count, 2)
        XCTAssertEqual(exercise.sets[0].suggestedReps, 10)
        XCTAssertEqual(exercise.sets[0].suggestedRPE, 8)
        XCTAssertEqual(exercise.substitution, "Custom exercise")
    }

    func test_confirmAsPlanned_noopWhenAlreadyLogged() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].weightKg = 99
        s.exercises[0].sets[0].reps = 5
        s.exercises[0].sets[0].logged = true
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        XCTAssertEqual(s.exercises[0].sets[0].weightKg, 99)
        XCTAssertEqual(s.exercises[0].sets[0].reps, 5)
    }

    func test_recomputeLogged_transitionsOnceAndClearsWhenRequiredFieldsAreRemoved() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].weightKg = 62
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertFalse(s.exercises[0].sets[0].logged)
        s.exercises[0].sets[0].reps = 9
        XCTAssertTrue(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertTrue(s.exercises[0].sets[0].logged)
        s.exercises[0].sets[0].weightKg = 64
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertTrue(s.exercises[0].sets[0].logged)
        s.exercises[0].sets[0].reps = nil
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertFalse(s.exercises[0].sets[0].logged)
        XCTAssertNil(s.exercises[0].completedAt)
    }

    func test_recomputeLogged_backfillsSuggestedRPEOnManualEntry() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)

        s.exercises[0].sets[0].weightKg = 62
        s.exercises[0].sets[0].reps = 9

        XCTAssertTrue(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertEqual(s.exercises[0].sets[0].rpe, 8)
    }

    func test_recomputeLogged_requiresSuggestedLoadForLoadedRepSet() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press")]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60

        s.exercises[0].sets[0].reps = 8
        XCTAssertFalse(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertFalse(s.exercises[0].sets[0].logged)

        s.exercises[0].sets[0].weightKg = 60
        XCTAssertTrue(s.recomputeLogged(exerciseIndex: 0, setIndex: 0))
        XCTAssertTrue(s.exercises[0].sets[0].logged)
    }

    func test_assembleWorkoutLog_onlyLoggedSets_unchangedContract() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press", sets: 2)]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        s.toggleQualityFlag(.assisted, exerciseIndex: 0, setIndex: 0)
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].weightKg, 60)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].reps, 8)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 8)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].qualityFlags, Set([.assisted]))
    }

    func test_activeSet_decodesLegacyJSON_withoutSuggestionKeys() throws {
        let legacy = """
        {"id":"abc","weightKg":null,"reps":null,"rpe":null,
         "isWarmup":false,"logged":false}
        """.data(using: .utf8)!
        let set = try JSONDecoder().decode(
            ActiveWorkoutSession.ActiveSet.self, from: legacy)
        XCTAssertEqual(set.id, "abc")
        XCTAssertFalse(set.logged)
        XCTAssertNil(set.suggestedWeightKg)
        XCTAssertNil(set.suggestedReps)
        XCTAssertNil(set.suggestedRPE)
    }

    func test_activeExercise_decodesLegacyJSON_withoutNewKeys() throws {
        let legacy = """
        {"id":"e1","name":"Bench","plannedSets":3,"plannedReps":"8",
         "restSeconds":150,"muscleGroups":["chest"],"sets":[],
         "skipped":false,"notes":""}
        """.data(using: .utf8)!
        let e = try JSONDecoder().decode(
            ActiveWorkoutSession.ActiveExercise.self, from: legacy)
        XCTAssertEqual(e.name, "Bench")
        XCTAssertNil(e.targetRPE)
        XCTAssertNil(e.formCues)
        XCTAssertNil(e.substitution)
    }
}
