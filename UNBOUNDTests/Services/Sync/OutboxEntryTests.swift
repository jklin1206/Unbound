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
