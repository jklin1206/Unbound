import XCTest
@testable import UNBOUND

final class SquadPresenceTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let p = SquadPresence(
            userId: UUID(), squadId: UUID(),
            workoutStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_010_000)
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(SquadPresence.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testIsActiveTrueBeforeExpiry() {
        let p = SquadPresence(
            userId: UUID(), squadId: UUID(),
            workoutStartedAt: .now,
            expiresAt: Date.now.addingTimeInterval(3600)
        )
        XCTAssertTrue(p.isActive)
    }

    func testIsActiveFalseAfterExpiry() {
        let p = SquadPresence(
            userId: UUID(), squadId: UUID(),
            workoutStartedAt: Date.now.addingTimeInterval(-7200),
            expiresAt: Date.now.addingTimeInterval(-1)
        )
        XCTAssertFalse(p.isActive)
    }
}
