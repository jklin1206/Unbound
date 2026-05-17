import XCTest
@testable import UNBOUND

final class RemoteSyncMapTests: XCTestCase {
    func test_known_collections_map_to_tables() {
        XCTAssertEqual(SyncCollectionMap.table(for: "workoutLogs"), "workout_logs")
        XCTAssertEqual(SyncCollectionMap.table(for: "exercisePreferences"), "exercise_preferences")
        XCTAssertEqual(SyncCollectionMap.userColumn(for: "users"), "id")
        XCTAssertEqual(SyncCollectionMap.userColumn(for: "programs"), "user_id")
    }
    func test_unknown_collection_returns_nil_table() {
        XCTAssertNil(SyncCollectionMap.table(for: "notSynced"))
    }
}
