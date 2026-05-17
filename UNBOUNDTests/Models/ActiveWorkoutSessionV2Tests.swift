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

    func test_logSet_anyOrder_recordsAndDefaultsEffortSolid() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 1, setIndex: 0, weightKg: 30, reps: 12)
        XCTAssertTrue(s.exercises[1].sets[0].logged)
        XCTAssertEqual(s.exercises[1].sets[0].weightKg, 30)
        XCTAssertEqual(s.exercises[1].sets[0].reps, 12)
        XCTAssertEqual(s.exercises[1].sets[0].effort, .solid)
        XCTAssertFalse(s.exercises[0].sets[0].logged)
    }
    func test_setEffort_indexAddressed() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 2, weightKg: 80, reps: 8)
        s.setEffort(exerciseIndex: 0, setIndex: 2, .hard)
        XCTAssertEqual(s.exercises[0].sets[2].effort, .hard)
    }
    func test_cycleEffort_order_easySolidHardWrap() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)   // → .solid
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // solid → hard
        XCTAssertEqual(s.exercises[0].sets[0].effort, .hard)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // hard → easy
        XCTAssertEqual(s.exercises[0].sets[0].effort, .easy)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // easy → solid
        XCTAssertEqual(s.exercises[0].sets[0].effort, .solid)
    }
    func test_logSet_outOfRange_isNoOp() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 9, setIndex: 9, weightKg: 1, reps: 1)
        XCTAssertFalse(s.exercises[0].sets[0].logged)
        s.cycleEffort(exerciseIndex: 9, setIndex: 9)
    }
    func test_addAndRemoveSet_indexAddressed() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.addSet(toExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 3)
        s.removeLastSet(fromExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 2)
        s.removeLastSet(fromExerciseIndex: 9)   // no-op, no crash
    }
    func test_assembleWorkoutLog_afterAnyOrderLogging() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.cycleEffort(exerciseIndex: 0, setIndex: 0)                     // solid → hard
        s.logSet(exerciseIndex: 1, setIndex: 1, weightKg: 30, reps: 11)
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 9)            // hard → 9
        XCTAssertEqual(log.exerciseEntries[1].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[1].sets[0].rpe, 8)            // solid default → 8
    }
}
