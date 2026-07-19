import XCTest
@testable import UNBOUND

@MainActor
final class WorkoutDraftStoreTests: XCTestCase {
    private func uniqueDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
    private func tmpStore() -> WorkoutDraftStore {
        WorkoutDraftStore(directory: uniqueDir())
    }
    private func workout(name: String) -> Workout {
        Workout(name: name, targetMuscleGroups: [],
            warmup: [], mainExercises: [
                Exercise(id: "e1", name: "Row", muscleGroups: [.back], sets: 2, reps: "10",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil)],
            cooldown: [], estimatedMinutes: 20, notes: nil, blockType: nil)
    }
    private func programSession() -> ActiveWorkoutSession {
        ActiveWorkoutSession(workout: workout(name: "Pull"), programId: "p", dayNumber: 2, source: .program)
    }
    private func customSession() -> ActiveWorkoutSession {
        ActiveWorkoutSession(workout: workout(name: "Quick Log"), programId: "", dayNumber: 0, source: .custom)
    }
    private func writeLegacy(_ session: ActiveWorkoutSession, to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(session.snapshot())
        try data.write(to: dir.appendingPathComponent("workout-draft.json"), options: .atomic)
    }

    // MARK: - Round-trip + slot basics

    func test_saveThenLoadRoundTripsProgramSlot() throws {
        let store = tmpStore()
        let s = programSession()
        s.logCurrentSet(weightKg: 60, reps: 10)
        try store.save(s)
        let restored = try XCTUnwrap(store.load(.program))
        XCTAssertEqual(restored.plannedWorkoutName, "Pull")
        XCTAssertEqual(restored.exercises[0].sets[0].weightKg, 60)
        XCTAssertNil(store.load(.custom))
    }
    func test_loadReturnsNilWhenNoDraft() {
        let store = tmpStore()
        XCTAssertNil(store.load(.program))
        XCTAssertNil(store.load(.custom))
        XCTAssertNil(store.load(.other))
    }
    func test_hasDraftReflectsState() throws {
        let store = tmpStore()
        XCTAssertFalse(store.hasDraft(in: .program))
        try store.save(programSession())
        XCTAssertTrue(store.hasDraft(in: .program))
        XCTAssertFalse(store.hasDraft(in: .custom))
        store.clear(.program)
        XCTAssertFalse(store.hasDraft(in: .program))
    }

    // (a) Program + custom drafts coexist - saving one leaves the other intact.
    func test_programAndCustomDraftsCoexist() throws {
        let store = tmpStore()
        let p = programSession(); p.logCurrentSet(weightKg: 60, reps: 10)
        let c = customSession(); c.logCurrentSet(weightKg: 20, reps: 12)
        try store.save(p)
        try store.save(c)
        XCTAssertEqual(store.load(.program)?.exercises.first?.sets.first?.weightKg, 60)
        XCTAssertEqual(store.load(.custom)?.exercises.first?.sets.first?.weightKg, 20)
        // Re-saving the custom draft must not disturb the program draft.
        c.logCurrentSet(weightKg: 22, reps: 12)
        try store.save(c)
        XCTAssertEqual(store.load(.program)?.exercises.first?.sets.first?.weightKg, 60)
    }

    // (b) Legacy single-file migration lands in the correct slot + deletes old file.
    func test_legacyMigrationLandsInProgramSlotAndDeletesOldFile() throws {
        let dir = uniqueDir()
        try writeLegacy(programSession(), to: dir)
        let legacyURL = dir.appendingPathComponent("workout-draft.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path))

        let store = WorkoutDraftStore(directory: dir)
        XCTAssertTrue(store.hasDraft(in: .program))
        XCTAssertFalse(store.hasDraft(in: .custom))
        XCTAssertEqual(store.load(.program)?.programId, "p")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }
    func test_legacyMigrationRoutesCustomPayloadToCustomSlot() throws {
        let dir = uniqueDir()
        try writeLegacy(customSession(), to: dir)

        let store = WorkoutDraftStore(directory: dir)
        XCTAssertTrue(store.hasDraft(in: .custom))
        XCTAssertFalse(store.hasDraft(in: .program))
        XCTAssertEqual(store.load(.custom)?.source, .custom)
    }

    // (c) Completion clears ONLY its own slot.
    func test_completionClearsOnlyItsOwnSlot() throws {
        let store = tmpStore()
        try store.save(programSession())
        try store.save(customSession())

        store.clear(for: customSession())   // finish the custom session
        XCTAssertNil(store.load(.custom))
        XCTAssertNotNil(store.load(.program))

        // And the reverse direction.
        try store.save(customSession())
        store.clear(for: programSession())
        XCTAssertNil(store.load(.program))
        XCTAssertNotNil(store.load(.custom))
    }

    // (d) Custom draft round-trips + is discoverable by the resume lookup, which
    // reads load(.custom) and requires non-empty exercises.
    func test_customDraftRoundTripsAndIsDiscoverable() throws {
        let store = tmpStore()
        let c = customSession(); c.logCurrentSet(weightKg: 25, reps: 8)
        try store.save(c)

        let restored = try XCTUnwrap(store.load(.custom))
        XCTAssertFalse(restored.exercises.isEmpty)
        XCTAssertEqual(restored.plannedWorkoutName, "Quick Log")
        XCTAssertEqual(restored.exercises.first?.sets.first?.weightKg, 25)
        XCTAssertEqual(restored.source, .custom)
    }

    func test_clearAllWipesEverySlot() throws {
        let store = tmpStore()
        try store.save(programSession())
        try store.save(customSession())
        store.clearAll()
        XCTAssertNil(store.load(.program))
        XCTAssertNil(store.load(.custom))
    }
}
