import XCTest
@testable import UNBOUND

final class RemoteSyncMapTests: XCTestCase {
    func test_known_collections_map_to_tables() {
        XCTAssertEqual(SyncCollectionMap.table(for: "workoutLogs"), "workout_logs")
        XCTAssertEqual(SyncCollectionMap.table(for: "exercisePreferences"), "exercise_preferences")
        XCTAssertEqual(SyncCollectionMap.table(for: "program_blocks"), "program_blocks")
        XCTAssertEqual(SyncCollectionMap.userColumn(for: "users"), "id")
        XCTAssertEqual(SyncCollectionMap.userColumn(for: "programs"), "user_id")
    }

    func test_synced_collections_include_canonical_program_block_but_not_localOnlyProgressionKeys() {
        XCTAssertTrue(SyncCollectionMap.syncedCollections.contains("program_blocks"))
        XCTAssertFalse(SyncCollectionMap.syncedCollections.contains("progression_states"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("progression_states"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("movement_progress"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("movement_progress_source_receipts"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("body_map_profiles"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("body_map_source_receipts"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("training_completion_replay_receipts"))
        XCTAssertTrue(SyncCollectionMap.isLocalOnly("training_completion_progression_receipts"))
        XCTAssertFalse(SyncCollectionMap.syncedCollections.contains("programBlocks"))
        XCTAssertFalse(SyncCollectionMap.syncedCollections.contains("progressionState"))
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

    func test_workout_log_payload_allows_non_program_remote_sources() throws {
        let log = WorkoutLog(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            programId: "",
            dayNumber: 0,
            plannedWorkoutName: "Wall Handstand",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 10
        )

        let normalized = SupabaseRemoteSync.normalizedPayload(
            collection: "workoutLogs",
            data: try JSONEncoder.unbound.encode(log)
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: normalized) as? [String: Any]
        )

        XCTAssertTrue(payload["program_id"] is NSNull)
        XCTAssertEqual(payload["day_number"] as? Int, 0)
        XCTAssertEqual(payload["planned_workout_name"] as? String, "Wall Handstand")
    }

    func test_workout_log_payload_preserves_uuid_program_id() throws {
        let programId = UUID().uuidString
        let log = WorkoutLog(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            programId: programId,
            dayNumber: 2,
            plannedWorkoutName: "Program Day",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 10
        )

        let normalized = SupabaseRemoteSync.normalizedPayload(
            collection: "workoutLogs",
            data: try JSONEncoder.unbound.encode(log)
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: normalized) as? [String: Any]
        )

        XCTAssertEqual(payload["program_id"] as? String, programId)
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

    func test_workout_log_pull_payload_restores_null_program_id_as_empty_string() throws {
        let remote = """
        {
          "id": "log-1",
          "user_id": "user-1",
          "program_id": null,
          "day_number": 0,
          "planned_workout_name": "Wall Handstand",
          "started_at": "2026-06-01T10:00:00Z",
          "completed_at": "2026-06-01T10:10:00Z",
          "duration_minutes": 10,
          "overall_rpe": null,
          "overall_notes": null,
          "exercise_entries": []
        }
        """.data(using: .utf8)!

        let local = SupabaseRemoteSync.localPayload(collection: "workoutLogs", data: remote)
        let log = try JSONDecoder.unbound.decode(WorkoutLog.self, from: local)

        XCTAssertEqual(log.programId, "")
        XCTAssertEqual(log.dayNumber, 0)
        XCTAssertEqual(log.plannedWorkoutName, "Wall Handstand")
    }
}
