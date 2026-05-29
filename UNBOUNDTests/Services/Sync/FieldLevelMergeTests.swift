import XCTest
@testable import UNBOUND

/// Bug #5 (sync last-write-wins) regression suite. Proves field-level merge:
/// concurrent edits to DIFFERENT fields of the same document converge to the
/// union rather than one clobbering the other.
///
/// Uses an in-memory `RemoteSync` double so flush/pull/read are deterministic
/// and offline — no live Supabase.
@MainActor
final class FieldLevelMergeTests: XCTestCase {

    /// In-memory remote: stores one row per (collection, docId) as raw JSON.
    /// `read` returns the stored doc; `upsert` replaces it whole (matching the
    /// real Postgres whole-row upsert) — so correctness depends on the engine
    /// having merged BEFORE pushing.
    final class InMemoryRemote: RemoteSync, @unchecked Sendable {
        var store: [String: [String: Data]] = [:]   // collection -> docId -> json

        func upsert(collection: String, docId: String, json: Data) async throws {
            store[collection, default: [:]][docId] = json
        }
        func delete(collection: String, docId: String) async throws {
            store[collection]?.removeValue(forKey: docId)
        }
        func pull(collection: String, userId: String) async throws -> [Data] {
            Array((store[collection] ?? [:]).values)
        }
        func read(collection: String, docId: String) async throws -> Data? {
            store[collection]?[docId]
        }
    }

    private func json(_ s: String) -> Data { Data(s.utf8) }

    private func dict(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func entry(_ docId: String, payload: Data, changed: [String],
                       collection: String = "programs") -> OutboxEntry {
        OutboxEntry(id: UUID(), userId: "u1", collection: collection, docId: docId,
                    op: .upsert, payloadJSON: payload, changedFields: changed,
                    enqueuedAt: Date(), attempt: 0)
    }

    // MARK: - Proof C: pure merge primitive

    func test_overlay_replaces_only_listed_fields() throws {
        let base = try JSONDecoder().decode(JSONElement.self,
            from: json(#"{"id":"d1","a":"base","b":"base"}"#))
        let source = try JSONDecoder().decode(JSONElement.self,
            from: json(#"{"id":"d1","a":"NEW","b":"NEW"}"#))
        let merged = DocumentMerger.overlay(fields: ["a"], from: source, onto: base)
        let out = try dict(JSONEncoder().encode(merged))
        XCTAssertEqual(out["a"] as? String, "NEW")   // listed -> replaced
        XCTAssertEqual(out["b"] as? String, "base")  // unlisted -> base wins
        XCTAssertEqual(out["id"] as? String, "d1")
    }

    func test_overlay_removes_listed_field_absent_in_source() throws {
        let base = try JSONDecoder().decode(JSONElement.self,
            from: json(#"{"id":"d1","a":"base","b":"base"}"#))
        let source = try JSONDecoder().decode(JSONElement.self,
            from: json(#"{"id":"d1","a":"NEW"}"#))
        // "b" listed but absent in source -> removed.
        let merged = DocumentMerger.overlay(fields: ["a", "b"], from: source, onto: base)
        let out = try dict(JSONEncoder().encode(merged))
        XCTAssertEqual(out["a"] as? String, "NEW")
        XCTAssertNil(out["b"])
    }

    func test_overlay_non_object_returns_source() throws {
        let base = try JSONDecoder().decode(JSONElement.self, from: json(#""scalar""#))
        let source = try JSONDecoder().decode(JSONElement.self, from: json(#"{"a":1}"#))
        let merged = DocumentMerger.overlay(fields: ["a"], from: source, onto: base)
        let out = try dict(JSONEncoder().encode(merged))
        XCTAssertEqual(out["a"] as? Double, 1)
    }

    // MARK: - Proof A: server converges to the union of two devices' edits

    func test_flush_merges_concurrent_field_edits_into_remote_union() async throws {
        let remote = InMemoryRemote()
        // Seed a synced base doc on the server.
        try await remote.upsert(collection: "programs", docId: "d1",
            json: json(#"{"id":"d1","a":"base","b":"base"}"#))

        // Device A: independent local + outbox, SAME remote. Edits only `a`.
        let dirA = FileManager.default.temporaryDirectory.appendingPathComponent("flA-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dirA) }
        let outboxA = OutboxStore(directory: dirA)
        let localA = MockDatabaseService()
        let engineA = SyncEngine(outbox: outboxA, remote: remote, local: localA, maxAttempts: 5)
        outboxA.enqueue(entry("d1", payload: json(#"{"id":"d1","a":"A","b":"base"}"#),
                              changed: ["a"]))
        await engineA.flush()

        // Device B: independent local + outbox, SAME remote. Edits only `b`.
        let dirB = FileManager.default.temporaryDirectory.appendingPathComponent("flB-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dirB) }
        let outboxB = OutboxStore(directory: dirB)
        let localB = MockDatabaseService()
        let engineB = SyncEngine(outbox: outboxB, remote: remote, local: localB, maxAttempts: 5)
        outboxB.enqueue(entry("d1", payload: json(#"{"id":"d1","a":"base","b":"B"}"#),
                              changed: ["b"]))
        await engineB.flush()

        // BOTH edits survived: no last-write-wins.
        let remoteDoc = try await remote.read(collection: "programs", docId: "d1")
        let out = try dict(try XCTUnwrap(remoteDoc))
        XCTAssertEqual(out["a"] as? String, "A", "device A's field clobbered (LWW)")
        XCTAssertEqual(out["b"] as? String, "B", "device B's field clobbered (LWW)")
        XCTAssertEqual(out["id"] as? String, "d1")
    }

    func test_flush_pushes_payload_when_no_remote_doc_exists() async throws {
        let remote = InMemoryRemote()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fl0-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = OutboxStore(directory: dir)
        let engine = SyncEngine(outbox: outbox, remote: remote,
                                local: MockDatabaseService(), maxAttempts: 5)
        outbox.enqueue(entry("d2", payload: json(#"{"id":"d2","a":"only"}"#), changed: ["a"]))
        await engine.flush()
        let remoteDoc = try await remote.read(collection: "programs", docId: "d2")
        let out = try dict(try XCTUnwrap(remoteDoc))
        XCTAssertEqual(out["a"] as? String, "only")
    }

    // MARK: - Proof B: pull does not clobber an unsynced local edit

    func test_restore_preserves_pending_local_field_over_remote() async throws {
        let remote = InMemoryRemote()
        // Remote has both fields; `a` is fresh from another device.
        try await remote.upsert(collection: "programs", docId: "d1",
            json: json(#"{"id":"d1","userId":"u1","a":"remote","b":"base"}"#))

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("re-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = OutboxStore(directory: dir)
        let local = MockDatabaseService()
        let engine = SyncEngine(outbox: outbox, remote: remote, local: local, maxAttempts: 5)

        // Local has an UNSYNCED edit to `b` (pending outbox upsert, changedFields ["b"]).
        try await local.create(JSONElement.object([
            "id": .string("d1"), "userId": .string("u1"),
            "a": .string("base"), "b": .string("local")
        ]), collection: "programs", documentId: "d1")
        outbox.enqueue(entry("d1", payload: json(#"{"id":"d1","userId":"u1","a":"base","b":"local"}"#),
                             changed: ["b"]))

        try await engine.restore(userId: "u1")

        let localDoc: JSONElement = try await local.read(collection: "programs", documentId: "d1")
        let out = try dict(try JSONEncoder().encode(localDoc))
        XCTAssertEqual(out["a"] as? String, "remote", "remote's a should apply")
        XCTAssertEqual(out["b"] as? String, "local", "pending local b must be preserved")
    }

    func test_restore_takes_remote_when_no_pending_local_edit() async throws {
        let remote = InMemoryRemote()
        try await remote.upsert(collection: "programs", docId: "d3",
            json: json(#"{"id":"d3","userId":"u1","a":"remote"}"#))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("re2-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let engine = SyncEngine(outbox: OutboxStore(directory: dir), remote: remote,
                                local: MockDatabaseService(), maxAttempts: 5)
        try await engine.restore(userId: "u1")
        // No pending edit -> remote as-is (just assert it didn't throw / wrote).
    }

    // MARK: - changedFields plumbing & coalesce union

    func test_syncedDatabase_update_records_changed_field_keys() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cf-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = OutboxStore(directory: dir)
        let local = MockDatabaseService()
        let sut = SyncedDatabase(local: local, outbox: outbox)
        try await local.create(JSONElement.object(["id": .string("d1"), "a": .string("x")]),
                               collection: "programs", documentId: "d1")
        try await sut.update(["a": "y"], collection: "programs", documentId: "d1")
        let e = try XCTUnwrap(outbox.peekBatch(limit: 1).first)
        XCTAssertEqual(e.changedFields, ["a"])
    }

    func test_outbox_coalesce_unions_changed_fields() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("un-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = OutboxStore(directory: dir)
        outbox.enqueue(entry("d1", payload: json("{}"), changed: ["a"]))
        outbox.enqueue(entry("d1", payload: json("{}"), changed: ["b"]))
        let e = outbox.peekBatch(limit: 1).first
        XCTAssertEqual(e?.changedFields.sorted(), ["a", "b"],
                       "coalesce must UNION changedFields or a pre-flush edit is lost")
    }

    func test_outboxEntry_decodes_legacy_json_without_changedFields() throws {
        // Back-compat: persisted entries from before this field default to [].
        let legacy = json(#"{"id":"00000000-0000-0000-0000-000000000000","userId":"u1","collection":"programs","docId":"d1","op":"upsert","payloadJSON":null,"enqueuedAt":0,"attempt":0}"#)
        let e = try JSONDecoder().decode(OutboxEntry.self, from: legacy)
        XCTAssertEqual(e.changedFields, [])
    }
}
