import XCTest
import Combine
@testable import UNBOUND

@MainActor
final class SyncEngineTests: XCTestCase {
    final class MockRemote: RemoteSync, @unchecked Sendable {
        var failUpsertUntilAttempt = 0
        var upserts = 0, deletes = 0
        var pullResult: [Data] = []
        func merge(collection: String, docId: String,
                   fullJSON: Data, changedFields: [String]) async throws {
            upserts += 1
            if upserts <= failUpsertUntilAttempt { throw URLError(.notConnectedToInternet) }
        }
        func delete(collection: String, docId: String) async throws { deletes += 1 }
        func pull(collection: String, userId: String) async throws -> [Data] {
            collection == "programs" ? pullResult : []
        }
    }

    final class TestAuth: AuthServiceProtocol, @unchecked Sendable {
        var currentUserId: String?
        var isAuthenticated: Bool { currentUserId != nil }
        var authStatePublisher: AnyPublisher<String?, Never> {
            Just(currentUserId).eraseToAnyPublisher()
        }

        init(currentUserId: String?) {
            self.currentUserId = currentUserId
        }

        func signInWithApple() async throws -> String { currentUserId ?? "" }
        func signInWithEmail(email: String, password: String) async throws -> String { currentUserId ?? "" }
        func createAccountWithEmail(email: String, password: String) async throws -> String { currentUserId ?? "" }
        func signOut() throws { currentUserId = nil }
        func deleteAccount() async throws { currentUserId = nil }
    }

    private var dir: URL!
    private var outbox: OutboxStore!
    private var remote: MockRemote!
    private var local: MockDatabaseService!
    private var auth: TestAuth!
    private var sut: SyncEngine!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("se-\(UUID().uuidString)")
        outbox = OutboxStore(directory: dir)
        remote = MockRemote()
        local = MockDatabaseService()
        auth = TestAuth(currentUserId: "u1")
        sut = SyncEngine(outbox: outbox, remote: remote, local: local, maxAttempts: 5, auth: auth)
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

    func test_flush_deadlettersEntryForDifferentAuthenticatedUser() async {
        enq("p1")
        auth.currentUserId = "u2"

        await sut.flush()

        XCTAssertEqual(remote.upserts, 0)          // never sent to the wrong user's cloud
        XCTAssertEqual(outbox.pendingCount, 0)     // no longer left to starve the queue
        XCTAssertEqual(outbox.deadletterCount, 1)  // moved to dead-letter, not dropped
    }

    func test_flush_mismatchedEntryDoesNotBlockValidEntryBehindIt() async {
        // Stale anonymous entry at the FIFO head; a valid post-sign-in entry
        // queued behind it. A single flush must clear both: dead-letter the
        // mismatch and upsert the valid one in the same pass.
        outbox.enqueue(OutboxEntry(id: UUID(), userId: "anon", collection: "programs",
            docId: "stale", op: .upsert, payloadJSON: Data("{}".utf8), enqueuedAt: Date(), attempt: 0))
        enq("p1")

        await sut.flush()

        XCTAssertEqual(remote.upserts, 1)          // valid entry reached the remote
        XCTAssertEqual(outbox.pendingCount, 0)     // nothing left blocking the head
        XCTAssertEqual(outbox.deadletterCount, 1)  // only the mismatch was dead-lettered
    }

    func test_restore_writes_pulled_docs_local() async throws {
        remote.pullResult = [Data(#"{"id":"p9","userId":"u1"}"#.utf8)]
        try await sut.restore(userId: "u1")
        let el: JSONElement = try await local.read(collection: "programs", documentId: "p9")
        XCTAssertNotNil(el)
    }
}
