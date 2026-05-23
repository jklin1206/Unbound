import XCTest
@testable import UNBOUND

@MainActor
final class ActiveWorkoutSessionV2Tests: XCTestCase {
    private func workout() -> Workout {
        Workout(name: "Push", targetMuscleGroups: [], warmup: [],
            mainExercises: [
                Exercise(id: "e1", name: "Bench", muscleGroups: [.chest], sets: 3, reps: "8",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil),
                Exercise(id: "e2", name: "Fly", muscleGroups: [.chest], sets: 2, reps: "12",
                         restSeconds: 60, rpe: nil, notes: nil, substitution: nil),
            ], cooldown: [], estimatedMinutes: 30, notes: nil, blockType: nil)
    }
    func test_logSet_anyOrder_recordsNoRPEByDefault() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 1, setIndex: 0, weightKg: 30, reps: 12)
        XCTAssertTrue(s.exercises[1].sets[0].logged)
        XCTAssertEqual(s.exercises[1].sets[0].weightKg, 30)
        XCTAssertEqual(s.exercises[1].sets[0].reps, 12)
        XCTAssertNil(s.exercises[1].sets[0].rpe)
        XCTAssertFalse(s.exercises[0].sets[0].logged)
    }
    func test_setRPE_indexAddressed_setAndClear() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 2, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 2, 8)
        XCTAssertEqual(s.exercises[0].sets[2].rpe, 8)
        s.setRPE(exerciseIndex: 0, setIndex: 2, 10)
        XCTAssertEqual(s.exercises[0].sets[2].rpe, 10)
        s.setRPE(exerciseIndex: 0, setIndex: 2, nil)
        XCTAssertNil(s.exercises[0].sets[2].rpe)
    }
    func test_setRPE_outOfRange_isNoOp() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.setRPE(exerciseIndex: 9, setIndex: 9, 8)
        XCTAssertNil(s.exercises[0].sets[0].rpe)
    }
    func test_addAndRemoveSet_indexAddressed() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.addSet(toExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 3)
        s.removeLastSet(fromExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 2)
        s.removeLastSet(fromExerciseIndex: 9)
    }
    func test_assembleWorkoutLog_passesRPEStraight() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 9)
        s.logSet(exerciseIndex: 1, setIndex: 1, weightKg: 30, reps: 11)
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 9)
        XCTAssertEqual(log.exerciseEntries[1].sets.count, 1)
        XCTAssertNil(log.exerciseEntries[1].sets[0].rpe)
    }
    func test_snapshotRoundTrip_preservesRPE() throws {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 7)
        let data = try JSONEncoder().encode(s.snapshot())
        let snap = try JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        let r = ActiveWorkoutSession(snapshot: snap)
        XCTAssertEqual(r.exercises[0].sets[0].rpe, 7)
        XCTAssertTrue(r.exercises[0].sets[0].logged)
    }
}
