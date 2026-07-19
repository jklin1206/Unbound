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

    func test_workout_log_push_payload_maps_overall_rpe_to_column() throws {
        let log = WorkoutLog(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            programId: UUID().uuidString,
            dayNumber: 3,
            plannedWorkoutName: "Push Day",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 8,
            durationMinutes: 42
        )

        let normalized = SupabaseRemoteSync.normalizedPayload(
            collection: "workoutLogs",
            data: try JSONEncoder.unbound.encode(log)
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: normalized) as? [String: Any]
        )

        // Real column name, not the char-by-char acronym mangle.
        XCTAssertEqual(payload["overall_rpe"] as? Int, 8)
        XCTAssertNil(payload["overall_r_p_e"], "acronym must not leak the char-by-char snake key")
        XCTAssertNil(payload["overallRPE"])
    }

    func test_workout_log_overall_rpe_round_trips_through_push_and_pull() throws {
        let log = WorkoutLog(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            programId: UUID().uuidString,
            dayNumber: 3,
            plannedWorkoutName: "Push Day",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_600),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 9,
            durationMinutes: 42
        )

        // Push shapes the local doc into the remote (snake_case) column layout;
        // pull shapes a remote row back into the local (camelCase) layout.
        let pushed = SupabaseRemoteSync.normalizedPayload(
            collection: "workoutLogs",
            data: try JSONEncoder.unbound.encode(log)
        )
        let restored = SupabaseRemoteSync.localPayload(collection: "workoutLogs", data: pushed)
        let decoded = try JSONDecoder.unbound.decode(WorkoutLog.self, from: restored)

        XCTAssertEqual(decoded.overallRPE, 9)
    }

    func test_legacy_local_json_decodes_overall_rpe() throws {
        // Device-persisted logs store the acronym key verbatim ("overallRPE");
        // the seam fix does not change the local format, so old data must keep
        // decoding onto the property.
        let legacy = """
        {
          "id": "log-legacy",
          "userId": "user-1",
          "programId": "program-1",
          "dayNumber": 4,
          "plannedWorkoutName": "Legacy Day",
          "startedAt": "2026-06-01T10:00:00Z",
          "completedAt": "2026-06-01T10:45:00Z",
          "exerciseEntries": [],
          "overallRPE": 7,
          "durationMinutes": 45
        }
        """.data(using: .utf8)!

        let log = try JSONDecoder.unbound.decode(WorkoutLog.self, from: legacy)
        XCTAssertEqual(log.overallRPE, 7)
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
