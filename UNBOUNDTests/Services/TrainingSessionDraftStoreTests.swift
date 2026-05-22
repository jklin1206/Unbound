import XCTest
@testable import UNBOUND

final class TrainingSessionDraftStoreTests: XCTestCase {
    func testRecentDraftStoreSavesMostRecentFirstAndDedupes() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("recent-training-drafts.json")
        let store = TrainingSessionDraftStore(fileURL: fileURL)

        var first = TrainingSessionDraft(
            id: "draft-1",
            userId: "u1",
            source: .custom,
            title: "Mixed Pull",
            estimatedMinutes: 30,
            blocks: [
                TrainingBlock(
                    kind: .custom,
                    title: "Pull-up",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Pull-up",
                            sets: 3,
                            target: .repsRange(5, 8),
                            restSeconds: 120
                        )
                    ]
                )
            ]
        )
        let second = TrainingSessionDraft(
            id: "draft-2",
            userId: "u1",
            source: .custom,
            title: "Cardio Carry",
            estimatedMinutes: 20,
            blocks: [
                TrainingBlock(
                    kind: .cardio,
                    title: "Row",
                    cardioType: .row,
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Row",
                            sets: 1,
                            target: .distanceMeters(400),
                            restSeconds: 0
                        )
                    ]
                )
            ]
        )

        store.saveRecent(first)
        store.saveRecent(second)
        first.title = "Mixed Pull Edited"
        store.saveRecent(first)

        let recent = store.loadRecent()
        XCTAssertEqual(recent.map(\.id), ["draft-1", "draft-2"])
        XCTAssertEqual(recent.first?.title, "Mixed Pull Edited")
        XCTAssertEqual(recent.first?.blocks.first?.prescriptions.first?.target, .repsRange(5, 8))
        XCTAssertEqual(recent.last?.blocks.first?.cardioType, .row)
    }
}
