# Offline-First Sync: Unified Outbox — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every personalizing edit (coach/skill/user) and workout durable offline and reliably synced to Supabase through one outbox, with scan-gated monthly rollover.

**Architecture:** Local-authoritative single-device. All mutations pass through one `SyncedDatabase` decorator that writes the local file store then enqueues an `OutboxEntry`. A `SyncEngine` drains the outbox to Supabase on foreground/reconnect (no polling) and does a one-time full pull on sign-in/restore. `RolloverCoordinator` handles scan-gated-with-grace block rollover on top of this.

**Tech Stack:** Swift 5.9 / SwiftUI, XCTest, Xcode project `UNBOUND` (scheme `UNBOUND`), Supabase-swift, file-backed `DatabaseService`.

**Spec:** `docs/superpowers/specs/2026-05-17-offline-sync-outbox-design.md`

**⚠️ PROJECT USES XCODEGEN — file registration mechanism (global, applies to every task):**
`UNBOUND.xcodeproj/project.pbxproj` is **generated and gitignored**. `project.yml`
is the source of truth and globs all files under `UNBOUND/` and `UNBOUNDTests/`.
After creating ANY new `.swift` file you MUST run `xcodegen generate` **before**
building/testing, or the new file won't be in the target. Do NOT hand-edit
`project.pbxproj` (it gets clobbered). New files do not need manual project
edits — `xcodegen generate` picks them up via globbing. `xcodegen` is at
`/opt/homebrew/bin/xcodegen`. The `.xcodeproj` itself is committed; the
gitignored `project.pbxproj` is not — so commits only include `.swift`/doc files.

**Build command (used throughout — run `xcodegen generate` first if files were added):**
`xcodegen generate && xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -quiet`

**Test command (per suite):**
`xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/<SuiteName> -quiet 2>&1 | tail -20`

---

## File Structure

| File | Responsibility |
|---|---|
| `UNBOUND/Services/Sync/OutboxEntry.swift` | The queued-change value type. |
| `UNBOUND/Services/Sync/OutboxStore.swift` | Durable on-disk FIFO with coalescing + deadletter. |
| `UNBOUND/Services/Sync/RemoteSync.swift` | Protocol + Supabase impl: collection→table mapping, upsert/delete/pull. |
| `UNBOUND/Services/Sync/SyncedDatabase.swift` | `DatabaseServiceProtocol` decorator: local write + enqueue. |
| `UNBOUND/Services/Sync/SyncEngine.swift` | Drain (flush) + restore (pull) + triggers. |
| `UNBOUND/Services/ProgramGeneration/RolloverCoordinator.swift` | Scan-gated rollover with grace + fallback. |
| `UNBOUND/Services/ServiceContainer.swift` (modify) | Inject `SyncedDatabase` as the production `database`. |
| `UNBOUND/Services/Progression/ProgressionStateStore.swift` (modify) | Use injected `DatabaseServiceProtocol`. |
| `UNBOUND/Services/ExercisePreference/ExercisePreferenceService.swift` (modify) | Use injected `DatabaseServiceProtocol`. |
| `UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift` (modify) | Default to `SyncedDatabase.shared`. |
| `UNBOUND/Services/WorkoutLog/SupabaseWorkoutLogService.swift` (modify) | Delete ad-hoc fallback; route through synced DB. |
| `UNBOUND/Services/Program/ProgramStore.swift` (modify) | Become an outbox producer; retire `dirty/syncedAt` remote calls. |
| `UNBOUND/App/*App.swift` (modify) | Wire foreground/reconnect flush + restore-on-sign-in. |
| `UNBOUNDTests/Services/Sync/*.swift` | Unit tests. |

**Collection → Supabase table/column map** (used by `SupabaseRemoteSync`):

| Local collection | Supabase table | userId column |
|---|---|---|
| `workoutLogs` | `workout_logs` | `user_id` |
| `programs` | `programs` | `user_id` |
| `progressionState` | `progression_state` | `user_id` |
| `exercisePreferences` | `exercise_preferences` | `user_id` |
| `programBlocks` | `program_blocks` | `user_id` |
| `scanCheckpoints` | `scan_checkpoints` | `user_id` |
| `users` | `users` | `id` |

---

## Task 1: OutboxEntry model

**Files:**
- Create: `UNBOUND/Services/Sync/OutboxEntry.swift`
- Test: `UNBOUNDTests/Services/Sync/OutboxEntryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/OutboxEntryTests.swift
import XCTest
@testable import UNBOUND

final class OutboxEntryTests: XCTestCase {
    func test_roundtrips_through_codable() throws {
        let e = OutboxEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            userId: "u1", collection: "exercisePreferences", docId: "u1:squat",
            op: .upsert, payloadJSON: Data("{\"a\":1}".utf8),
            enqueuedAt: Date(timeIntervalSince1970: 1000), attempt: 0
        )
        let data = try JSONEncoder().encode(e)
        let back = try JSONDecoder().decode(OutboxEntry.self, from: data)
        XCTAssertEqual(back, e)
    }

    func test_delete_entry_has_nil_payload() {
        let e = OutboxEntry(id: UUID(), userId: "u1", collection: "c",
                            docId: "d", op: .delete, payloadJSON: nil,
                            enqueuedAt: Date(), attempt: 0)
        XCTAssertEqual(e.op, .delete)
        XCTAssertNil(e.payloadJSON)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/OutboxEntryTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'OutboxEntry' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/OutboxEntry.swift
import Foundation

/// One pending change to a single document. The unit drained by SyncEngine.
struct OutboxEntry: Codable, Equatable, Identifiable, Sendable {
    enum Op: String, Codable, Sendable { case upsert, delete }

    let id: UUID
    let userId: String
    let collection: String
    let docId: String
    let op: Op
    /// Encoded document JSON for `.upsert`; nil for `.delete`.
    let payloadJSON: Data?
    let enqueuedAt: Date
    var attempt: Int
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/OutboxEntryTests -quiet 2>&1 | tail -20`
Expected: PASS (`** TEST SUCCEEDED **`).

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Sync/OutboxEntry.swift UNBOUNDTests/Services/Sync/OutboxEntryTests.swift
git commit -m "feat(sync): OutboxEntry model"
```

---

## Task 2: OutboxStore (durable disk queue)

**Files:**
- Create: `UNBOUND/Services/Sync/OutboxStore.swift`
- Test: `UNBOUNDTests/Services/Sync/OutboxStoreTests.swift`

Behavior: append-only, persisted atomically; `enqueue` coalesces — replaces any
existing entry with the same `(collection, docId)` (last-writer-wins, keeps the
queue bounded) and resets `attempt` to 0; `peekBatch` returns oldest-first;
`ack` removes by id; `recordFailure` increments attempt; `moveToDeadletter`
relocates a poison entry. Injectable directory for tests (mirrors `ProgramStore`).

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/OutboxStoreTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class OutboxStoreTests: XCTestCase {
    private var dir: URL!
    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("outbox-\(UUID().uuidString)")
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func entry(_ docId: String, _ col: String = "c",
                       op: OutboxEntry.Op = .upsert) -> OutboxEntry {
        OutboxEntry(id: UUID(), userId: "u1", collection: col, docId: docId,
                    op: op, payloadJSON: Data("x".utf8),
                    enqueuedAt: Date(), attempt: 0)
    }

    func test_enqueue_then_peek_returns_fifo() {
        let s = OutboxStore(directory: dir)
        s.enqueue(entry("a")); s.enqueue(entry("b"))
        XCTAssertEqual(s.peekBatch(limit: 10).map(\.docId), ["a", "b"])
    }

    func test_enqueue_coalesces_same_collection_docid() {
        let s = OutboxStore(directory: dir)
        s.enqueue(entry("a")); s.enqueue(entry("b")); s.enqueue(entry("a"))
        // "a" replaced in place at its original slot is acceptable; the
        // invariant is: exactly one "a", and "b" still present.
        let docs = s.peekBatch(limit: 10).map(\.docId)
        XCTAssertEqual(docs.filter { $0 == "a" }.count, 1)
        XCTAssertTrue(docs.contains("b"))
    }

    func test_ack_removes_entry() {
        let s = OutboxStore(directory: dir)
        let e = entry("a"); s.enqueue(e)
        s.ack([e.id])
        XCTAssertEqual(s.pendingCount, 0)
    }

    func test_persists_across_relaunch() {
        let s1 = OutboxStore(directory: dir)
        s1.enqueue(entry("a"))
        let s2 = OutboxStore(directory: dir)
        XCTAssertEqual(s2.peekBatch(limit: 10).map(\.docId), ["a"])
    }

    func test_moveToDeadletter_drops_from_pending() {
        let s = OutboxStore(directory: dir)
        let e = entry("a"); s.enqueue(e)
        s.moveToDeadletter(e.id)
        XCTAssertEqual(s.pendingCount, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/OutboxStoreTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'OutboxStore' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/OutboxStore.swift
import Foundation

/// Durable, single-device FIFO of pending changes. Persisted as one JSON
/// array via atomic write. Coalesces by (collection, docId) so the queue
/// stays bounded regardless of edit volume. @MainActor for serialized access.
@MainActor
final class OutboxStore {
    static let shared = OutboxStore()

    private let pendingURL: URL
    private let deadletterURL: URL
    private var pending: [OutboxEntry] = []
    private var dead: [OutboxEntry] = []

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.pendingURL = base.appendingPathComponent("outbox.json")
        self.deadletterURL = base.appendingPathComponent("outbox-deadletter.json")
        self.pending = (try? JSONDecoder().decode([OutboxEntry].self,
                        from: Data(contentsOf: pendingURL))) ?? []
        self.dead = (try? JSONDecoder().decode([OutboxEntry].self,
                     from: Data(contentsOf: deadletterURL))) ?? []
    }

    var pendingCount: Int { pending.count }

    func enqueue(_ entry: OutboxEntry) {
        if let i = pending.firstIndex(where: {
            $0.collection == entry.collection && $0.docId == entry.docId
        }) {
            pending[i] = entry          // coalesce in place, newest state wins
        } else {
            pending.append(entry)
        }
        persistPending()
    }

    func peekBatch(limit: Int) -> [OutboxEntry] {
        Array(pending.prefix(limit))
    }

    func ack(_ ids: [UUID]) {
        let set = Set(ids)
        pending.removeAll { set.contains($0.id) }
        persistPending()
    }

    func recordFailure(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[i].attempt += 1
        persistPending()
    }

    func moveToDeadletter(_ id: UUID) {
        guard let i = pending.firstIndex(where: { $0.id == id }) else { return }
        dead.append(pending.remove(at: i))
        persistPending()
        try? JSONEncoder().encode(dead).write(to: deadletterURL, options: .atomic)
    }

    private func persistPending() {
        try? JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/OutboxStoreTests -quiet 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Sync/OutboxStore.swift UNBOUNDTests/Services/Sync/OutboxStoreTests.swift
git commit -m "feat(sync): durable OutboxStore with coalescing + deadletter"
```

---

## Task 3: RemoteSync protocol + Supabase impl

**Files:**
- Create: `UNBOUND/Services/Sync/RemoteSync.swift`
- Test: `UNBOUNDTests/Services/Sync/RemoteSyncMapTests.swift`

Only the pure collection→table mapping is unit-tested (network is integration,
verified in Task 11 smoke). `SupabaseRemoteSync` wraps existing
`SupabaseDatabase` methods (`upsert(_:into:)`, `delete(from:keyedBy:equals:)`,
`query(from:whereColumn:equals:orderBy:ascending:limit:)`).

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/RemoteSyncMapTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/RemoteSyncMapTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'SyncCollectionMap' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/RemoteSync.swift
import Foundation

/// Static collection→table/column mapping. The single source of truth for
/// which local collections sync and how they key by user.
enum SyncCollectionMap {
    private static let tables: [String: String] = [
        "workoutLogs": "workout_logs",
        "programs": "programs",
        "progressionState": "progression_state",
        "exercisePreferences": "exercise_preferences",
        "programBlocks": "program_blocks",
        "scanCheckpoints": "scan_checkpoints",
        "users": "users",
    ]
    static func table(for collection: String) -> String? { tables[collection] }
    static func userColumn(for collection: String) -> String {
        collection == "users" ? "id" : "user_id"
    }
    static var syncedCollections: [String] { Array(tables.keys) }
}

/// Network seam. One implementation (Supabase); mockable in tests.
protocol RemoteSync: Sendable {
    /// Push raw document JSON. Throws on any failure (engine handles retry).
    func upsert(collection: String, docId: String, json: Data) async throws
    func delete(collection: String, docId: String) async throws
    /// Pull all docs for a user as raw JSON dictionaries (restore path).
    func pull(collection: String, userId: String) async throws -> [Data]
}

/// Adapter over SupabaseDatabase. JSON is passed through as already-encoded
/// document bytes (the local store's canonical form).
final class SupabaseRemoteSync: RemoteSync, @unchecked Sendable {
    static let shared = SupabaseRemoteSync()
    private let supabase = SupabaseDatabase.shared
    private init() {}

    private struct RawRow: Codable, Sendable {
        // Supabase rows are decoded/encoded as the document's own shape
        // elsewhere; for the generic path we round-trip via JSONElement.
    }

    func upsert(collection: String, docId: String, json: Data) async throws {
        guard let table = SyncCollectionMap.table(for: collection) else { return }
        let obj = try JSONDecoder().decode(JSONElement.self, from: json)
        _ = try await supabase.upsert(obj, into: table)
    }

    func delete(collection: String, docId: String) async throws {
        guard let table = SyncCollectionMap.table(for: collection) else { return }
        try await supabase.delete(from: table, keyedBy: "id", equals: docId)
    }

    func pull(collection: String, userId: String) async throws -> [Data] {
        guard let table = SyncCollectionMap.table(for: collection) else { return [] }
        let rows: [JSONElement] = try await supabase.query(
            from: table,
            whereColumn: SyncCollectionMap.userColumn(for: collection),
            equals: userId, orderBy: nil, ascending: false, limit: nil
        )
        return try rows.map { try JSONEncoder().encode($0) }
    }
}

/// Type-erased JSON value so the generic sync path can move arbitrary
/// document shapes through Supabase-swift's Codable APIs.
struct JSONElement: Codable, Sendable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode([String: JSONElement].self) { value = v }
        else if let v = try? c.decode([JSONElement].self) { value = v }
        else if let v = try? c.decode(Bool.self) { value = v }
        else if let v = try? c.decode(Double.self) { value = v }
        else if let v = try? c.decode(String.self) { value = v }
        else { value = NSNull() }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as [String: JSONElement]: try c.encode(v)
        case let v as [JSONElement]: try c.encode(v)
        case let v as Bool: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String: try c.encode(v)
        default: try c.encodeNil()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/RemoteSyncMapTests -quiet 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Build the whole scheme (catches Supabase API mismatch)**

Run: `xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|: error:"`
Expected: `** BUILD SUCCEEDED **`. If `supabase.query`/`upsert`/`delete` signatures differ, adjust the call sites in `SupabaseRemoteSync` to match `UNBOUND/Services/Supabase/SupabaseDatabase.swift` (do not change SupabaseDatabase).

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Services/Sync/RemoteSync.swift UNBOUNDTests/Services/Sync/RemoteSyncMapTests.swift
git commit -m "feat(sync): RemoteSync protocol + Supabase adapter + collection map"
```

---

## Task 4: SyncedDatabase decorator

**Files:**
- Create: `UNBOUND/Services/Sync/SyncedDatabase.swift`
- Test: `UNBOUNDTests/Services/Sync/SyncedDatabaseTests.swift`

Decorates any `DatabaseServiceProtocol`. `create`/`update` write local then
enqueue an `.upsert` (re-reading the merged doc so the enqueued payload is the
full document, matching `update`'s field-merge semantics). `delete` deletes
local then enqueues `.delete`. `read`/`query` pass straight through (read plane
never enqueues). Only collections in `SyncCollectionMap` enqueue; others write
local-only (e.g. transient caches).

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/SyncedDatabaseTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class SyncedDatabaseTests: XCTestCase {
    private var dir: URL!
    private var outbox: OutboxStore!
    private var local: MockDatabaseService!
    private var sut: SyncedDatabase!

    struct Doc: Codable, Equatable { var id: String; var userId: String; var n: Int }

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sdb-\(UUID().uuidString)")
        outbox = OutboxStore(directory: dir)
        local = MockDatabaseService()
        sut = SyncedDatabase(local: local, outbox: outbox)
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: dir); super.tearDown()
    }

    func test_create_writes_local_and_enqueues_upsert() async throws {
        try await sut.create(Doc(id: "d1", userId: "u1", n: 1),
                              collection: "exercisePreferences", documentId: "d1")
        let got: Doc = try await local.read(collection: "exercisePreferences", documentId: "d1")
        XCTAssertEqual(got.n, 1)
        let q = outbox.peekBatch(limit: 10)
        XCTAssertEqual(q.count, 1)
        XCTAssertEqual(q[0].op, .upsert)
        XCTAssertEqual(q[0].docId, "d1")
    }

    func test_delete_enqueues_delete() async throws {
        try await sut.create(Doc(id: "d1", userId: "u1", n: 1),
                              collection: "programs", documentId: "d1")
        try await sut.delete(collection: "programs", documentId: "d1")
        let q = outbox.peekBatch(limit: 10)
        XCTAssertEqual(q.last?.op, .delete)
    }

    func test_unsynced_collection_does_not_enqueue() async throws {
        try await sut.create(Doc(id: "d1", userId: "u1", n: 1),
                              collection: "transientCache", documentId: "d1")
        XCTAssertEqual(outbox.pendingCount, 0)
    }

    func test_read_passes_through_without_enqueue() async throws {
        try await sut.create(Doc(id: "d1", userId: "u1", n: 9),
                              collection: "programs", documentId: "d1")
        outbox.ack(outbox.peekBatch(limit: 99).map(\.id))
        let _: Doc = try await sut.read(collection: "programs", documentId: "d1")
        XCTAssertEqual(outbox.pendingCount, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncedDatabaseTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'SyncedDatabase' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/SyncedDatabase.swift
import Foundation

/// DatabaseServiceProtocol decorator: every mutation writes the local store
/// first (authoritative, instant) then enqueues an OutboxEntry. The single
/// choke point — a store cannot be "forgotten" by sync.
final class SyncedDatabase: DatabaseServiceProtocol, @unchecked Sendable {
    static let shared = SyncedDatabase(local: DatabaseService.shared,
                                       outbox: OutboxStore.shared)

    private let local: any DatabaseServiceProtocol
    private let outbox: OutboxStore

    init(local: any DatabaseServiceProtocol, outbox: OutboxStore) {
        self.local = local
        self.outbox = outbox
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        try await local.create(object, collection: collection, documentId: documentId)
        await enqueueUpsert(collection: collection, docId: documentId)
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        try await local.read(collection: collection, documentId: documentId)
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        try await local.update(fields, collection: collection, documentId: documentId)
        await enqueueUpsert(collection: collection, docId: documentId)
    }

    func delete(collection: String, documentId: String) async throws {
        try await local.delete(collection: collection, documentId: documentId)
        guard SyncCollectionMap.table(for: collection) != nil else { return }
        let entry = OutboxEntry(id: UUID(), userId: "", collection: collection,
                                docId: documentId, op: .delete, payloadJSON: nil,
                                enqueuedAt: Date(), attempt: 0)
        await MainActor.run { outbox.enqueue(entry) }
    }

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any,
                           orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
        try await local.query(collection: collection, field: field, isEqualTo: value,
                              orderBy: orderBy, descending: descending, limit: limit)
    }

    /// Re-reads the just-written doc as raw JSON so the enqueued payload is
    /// the full, merged document (correct even after a field-level `update`).
    private func enqueueUpsert(collection: String, docId: String) async {
        guard SyncCollectionMap.table(for: collection) != nil else { return }
        guard let raw: RawDoc = try? await local.read(collection: collection,
                                                      documentId: docId) else { return }
        let entry = OutboxEntry(id: UUID(), userId: raw.userId ?? raw.id ?? "",
                                collection: collection, docId: docId, op: .upsert,
                                payloadJSON: raw.json, enqueuedAt: Date(), attempt: 0)
        await MainActor.run { outbox.enqueue(entry) }
    }

    /// Decodes only the routing fields + retains the raw bytes.
    private struct RawDoc: Codable {
        let id: String?
        let userId: String?
        let json: Data
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            id = try? c.decode(String.self, forKey: .id)
            userId = try? c.decode(String.self, forKey: .userId)
            json = (try? JSONEncoder().encode(JSONElement(from: decoder))) ?? Data()
        }
        func encode(to encoder: Encoder) throws {}
        enum K: String, CodingKey { case id, userId }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncedDatabaseTests -quiet 2>&1 | tail -20`
Expected: PASS. If `RawDoc.json` ends up empty (decoder reuse), replace its body with: re-encode via `local.read` returning `JSONElement` directly — change `enqueueUpsert` to `let el: JSONElement = try await local.read(...)`, `payloadJSON = try JSONEncoder().encode(el)`, and pull `id`/`userId` from `el.value as? [String: JSONElement]`. Keep iterating until the 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Sync/SyncedDatabase.swift UNBOUNDTests/Services/Sync/SyncedDatabaseTests.swift
git commit -m "feat(sync): SyncedDatabase decorator (local write + enqueue)"
```

---

## Task 5: SyncEngine — flush + restore

**Files:**
- Create: `UNBOUND/Services/Sync/SyncEngine.swift`
- Test: `UNBOUNDTests/Services/Sync/SyncEngineTests.swift`

`flush()`: drain `peekBatch`, push each via `RemoteSync`; on success `ack`; on
failure `recordFailure` and stop the batch (will retry next trigger); after
`maxAttempts` (5) `moveToDeadletter`. Single-flight via an `isFlushing` guard.
`restore(userId:)`: for each synced collection, `pull` then write each doc into
`local` via `DatabaseService.create`. Uses a mock `RemoteSync`.

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/SyncEngineTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class SyncEngineTests: XCTestCase {
    final class MockRemote: RemoteSync, @unchecked Sendable {
        var failUpsertUntilAttempt = 0
        var upserts = 0, deletes = 0
        var pullResult: [Data] = []
        func upsert(collection: String, docId: String, json: Data) async throws {
            upserts += 1
            if upserts <= failUpsertUntilAttempt { throw URLError(.notConnectedToInternet) }
        }
        func delete(collection: String, docId: String) async throws { deletes += 1 }
        func pull(collection: String, userId: String) async throws -> [Data] {
            collection == "programs" ? pullResult : []
        }
    }

    private var dir: URL!
    private var outbox: OutboxStore!
    private var remote: MockRemote!
    private var local: MockDatabaseService!
    private var sut: SyncEngine!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("se-\(UUID().uuidString)")
        outbox = OutboxStore(directory: dir)
        remote = MockRemote()
        local = MockDatabaseService()
        sut = SyncEngine(outbox: outbox, remote: remote, local: local, maxAttempts: 5)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir); super.tearDown() }

    private func enq(_ id: String, op: OutboxEntry.Op = .upsert) {
        outbox.enqueue(OutboxEntry(id: UUID(), userId: "u1", collection: "programs",
            docId: id, op: op, payloadJSON: Data("{}".utf8), enqueuedAt: Date(), attempt: 0))
    }

    func test_flush_acks_on_success() async {
        enq("p1")
        await sut.flush()
        XCTAssertEqual(outbox.pendingCount, 0)
        XCTAssertEqual(remote.upserts, 1)
    }

    func test_flush_retains_and_counts_on_failure() async {
        remote.failUpsertUntilAttempt = 99
        enq("p1")
        await sut.flush()
        XCTAssertEqual(outbox.pendingCount, 1)
        XCTAssertEqual(outbox.peekBatch(limit: 1).first?.attempt, 1)
    }

    func test_deadletters_after_maxAttempts() async {
        remote.failUpsertUntilAttempt = 99
        enq("p1")
        for _ in 0..<5 { await sut.flush() }
        XCTAssertEqual(outbox.pendingCount, 0)   // moved to deadletter
    }

    func test_restore_writes_pulled_docs_local() async throws {
        remote.pullResult = [Data(#"{"id":"p9","userId":"u1"}"#.utf8)]
        try await sut.restore(userId: "u1")
        let el: JSONElement = try await local.read(collection: "programs", documentId: "p9")
        XCTAssertNotNil(el)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncEngineTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'SyncEngine' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/SyncEngine.swift
import Foundation

/// Drains the outbox to the remote and restores from it. Single-flight.
/// No timers, no polling — driven entirely by external triggers (Task 6).
@MainActor
final class SyncEngine {
    static let shared = SyncEngine(outbox: .shared,
                                   remote: SupabaseRemoteSync.shared,
                                   local: DatabaseService.shared,
                                   maxAttempts: 5)

    private let outbox: OutboxStore
    private let remote: any RemoteSync
    private let local: any DatabaseServiceProtocol
    private let maxAttempts: Int
    private let logger = LoggingService.shared
    private var isFlushing = false

    init(outbox: OutboxStore, remote: any RemoteSync,
         local: any DatabaseServiceProtocol, maxAttempts: Int) {
        self.outbox = outbox; self.remote = remote
        self.local = local; self.maxAttempts = maxAttempts
    }

    func flush() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        for entry in outbox.peekBatch(limit: 50) {
            do {
                switch entry.op {
                case .upsert:
                    try await remote.upsert(collection: entry.collection,
                        docId: entry.docId, json: entry.payloadJSON ?? Data())
                case .delete:
                    try await remote.delete(collection: entry.collection,
                                            docId: entry.docId)
                }
                outbox.ack([entry.id])
            } catch {
                outbox.recordFailure(entry.id)
                let attempts = (outbox.peekBatch(limit: 50)
                    .first { $0.id == entry.id }?.attempt) ?? maxAttempts
                if attempts >= maxAttempts {
                    logger.log("Outbox entry deadlettered: \(entry.collection)/\(entry.docId): \(error)",
                               level: .error, context: ["docId": entry.docId])
                    outbox.moveToDeadletter(entry.id)
                } else {
                    // Stop this pass; retry on next trigger.
                    break
                }
            }
        }
    }

    func restore(userId: String) async throws {
        for collection in SyncCollectionMap.syncedCollections {
            let docs = (try? await remote.pull(collection: collection, userId: userId)) ?? []
            for json in docs {
                guard let el = try? JSONDecoder().decode(JSONElement.self, from: json),
                      let dict = el.value as? [String: JSONElement],
                      let idEl = dict["id"]?.value as? String else { continue }
                try? await local.create(el, collection: collection, documentId: idEl)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncEngineTests -quiet 2>&1 | tail -20`
Expected: PASS. If `deadletters_after_maxAttempts` needs >5 flushes due to the early `break`, change the failing-entry handling so a non-deadletter failure still `recordFailure`s and the loop `break`s (one attempt per flush) — five flushes → attempt reaches 5 → deadletter. Adjust until all 4 pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Sync/SyncEngine.swift UNBOUNDTests/Services/Sync/SyncEngineTests.swift
git commit -m "feat(sync): SyncEngine flush (backoff+deadletter) + restore"
```

---

## Task 6: Trigger wiring (foreground + reconnect + post-write)

**Files:**
- Modify: the app entry point (find with `grep -rl "@main" UNBOUND/App`)
- Create: `UNBOUND/Services/Sync/SyncTriggers.swift`
- Test: `UNBOUNDTests/Services/Sync/SyncTriggersTests.swift`

`SyncTriggers` owns an `NWPathMonitor`; calls `SyncEngine.flush()` on
becoming-satisfied. The app calls `SyncTriggers.shared.start()` once and calls
`flush()` on `scenePhase == .active`. Post-write nudge: `SyncedDatabase` posts
`.outboxDidEnqueue`; `SyncTriggers` debounces (2s) → `flush()`.

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/Sync/SyncTriggersTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class SyncTriggersTests: XCTestCase {
    func test_debounced_enqueue_notification_calls_flush_once() async {
        let exp = expectation(description: "flush")
        var calls = 0
        let t = SyncTriggers(debounce: 0.1) { calls += 1; exp.fulfill() }
        t.start()
        NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
        await fulfillment(of: [exp], timeout: 2)
        XCTAssertEqual(calls, 1)
        t.stop()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncTriggersTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'SyncTriggers' in scope` / `.outboxDidEnqueue`.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Services/Sync/SyncTriggers.swift
import Foundation
import Network

extension Notification.Name {
    static let outboxDidEnqueue = Notification.Name("unbound.outboxDidEnqueue")
}

/// Owns the flush triggers: network-reconnect, post-write debounce.
/// Foreground (.active) is driven by the app's scenePhase (see app entry).
@MainActor
final class SyncTriggers {
    static let shared = SyncTriggers(debounce: 2.0) {
        Task { await SyncEngine.shared.flush() }
    }

    private let monitor = NWPathMonitor()
    private let debounce: TimeInterval
    private let onFire: () -> Void
    private var work: DispatchWorkItem?
    private var token: NSObjectProtocol?

    init(debounce: TimeInterval, onFire: @escaping () -> Void) {
        self.debounce = debounce; self.onFire = onFire
    }

    func start() {
        token = NotificationCenter.default.addObserver(
            forName: .outboxDidEnqueue, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleDebounced()
        }
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.onFire() }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    func stop() {
        if let token { NotificationCenter.default.removeObserver(token) }
        monitor.cancel(); work?.cancel()
    }

    private func scheduleDebounced() {
        work?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.onFire() }
        work = w
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: w)
    }
}
```

Then in `SyncedDatabase`, after each `outbox.enqueue(...)` call site, add:
`NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)`.

In the app entry point `body`, add `.onChange(of: scenePhase)` (declare
`@Environment(\.scenePhase) private var scenePhase`):

```swift
.onChange(of: scenePhase) { _, phase in
    if phase == .active { Task { await SyncEngine.shared.flush() } }
}
.task { SyncTriggers.shared.start() }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SyncTriggersTests -quiet 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Build whole scheme**

Run: `xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|: error:"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Services/Sync/SyncTriggers.swift UNBOUND/Services/Sync/SyncedDatabase.swift UNBOUNDTests/Services/Sync/SyncTriggersTests.swift UNBOUND/App
git commit -m "feat(sync): flush triggers — reconnect, foreground, debounced post-write"
```

---

## Task 7: Route edit side-stores + workout logs through SyncedDatabase

**Files:**
- Modify: `UNBOUND/Services/Progression/ProgressionStateStore.swift:6`
- Modify: `UNBOUND/Services/ExercisePreference/ExercisePreferenceService.swift:5`
- Modify: `UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift:17`
- Modify: `UNBOUND/Services/WorkoutLog/SupabaseWorkoutLogService.swift`
- Modify: `UNBOUND/Services/ServiceContainer.swift:46`

No new behavior — only swap the backing store. The earlier ad-hoc any-error
fallback in `SupabaseWorkoutLogService` is removed; persistence now goes
through `SyncedDatabase` (local + outbox) and the side-effect chain stays.

- [ ] **Step 1: Repoint the three local-only stores**

In `ProgressionStateStore.swift` change `private let database = DatabaseService.shared`
→ `private let database: any DatabaseServiceProtocol = SyncedDatabase.shared`.

In `ExercisePreferenceService.swift` change `private let database = DatabaseService.shared`
→ `private let database: any DatabaseServiceProtocol = SyncedDatabase.shared`.

In `ProgramBlockStore.swift` change the init default
`init(database: DatabaseServiceProtocol = DatabaseService.shared)`
→ `init(database: DatabaseServiceProtocol = SyncedDatabase.shared)`.

- [ ] **Step 2: Collapse SupabaseWorkoutLogService onto the synced path**

Replace the body of `saveLog`'s do/catch (the block added 2026-05-17) so it
writes through `SyncedDatabase.shared.create(log, collection: "workoutLogs",
documentId: log.id)` and then runs the existing side-effect chain
unconditionally; delete the `supabase.upsert` + broad `catch` wrapper. Do the
same for `updateLog` (→ `SyncedDatabase.shared.update`-equivalent: re-`create`
the full log), `fetchLogs`/`fetchRecentLogs` (→ read local via
`DatabaseService.shared.query(collection: "workoutLogs", ...)`),
`deleteLog` (→ `SyncedDatabase.shared.delete`). Keep `loadProfile` as is.

- [ ] **Step 3: Make production container use SyncedDatabase**

In `ServiceContainer.swift` line ~46 change `self.database = DatabaseService.shared`
→ `self.database = SyncedDatabase.shared`. Leave the test/mock init
(`MockDatabaseService()`) untouched.

- [ ] **Step 4: Build + run the affected suites**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/Services -quiet 2>&1 | tail -25`
Expected: `** TEST SUCCEEDED **`. Fix any compile mismatch (e.g. `SyncedDatabase` is `any DatabaseServiceProtocol` — call sites already use the protocol so no change needed). No behavior tests change.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Progression/ProgressionStateStore.swift UNBOUND/Services/ExercisePreference/ExercisePreferenceService.swift UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift UNBOUND/Services/WorkoutLog/SupabaseWorkoutLogService.swift UNBOUND/Services/ServiceContainer.swift
git commit -m "refactor(sync): route edit stores + workout logs through SyncedDatabase; drop ad-hoc fallback"
```

---

## Task 8: ProgramStore becomes an outbox producer

**Files:**
- Modify: `UNBOUND/Services/Program/ProgramStore.swift`
- Test: `UNBOUNDTests/Services/ProgramStoreTests.swift` (extend existing)

`save()` keeps the local cache file (read model unchanged) but instead of
`remote.persist(...)` it enqueues a `programs` upsert + a `users`
`currentProgramId` patch. Remove `dirty/syncedAt` round-trip and
`flushIfDirty` (the outbox is now the single "unsynced" definition);
`revalidate` keeps pulling on a program-id mismatch (restore/rollover path).

- [ ] **Step 1: Add failing test to ProgramStoreTests.swift**

```swift
func test_save_enqueues_program_upsert() async {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ps-\(UUID().uuidString)")
    let outbox = OutboxStore(directory: dir)
    let store = ProgramStore(directory: dir, outbox: outbox)
    await store.save(TrainingProgram.fixture(id: "prog1"), userId: "u1")
    let q = outbox.peekBatch(limit: 10)
    XCTAssertTrue(q.contains { $0.collection == "programs" && $0.docId == "prog1" })
}
```
(If `TrainingProgram.fixture` doesn't exist, construct a minimal
`TrainingProgram` inline using its required initializer — check
`UNBOUND/Models/Program.swift` for the memberwise init.)

- [ ] **Step 2: Run it — expect FAIL**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProgramStoreTests -quiet 2>&1 | tail -20`
Expected: FAIL — `ProgramStore` has no `outbox:` initializer parameter.

- [ ] **Step 3: Implement**

Change `ProgramStore.init` to also accept `outbox: OutboxStore = .shared` and
store it. Replace `save(_:userId:)`:

```swift
func save(_ program: TrainingProgram, userId: String) async {
    self.program = program
    writeCache(Cached(program: program, userId: userId, dirty: false, syncedAt: Date()))
    if let json = try? JSONEncoder().encode(program) {
        outbox.enqueue(OutboxEntry(id: UUID(), userId: userId,
            collection: "programs", docId: program.id, op: .upsert,
            payloadJSON: json, enqueuedAt: Date(), attempt: 0))
    }
    if let patch = try? JSONSerialization.data(withJSONObject:
        ["id": userId, "currentProgramId": program.id]) {
        outbox.enqueue(OutboxEntry(id: UUID(), userId: userId,
            collection: "users", docId: userId, op: .upsert,
            payloadJSON: patch, enqueuedAt: Date(), attempt: 0))
    }
    NotificationCenter.default.post(name: .outboxDidEnqueue, object: nil)
}
```

Delete `flushIfDirty`; keep `revalidate` but drop its `flushIfDirty` call.
Keep `adopt`, `loadLocal`, `clear`. Leave the `ProgramRemote`/
`SupabaseProgramService` type for `revalidate`'s `fetchProgram` (pull path).

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/ProgramStoreTests -quiet 2>&1 | tail -20`
Expected: PASS (existing ProgramStore tests + the new one). Update any existing test that referenced `flushIfDirty` to assert via the outbox instead.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Program/ProgramStore.swift UNBOUNDTests/Services/ProgramStoreTests.swift
git commit -m "refactor(sync): ProgramStore is an outbox producer; retire dirty/flushIfDirty"
```

---

## Task 9: RolloverCoordinator — scan-gated + grace + fallback

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/RolloverCoordinator.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/RolloverCoordinatorTests.swift`

Pure decision function `decide(...)` is the testable core; the side-effecting
`evaluate(...)` calls `BlockRolloverService.performRollover`. Grace = 5 days.

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Services/ProgramGeneration/RolloverCoordinatorTests.swift
import XCTest
@testable import UNBOUND

final class RolloverCoordinatorTests: XCTestCase {
    private let day: TimeInterval = 86400
    private func decide(daysRemaining: Int, freshScan: Bool, daysPastBoundary: Int)
        -> RolloverCoordinator.Decision {
        RolloverCoordinator.decide(
            daysRemaining: daysRemaining, hasFreshScan: freshScan,
            daysPastBoundary: daysPastBoundary, graceDays: 5)
    }

    func test_before_boundary_is_noop() {
        XCTAssertEqual(decide(daysRemaining: 3, freshScan: false, daysPastBoundary: 0), .noop)
    }
    func test_boundary_with_fresh_scan_rolls_now() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: true, daysPastBoundary: 0), .rollNow)
    }
    func test_boundary_no_scan_awaits() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: false, daysPastBoundary: 0), .awaitRescan)
    }
    func test_grace_expired_no_scan_auto_rolls() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: false, daysPastBoundary: 6), .rollNow)
    }
}
```

- [ ] **Step 2: Run it — expect FAIL**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/RolloverCoordinatorTests -quiet 2>&1 | tail -20`
Expected: FAIL — `cannot find 'RolloverCoordinator'`.

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/RolloverCoordinator.swift
import Foundation

/// Decides + executes the monthly block rollover: prefer a fresh scan at the
/// boundary, prompt for one, auto-roll with existing data after a grace
/// window. Runs fully on-device (deterministic generator) — offline OK.
@MainActor
final class RolloverCoordinator {
    static let shared = RolloverCoordinator()

    enum Decision: Equatable { case noop, rollNow, awaitRescan }

    /// Pure core. `daysPastBoundary` is 0 until the block ends, then counts up.
    static func decide(daysRemaining: Int, hasFreshScan: Bool,
                       daysPastBoundary: Int, graceDays: Int) -> Decision {
        guard daysRemaining == 0 else { return .noop }
        if hasFreshScan { return .rollNow }
        return daysPastBoundary >= graceDays ? .rollNow : .awaitRescan
    }

    /// Foreground entry point. Reads program + latest scan locally, decides,
    /// and rolls if needed. Idempotent: re-checks latest block number before
    /// generating so two foregrounds can't double-roll.
    func evaluateOnForeground(userId: String, services: ServiceContainer) async {
        guard let program = ProgramStore.shared.program else { return }
        let remaining = BlockRolloverScheduler.daysRemaining(program: program)
        let pastBoundary = max(0, program.durationDays
            - BlockRolloverScheduler.daysRemaining(program: program)
            - program.durationDays + Int(Date().timeIntervalSince(program.createdAt) / 86400)
            - program.durationDays + 1)
        let latestScan = try? ScanCheckpointStore.shared.mostRecent(userId: userId)
        let hasFresh = (latestScan?.createdAt ?? .distantPast) > program.createdAt

        let decision = Self.decide(daysRemaining: remaining, hasFreshScan: hasFresh,
            daysPastBoundary: daysPastBoundaryDays(program: program), graceDays: 5)
        guard decision == .rollNow else { return }

        let prevBlock = await ProgramBlockStore.shared.latestBlock(userId: userId)
        guard let profile = try? await services.user.fetchProfile(userId: userId) else { return }
        let scan = try? services.scan.latestSession(userId: userId)   // optional
        do {
            let newProgram = try await BlockRolloverService.performRollover(
                userId: userId, profile: profile, analysis: nil, scan: scan)
            // Guard against double-roll: only adopt if block advanced.
            let after = await ProgramBlockStore.shared.latestBlock(userId: userId)
            if (after?.blockNumber ?? 0) > (prevBlock?.blockNumber ?? 0) {
                await ProgramStore.shared.save(newProgram, userId: userId)
            }
        } catch {
            LoggingService.shared.log("Rollover failed: \(error)", level: .error)
        }
    }

    private func daysPastBoundaryDays(program: TrainingProgram) -> Int {
        let elapsed = Int(Date().timeIntervalSince(program.createdAt) / 86400)
        return max(0, elapsed - program.durationDays)
    }
}
```

(Delete the unused `pastBoundary` local — it was a scratch calc; the real
value is `daysPastBoundaryDays`. If `services.scan.latestSession` doesn't
exist, pass `scan: nil` — `performRollover` accepts `ScanSession?`.)

- [ ] **Step 4: Run tests — expect PASS**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/RolloverCoordinatorTests -quiet 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/RolloverCoordinator.swift UNBOUNDTests/Services/ProgramGeneration/RolloverCoordinatorTests.swift
git commit -m "feat(rollover): scan-gated coordinator with grace + auto-fallback"
```

---

## Task 10: Wire restore-on-sign-in + rollover-on-foreground

**Files:**
- Modify: app entry point (same file as Task 6) and/or `AuthService` sign-in completion site (`grep -rn "signInWithApple\|signInWithEmail\|migrateIfNeeded" UNBOUND/App UNBOUND/Services/Auth`)

- [ ] **Step 1: Restore on a fresh sign-in**

At the point where a sign-in transitions an un-restored device (no local
program cache for the new userId), call once:

```swift
Task {
    if ProgramStore.shared.loadLocal(userId: userId) == nil {
        try? await SyncEngine.shared.restore(userId: userId)
        await services.programViewModel?.reloadLocalProgram()  // or existing reload hook
    }
}
```
Use the existing post-auth hook near `LocalToSupabaseMigration` /
`migrateIfNeeded`. Do not restore on every launch — gate on "no local cache."

- [ ] **Step 2: Rollover on foreground**

In the app entry `.onChange(of: scenePhase)` active branch (added Task 6), add
after the flush line:

```swift
if let uid = services.auth.currentUserId {
    Task { await RolloverCoordinator.shared.evaluateOnForeground(userId: uid, services: services) }
}
```

- [ ] **Step 3: Build whole scheme**

Run: `xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|: error:"`
Expected: `** BUILD SUCCEEDED **`. Resolve any missing hook names against the actual app entry / AuthService (adjust call sites; don't invent APIs).

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/App UNBOUND/Services/Auth
git commit -m "feat(sync): restore-on-sign-in (no local cache) + rollover-on-foreground"
```

---

## Task 11: Full build, full test, integration smoke

- [ ] **Step 1: Full test suite**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | grep -E "Test Suite 'UNBOUNDTests'|TEST (SUCCEEDED|FAILED)|failed"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Manual sim smoke (offline edit survives + flushes)**

1. Boot sim, install (`xcodebuild build` then `xcrun simctl install booted <app>`).
2. Turn the Mac/sim offline (or rely on no Supabase reachability).
3. Complete a workout + apply a coach exercise swap.
4. Force-quit and relaunch the app → both still present (local) ✔.
5. Inspect outbox file:
   `cat ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/UNBOUND/outbox.json` → entries present ✔.
6. Restore connectivity, foreground the app → within ~2s outbox drains
   (`outbox.json` → `[]`) and rows appear in Supabase ✔.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "test(sync): full suite green + offline→online smoke verified"
```

---

## Self-Review

- **Spec coverage:** outbox (T1–2), no-poll triggers (T6), SyncedDatabase choke point (T4,T7), edit-store gap fixed (T7), ProgramStore unified (T8), restore (T5,T10), scan-gated rollover w/ grace (T9,T10), error handling/deadletter (T5), supersedes ad-hoc fallback (T7). All spec sections mapped.
- **Type consistency:** `OutboxEntry`, `OutboxStore` (`enqueue/peekBatch/ack/recordFailure/moveToDeadletter/pendingCount`), `SyncCollectionMap`, `RemoteSync` (`upsert/delete/pull`), `SyncedDatabase`, `SyncEngine` (`flush/restore`), `RolloverCoordinator` (`decide/evaluateOnForeground`) used consistently across tasks.
- **Known follow-up (spec, out of scope):** no offline→online *re-pull* reconciliation queue beyond at-least-once push; documented in spec.
- **Risk note:** several integration call sites (`services.scan.latestSession`, post-auth hook name, app `@main` file) are environment-dependent — each step instructs verifying against the real symbol rather than assuming. Keep tasks small; build after every integration task.
