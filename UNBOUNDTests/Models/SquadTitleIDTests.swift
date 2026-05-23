import XCTest
@testable import UNBOUND

final class SquadTitleIDTests: XCTestCase {
    func testLinkedSessionsRoundtrip() throws {
        let id = SquadTitleID(category: .linkedSessions, axis: nil, tier: 2)
        try roundtrip(id)
    }
    func testSquadStreakRoundtrip() throws {
        let id = SquadTitleID(category: .squadStreak, axis: nil, tier: 3)
        try roundtrip(id)
    }
    func testCollectiveAxisRoundtrip() throws {
        let id = SquadTitleID(category: .collectiveAxis, axis: .power, tier: 1)
        try roundtrip(id)
    }
    func testAffinityTenureRoundtrip() throws {
        let id = SquadTitleID(category: .affinityTenure, axis: .mobility, tier: 2)
        try roundtrip(id)
    }
    func testHashableInSet() {
        let a = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)
        let b = SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)
        let c = SquadTitleID(category: .linkedSessions, axis: nil, tier: 2)
        var set: Set<SquadTitleID> = [a]
        XCTAssertTrue(set.contains(b))
        set.insert(c)
        XCTAssertEqual(set.count, 2)
    }

    private func roundtrip(_ id: SquadTitleID) throws {
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(SquadTitleID.self, from: data)
        XCTAssertEqual(decoded, id)
    }
}
