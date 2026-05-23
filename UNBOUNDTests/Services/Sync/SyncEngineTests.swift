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
        XCTAssertEqual(outbox.pendingCount, 0)
    }

    func test_restore_writes_pulled_docs_local() async throws {
        remote.pullResult = [Data(#"{"id":"p9","userId":"u1"}"#.utf8)]
        try await sut.restore(userId: "u1")
        let el: JSONElement = try await local.read(collection: "programs", documentId: "p9")
        XCTAssertNotNil(el)
    }
}
