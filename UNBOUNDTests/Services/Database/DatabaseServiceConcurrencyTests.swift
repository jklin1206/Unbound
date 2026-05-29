import XCTest
@testable import UNBOUND

/// Proof for WS-A #3 (DB write race / lost updates).
///
/// `DatabaseService.update` does a read-modify-write on a document. Before the
/// actor conversion, concurrent updates to the same document interleaved and
/// clobbered each other (last whole-document write won), silently losing
/// writes. Actor isolation serializes every operation, so all updates persist.
final class DatabaseServiceConcurrencyTests: XCTestCase {

    func test_concurrent_updates_to_one_document_lose_no_writes() async throws {
        let db = DatabaseService.shared
        let collection = "concurrency_proof"
        let documentId = "race-\(UUID().uuidString)"
        let count = 100

        // 100 concurrent updates, each setting a distinct field on the SAME doc.
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    try? await db.update(["field\(i)": i], collection: collection, documentId: documentId)
                }
            }
        }

        // Every field must be present — 0 lost writes.
        let result: [String: Int] = try await db.read(collection: collection, documentId: documentId)
        XCTAssertEqual(result.count, count, "all \(count) concurrent updates must persist (0 lost writes)")
        for i in 0..<count {
            XCTAssertEqual(result["field\(i)"], i, "field\(i) was lost to a write race")
        }

        try? await db.delete(collection: collection, documentId: documentId)
    }
}
