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

    func test_program_payload_matches_current_supabase_schema() throws {
        let program = ProgramTestFactory.makeProgram(
            days: [ProgramTestFactory.makeDay(dayNumber: 1)],
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            withArc: true
        )
        let localJSON = try JSONEncoder.unbound.encode(program)

        let normalized = SupabaseRemoteSync.normalizedPayload(
            collection: "programs",
            data: localJSON
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: normalized) as? [String: Any]
        )

        XCTAssertEqual(payload["id"] as? String, program.id)
        XCTAssertEqual(payload["user_id"] as? String, program.userId)
        XCTAssertEqual(payload["archetype"] as? String, "universal")
        XCTAssertNil(payload["scan_id"])
        XCTAssertNil(payload["analysis_id"])
        XCTAssertNil(payload["arcs"])
        XCTAssertNil(payload["current_arc_id"])
        XCTAssertNil(payload["rationale"])
        XCTAssertNotNil(payload["days"])
        XCTAssertNotNil(payload["nutrition_plan"])
        XCTAssertNotNil(payload["recovery_plan"])
    }

    func test_pull_payload_is_camel_cased_for_local_restore() throws {
        let remote = """
        {
          "id": "program-1",
          "user_id": "user-1",
          "current_program_id": "program-1",
          "days": [
            {
              "id": "day-1",
              "day_number": 1,
              "recovery_activities": []
            }
          ]
        }
        """.data(using: .utf8)!

        let local = SupabaseRemoteSync.camelCasedJSON(remote)
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: local) as? [String: Any]
        )
        let days = try XCTUnwrap(payload["days"] as? [[String: Any]])

        XCTAssertEqual(payload["userId"] as? String, "user-1")
        XCTAssertEqual(payload["currentProgramId"] as? String, "program-1")
        XCTAssertEqual(days.first?["dayNumber"] as? Int, 1)
        XCTAssertNotNil(days.first?["recoveryActivities"])
    }
}
