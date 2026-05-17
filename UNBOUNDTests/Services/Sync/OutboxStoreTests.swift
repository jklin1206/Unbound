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
