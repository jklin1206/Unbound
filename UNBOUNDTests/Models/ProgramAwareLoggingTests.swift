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

    func test_recomputeLogged_transitionsOnceAndNeverUnlogs() {
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
    }

    func test_assembleWorkoutLog_onlyLoggedSets_unchangedContract() {
        let s = ActiveWorkoutSession(workout: workout([ex("Bench Press", sets: 2)]),
                                     programId: "p", dayNumber: 1)
        s.exercises[0].sets[0].suggestedWeightKg = 60
        s.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].weightKg, 60)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].reps, 8)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 8)
    }

    func test_legacyWorkoutLoggerFlushesUnifiedReceiptAndCompatibleLogOnce() async throws {
        let services = ServiceContainer.mock
        let viewModel = WorkoutLoggingViewModel(
            workout: workout([ex("Bench Press", sets: 1, reps: "5")]),
            programId: "legacy-program",
            dayNumber: 2,
            services: services
        )
        viewModel.startTime = Date().addingTimeInterval(-600)
        viewModel.overallRPE = 8
        viewModel.exerciseEntries[0].sets[0].weightKg = WeightPlatePolicy.formatLoggedWeight(
            100,
            unit: WeightPlatePolicy.currentUnit
        )
        viewModel.exerciseEntries[0].sets[0].reps = "5"
        viewModel.exerciseEntries[0].sets[0].rpe = 8

        let savedPreview = await viewModel.saveLog()
        let preview = try XCTUnwrap(savedPreview)
        let summary = try XCTUnwrap(viewModel.trainingReceiptSummary(for: preview))
        let workoutLog = try XCTUnwrap(services.workoutLog as? MockWorkoutLogService)
        let database = try XCTUnwrap(services.database as? MockDatabaseService)

        XCTAssertNil(preview.savedPerformanceLogId)
        XCTAssertGreaterThan(preview.totalMovementAP, 0)
        XCTAssertEqual(summary.workoutName, "Push Day")
        XCTAssertEqual(summary.workSets, 1)
        XCTAssertNotNil(summary.progression)
        XCTAssertTrue(workoutLog.logs.isEmpty)
        XCTAssertFalse(database.store.keys.contains { $0.hasPrefix("performanceLogs/") })
        XCTAssertFalse(database.store.keys.contains { $0.hasPrefix("training_completion_records/") })

        await viewModel.flushPendingCompletionEffects()

        XCTAssertEqual(workoutLog.logs.count, 1)
        let savedLog = try XCTUnwrap(workoutLog.logs.first)
        let record: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: savedLog.id
        )
        let performanceLog: PerformanceLog = try await database.read(
            collection: "performanceLogs",
            documentId: savedLog.id
        )

        XCTAssertEqual(record.performanceLogId, savedLog.id)
        XCTAssertEqual(record.userId, "mock-user-123")
        XCTAssertEqual(performanceLog.id, savedLog.id)
        XCTAssertEqual(performanceLog.title, "Push Day")

        await viewModel.flushPendingCompletionEffects()
        XCTAssertEqual(workoutLog.logs.count, 1)
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
