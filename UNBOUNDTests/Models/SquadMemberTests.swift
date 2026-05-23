import XCTest
@testable import UNBOUND

final class SquadMemberTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let m = SquadMember(
            id: UUID(), squadId: UUID(), userId: UUID(),
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000),
            displayName: "Marcus",
            equippedTitle: TitleID(path: .axis(.power), tier: .silver),
            buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        )
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(SquadMember.self, from: data)
        XCTAssertEqual(decoded, m)
    }

    func testNilOptionalsRoundtrip() throws {
        let m = SquadMember(
            id: UUID(), squadId: UUID(), userId: UUID(),
            joinedAt: .now,
            displayName: "Maya",
            equippedTitle: nil,
            buildIdentity: nil
        )
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(SquadMember.self, from: data)
        XCTAssertEqual(decoded, m)
    }
}
