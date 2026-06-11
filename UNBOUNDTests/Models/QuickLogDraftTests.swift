import XCTest
@testable import UNBOUND

@MainActor
final class QuickLogDraftTests: XCTestCase {
    func test_empty_producesCustomDraftWithNoBlocks() {
        let draft = QuickLogDraftFactory.empty(userId: "u1")
        XCTAssertEqual(draft.userId, "u1")
        XCTAssertEqual(draft.source, .custom)
        XCTAssertTrue(draft.blocks.isEmpty, "Quick Log starts empty; user adds exercises live")
        XCTAssertEqual(draft.title, "Quick Log")
    }

    func test_emptyDraft_makesAnEmptyActiveSessionYouCanAppendTo() {
        let draft = QuickLogDraftFactory.empty(userId: "u1")
        let session = ActiveWorkoutSession(trainingDraft: draft)
        XCTAssertTrue(session.exercises.isEmpty, "empty draft → empty session")
    }

    func test_savedWorkoutDraftFactory_producesReusableWorkoutDraftCopy() {
        let draft = SavedWorkoutDraftFactory.empty(userId: "u1")

        XCTAssertEqual(draft.userId, "u1")
        XCTAssertEqual(draft.source, .custom)
        XCTAssertTrue(draft.blocks.isEmpty)
        XCTAssertEqual(draft.title, "New Workout")
    }
}
