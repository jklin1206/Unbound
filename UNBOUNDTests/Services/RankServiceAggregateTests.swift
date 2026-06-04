// UNBOUNDTests/Services/RankServiceAggregateTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class RankServiceAggregateTests: XCTestCase {
    func testMockAggregateRankReturnsOverride() async {
        let svc = MockRankService()
        svc.aggregateRankOverride = .master
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .master)
    }

    func testMockAggregateRankDefaultsToForged() async {
        let svc = MockRankService()
        let rank = await svc.aggregateRank(userId: "u")
        XCTAssertEqual(rank, .forged)
    }
}
