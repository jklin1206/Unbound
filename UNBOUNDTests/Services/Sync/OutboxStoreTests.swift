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
                       op: OutboxEntry.Op = .upsert,
                       userId: String = "u1") -> OutboxEntry {
        OutboxEntry(id: UUID(), userId: userId, collection: col, docId: docId,
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
        let docs = s.peekBatch(limit: 10).map(\.docId)
        XCTAssertEqual(docs.filter { $0 == "a" }.count, 1)
        XCTAssertTrue(docs.contains("b"))
    }

    func test_enqueue_doesNotCoalesceAcrossUsers() {
        let s = OutboxStore(directory: dir)
        s.enqueue(entry("a", userId: "u1"))
        s.enqueue(entry("a", userId: "u2"))

        let entries = s.peekBatch(limit: 10)
        XCTAssertEqual(entries.map(\.userId), ["u1", "u2"])
        XCTAssertEqual(entries.map(\.docId), ["a", "a"])
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
        XCTAssertEqual(s.deadletterCount, 1)
    }

    func test_deadletter_persists_across_relaunch() {
        let s1 = OutboxStore(directory: dir)
        let e = entry("a"); s1.enqueue(e)
        s1.moveToDeadletter(e.id)
        let s2 = OutboxStore(directory: dir)
        XCTAssertEqual(s2.deadletterCount, 1)
        XCTAssertEqual(s2.pendingCount, 0)
    }

    func test_load_recoversEmpty_onCorruptFile() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("this is not json".utf8).write(to: dir.appendingPathComponent("outbox.json"))
        let s = OutboxStore(directory: dir)
        XCTAssertEqual(s.pendingCount, 0)
    }

    func test_requeueDeadlettered_resurrectsOnlyThatUsersEntries() {
        let s = OutboxStore(directory: dir)
        let e = entry("a", userId: "u1"); s.enqueue(e)
        s.moveToDeadletter(e.id)
        XCTAssertEqual(s.requeueDeadlettered(userId: "u2", maxAttempts: 5), 0,
                       "another user's sign-in must not resurrect u1's entries")
        XCTAssertEqual(s.deadletterCount, 1)
        XCTAssertEqual(s.requeueDeadlettered(userId: "U1", maxAttempts: 5), 1,
                       "uid match is case-insensitive, mirroring canFlush")
        XCTAssertEqual(s.pendingCount, 1)
        XCTAssertEqual(s.deadletterCount, 0)
    }

    func test_requeueDeadlettered_leavesAttemptExhaustedEntriesDead() {
        let s = OutboxStore(directory: dir)
        var e = entry("a", userId: "u1")
        e.attempt = 5
        s.enqueue(e)
        s.moveToDeadletter(e.id)
        XCTAssertEqual(s.requeueDeadlettered(userId: "u1", maxAttempts: 5), 0,
                       "entries dead-lettered for exhausting flush attempts stay dead")
        XCTAssertEqual(s.deadletterCount, 1)
        XCTAssertEqual(s.pendingCount, 0)
    }

    func test_requeueDeadlettered_newerPendingEditWins() {
        let s = OutboxStore(directory: dir)
        let old = entry("a", userId: "u1"); s.enqueue(old)
        s.moveToDeadletter(old.id)
        let newer = entry("a", userId: "u1"); s.enqueue(newer)
        XCTAssertEqual(s.requeueDeadlettered(userId: "u1", maxAttempts: 5), 1)
        XCTAssertEqual(s.pendingCount, 1,
                       "resurrected entry merges into the newer pending edit for the same doc")
        XCTAssertEqual(s.peekBatch(limit: 1).first?.id, newer.id,
                       "the newer payload wins; only changed-field sets union")
        XCTAssertEqual(s.deadletterCount, 0)
    }
}
