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
