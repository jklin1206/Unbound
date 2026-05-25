import XCTest
@testable import UNBOUND

final class WaveAdjustmentStoreTests: XCTestCase {
    func testMarkRevertedPersistsPerUserAndProgram() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WaveAdjustmentStore(directory: directory)

        store.markReverted("arc-1:wave2:start:3", userId: "user-1", programId: "program-1")
        store.markReverted("arc-1:wave2:start:4", userId: "user-1", programId: "program-1")
        store.markReverted("arc-2:wave2:start:1", userId: "user-1", programId: "program-2")

        let reloaded = WaveAdjustmentStore(directory: directory)

        XCTAssertEqual(
            reloaded.revertedAdjustmentIDs(userId: "user-1", programId: "program-1"),
            ["arc-1:wave2:start:3", "arc-1:wave2:start:4"]
        )
        XCTAssertEqual(
            reloaded.revertedAdjustmentIDs(userId: "user-1", programId: "program-2"),
            ["arc-2:wave2:start:1"]
        )
    }

    func testClearRemovesOnlyMatchingRecord() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = WaveAdjustmentStore(directory: directory)

        store.markReverted("a", userId: "user-1", programId: "program-1")
        store.markReverted("b", userId: "user-1", programId: "program-2")
        store.clear(userId: "user-1", programId: "program-1")

        XCTAssertTrue(store.revertedAdjustmentIDs(userId: "user-1", programId: "program-1").isEmpty)
        XCTAssertEqual(store.revertedAdjustmentIDs(userId: "user-1", programId: "program-2"), ["b"])
    }
}
