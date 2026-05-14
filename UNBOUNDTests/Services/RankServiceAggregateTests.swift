// UNBOUNDTests/Services/RankServiceAggregateTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class RankServiceAggregateTests: XCTestCase {
    func testMockAggregateRankReturnsOverride() async {
        let svc = MockRankService()
        svc.archetypeRankOverride = .b
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .b)
    }

    func testMockAggregateRankDefaultsToC() async {
        let svc = MockRankService()  // default override = .c
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .c)
    }
}
