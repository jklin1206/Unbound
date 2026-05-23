import XCTest
@testable import UNBOUND

final class SquadTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let squad = Squad(
            id: UUID(),
            name: "Test Crew",
            captainId: UUID(),
            affinityAxis: .power,
            affinitySetAt: Date(timeIntervalSince1970: 1_700_000_000),
            inviteCode: "A3F7K9",
            maxSize: 8,
            squadStreakWeeks: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(squad)
        let decoded = try JSONDecoder().decode(Squad.self, from: data)
        XCTAssertEqual(decoded, squad)
    }

    func testNilAffinityRoundtrip() throws {
        let squad = Squad(
            id: UUID(), name: "Test", captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "A3F7K9", maxSize: 8, squadStreakWeeks: 0,
            createdAt: .now
        )
        let data = try JSONEncoder().encode(squad)
        let decoded = try JSONDecoder().decode(Squad.self, from: data)
        XCTAssertEqual(decoded, squad)
    }

    func testInviteURL() {
        let squad = Squad(
            id: UUID(), name: "Test", captainId: UUID(),
            affinityAxis: nil, affinitySetAt: nil,
            inviteCode: "A3F7K9", maxSize: 8, squadStreakWeeks: 0,
            createdAt: .now
        )
        XCTAssertEqual(squad.inviteURL?.absoluteString, "https://unboundapp.com/squad/A3F7K9")
    }
}
