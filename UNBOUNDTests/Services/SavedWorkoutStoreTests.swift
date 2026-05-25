import XCTest
@testable import UNBOUND

final class SavedWorkoutStoreTests: XCTestCase {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("saved-workouts-\(UUID().uuidString)")
            .appendingPathComponent("saved-workouts.json")
    }

    private func sampleWorkout(id: UUID = UUID(), title: String = "My Pull A", role: String? = "pull") -> SavedWorkout {
        SavedWorkout(
            id: id,
            title: title,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: title,
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pull-Up",
                            sets: 3,
                            target: .repsRange(6, 8),
                            restSeconds: 120,
                            muscleGroups: [.back, .arms],
                            rpe: 8
                        )
                    ]
                )
            ],
            sessionRole: role,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
    }

    func testSaveRoundTripsAcrossStoreInstances() {
        let url = tempFileURL()
        let store = SavedWorkoutStore(fileURL: url)
        let workout = sampleWorkout(title: "My Vert Pull A", role: "Pull")

        store.save(workout)

        let reloaded = SavedWorkoutStore(fileURL: url)
        XCTAssertEqual(reloaded.all().count, 1)
        XCTAssertEqual(reloaded.get(id: workout.id)?.title, "My Vert Pull A")
        XCTAssertEqual(reloaded.get(id: workout.id)?.sessionRole, "pull")
        XCTAssertEqual(reloaded.get(id: workout.id)?.blocks.first?.prescriptions.first?.exerciseName, "Pull-Up")
    }

    func testSaveIsIdempotentByID() {
        let url = tempFileURL()
        let store = SavedWorkoutStore(fileURL: url)
        let id = UUID()

        store.save(sampleWorkout(id: id, title: "Push A", role: "push"))
        store.save(sampleWorkout(id: id, title: "Push A Updated", role: "push"))

        XCTAssertEqual(store.all().count, 1)
        XCTAssertEqual(store.get(id: id)?.title, "Push A Updated")
    }

    func testMultipleWorkoutsAreSortedByOrderThenUpdatedAt() {
        let url = tempFileURL()
        let store = SavedWorkoutStore(fileURL: url)

        var second = sampleWorkout(title: "Second", role: "upper")
        second.order = 2
        var first = sampleWorkout(title: "First", role: "upper")
        first.order = 1

        store.save(second)
        store.save(first)

        XCTAssertEqual(store.all().map(\.title), ["First", "Second"])
    }

    func testDeleteRemovesOnlyMatchingWorkout() {
        let url = tempFileURL()
        let store = SavedWorkoutStore(fileURL: url)
        let keep = sampleWorkout(title: "Keep")
        let remove = sampleWorkout(title: "Remove")

        store.save(keep)
        store.save(remove)
        store.delete(id: remove.id)

        XCTAssertEqual(store.all().map(\.id), [keep.id])
        XCTAssertNil(store.get(id: remove.id))
    }
}
