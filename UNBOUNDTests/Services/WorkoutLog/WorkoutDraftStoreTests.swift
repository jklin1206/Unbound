import XCTest
@testable import UNBOUND

@MainActor
final class WorkoutDraftStoreTests: XCTestCase {
    private func tmpStore() -> WorkoutDraftStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return WorkoutDraftStore(directory: dir)
    }
    private func session() -> ActiveWorkoutSession {
        ActiveWorkoutSession(workout: Workout(name: "Pull", targetMuscleGroups: [],
            warmup: [], mainExercises: [
                Exercise(id: "e1", name: "Row", muscleGroups: [.back], sets: 2, reps: "10",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil)],
            cooldown: [], estimatedMinutes: 20, notes: nil, blockType: nil),
            programId: "p", dayNumber: 2)
    }
    func test_saveThenLoadRoundTrips() throws {
        let store = tmpStore()
        let s = session()
        s.logCurrentSet(weightKg: 60, reps: 10)
        try store.save(s)
        let restored = try XCTUnwrap(store.load())
        XCTAssertEqual(restored.plannedWorkoutName, "Pull")
        XCTAssertEqual(restored.exercises[0].sets[0].weightKg, 60)
    }
    func test_loadReturnsNilWhenNoDraft() {
        XCTAssertNil(tmpStore().load())
    }
    func test_clearRemovesDraft() throws {
        let store = tmpStore()
        try store.save(session())
        XCTAssertNotNil(store.load())
        store.clear()
        XCTAssertNil(store.load())
    }
    func test_hasDraftReflectsState() throws {
        let store = tmpStore()
        XCTAssertFalse(store.hasDraft)
        try store.save(session())
        XCTAssertTrue(store.hasDraft)
        store.clear()
        XCTAssertFalse(store.hasDraft)
    }
}
