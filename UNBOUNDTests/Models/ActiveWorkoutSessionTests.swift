import XCTest
@testable import UNBOUND

@MainActor
final class ActiveWorkoutSessionTests: XCTestCase {
    private func workout() -> Workout {
        Workout(name: "Push", targetMuscleGroups: [],
            warmup: [],
            mainExercises: [
                Exercise(id: "e1", name: "Bench", muscleGroups: [.chest], sets: 2, reps: "8",
                         restSeconds: 120, rpe: nil, notes: nil, substitution: nil),
                Exercise(id: "e2", name: "Fly", muscleGroups: [.chest], sets: 1, reps: "12",
                         restSeconds: 60, rpe: nil, notes: nil, substitution: nil),
            ],
            cooldown: [], estimatedMinutes: 30, notes: nil, blockType: nil)
    }
    func test_buildsFromWorkout() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        XCTAssertEqual(s.exercises.count, 2)
        XCTAssertEqual(s.exercises[0].sets.count, 2)
        XCTAssertEqual(s.exercises[1].sets.count, 1)
        XCTAssertEqual(s.currentExerciseIndex, 0)
        XCTAssertEqual(s.currentSetIndex, 0)
        XCTAssertFalse(s.isLastSetOfWorkout)
    }
    func test_logCurrentSet_recordsAndAdvances() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        XCTAssertTrue(s.exercises[0].sets[0].logged)
        XCTAssertEqual(s.exercises[0].sets[0].weightKg, 80)
        XCTAssertEqual(s.exercises[0].sets[0].reps, 8)
        s.advance()
        XCTAssertEqual(s.currentExerciseIndex, 0)
        XCTAssertEqual(s.currentSetIndex, 1)
    }
    func test_advance_rollsToNextExercise() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.advance()
        s.logCurrentSet(weightKg: 80, reps: 7); s.advance()
        XCTAssertEqual(s.currentExerciseIndex, 1)
        XCTAssertEqual(s.currentSetIndex, 0)
    }
    func test_isLastSetOfWorkout_trueOnFinalSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8); s.advance()
        s.logCurrentSet(weightKg: 80, reps: 7); s.advance()
        XCTAssertTrue(s.isLastSetOfWorkout)
    }
    func test_setRPE_storesOnCurrentSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 9)
        XCTAssertEqual(s.exercises[0].sets[0].rpe, 9)
    }
    func test_addAndRemoveSet() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.addSetToCurrentExercise()
        XCTAssertEqual(s.exercises[0].sets.count, 3)
        s.removeLastSetFromCurrentExercise()
        XCTAssertEqual(s.exercises[0].sets.count, 2)
    }
    func test_skipCurrentExercise_marksAndJumps() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.skipCurrentExercise()
        XCTAssertTrue(s.exercises[0].skipped)
        XCTAssertEqual(s.currentExerciseIndex, 1)
    }
    func test_jumpToExercise() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.jumpToExercise(1)
        XCTAssertEqual(s.currentExerciseIndex, 1)
        XCTAssertEqual(s.currentSetIndex, 0)
        s.jumpToExercise(99)
        XCTAssertEqual(s.currentExerciseIndex, 1)
    }
    func test_assembleWorkoutLog_matchesModel() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 8)
        s.advance()
        s.logCurrentSet(weightKg: 82.5, reps: 6)
        s.setRPE(exerciseIndex: 0, setIndex: 1, 9)
        s.advance()
        s.skipCurrentExercise()
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.userId, "u")
        XCTAssertEqual(log.programId, "p")
        XCTAssertEqual(log.dayNumber, 1)
        XCTAssertEqual(log.plannedWorkoutName, "Push")
        XCTAssertEqual(log.exerciseEntries.count, 2)
        let bench = log.exerciseEntries[0]
        XCTAssertEqual(bench.exerciseName, "Bench")
        XCTAssertEqual(bench.sets.count, 2)
        XCTAssertEqual(bench.sets[0].setNumber, 1)
        XCTAssertEqual(bench.sets[0].weightKg, 80)
        XCTAssertEqual(bench.sets[0].reps, 8)
        XCTAssertEqual(bench.sets[0].rpe, 8)
        XCTAssertEqual(bench.sets[1].rpe, 9)
        XCTAssertTrue(log.exerciseEntries[1].skipped)
        XCTAssertNotNil(log.completedAt)
        XCTAssertNotNil(log.durationMinutes)
    }
    func test_snapshotRoundTrip() throws {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logCurrentSet(weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 8)
        s.advance()
        let data = try JSONEncoder().encode(s.snapshot())
        let snap = try JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        let restored = ActiveWorkoutSession(snapshot: snap)
        XCTAssertEqual(restored.exercises[0].sets[0].weightKg, 80)
        XCTAssertEqual(restored.exercises[0].sets[0].rpe, 8)
        XCTAssertEqual(restored.currentSetIndex, 1)
        XCTAssertEqual(restored.plannedWorkoutName, "Push")
    }
}
