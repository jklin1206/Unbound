import XCTest
@testable import UNBOUND

final class SquadTitleThresholdEvaluatorTests: XCTestCase {
    typealias Counters = SquadTitleThresholdEvaluator.Counters

    func testLinkedBronzeCrossing() {
        var prior = Counters(); prior.linkedSessionsCount = 9
        var current = Counters(); current.linkedSessionsCount = 10
        XCTAssertEqual(
            SquadTitleThresholdEvaluator.crossings(prior: prior, current: current),
            [SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)]
        )
    }

    func testLinkedSilverCrossing() {
        var prior = Counters(); prior.linkedSessionsCount = 49
        var current = Counters(); current.linkedSessionsCount = 50
        XCTAssertEqual(
            SquadTitleThresholdEvaluator.crossings(prior: prior, current: current),
            [SquadTitleID(category: .linkedSessions, axis: nil, tier: 2)]
        )
    }

    func testStreakGoldCrossing() {
        var prior = Counters(); prior.squadStreakWeeks = 51
        var current = Counters(); current.squadStreakWeeks = 52
        XCTAssertEqual(
            SquadTitleThresholdEvaluator.crossings(prior: prior, current: current),
            [SquadTitleID(category: .squadStreak, axis: nil, tier: 3)]
        )
    }

    func testCollectiveAxisCrossing() {
        var prior = Counters(); prior.collectiveAxisRankUps[.power] = 24
        var current = Counters(); current.collectiveAxisRankUps[.power] = 25
        XCTAssertEqual(
            SquadTitleThresholdEvaluator.crossings(prior: prior, current: current),
            [SquadTitleID(category: .collectiveAxis, axis: .power, tier: 1)]
        )
    }

    func testAffinityTenureCrossing() {
        var prior = Counters(); prior.affinityTenureMonths[.mobility] = 1
        var current = Counters(); current.affinityTenureMonths[.mobility] = 2
        XCTAssertEqual(
            SquadTitleThresholdEvaluator.crossings(prior: prior, current: current),
            [SquadTitleID(category: .affinityTenure, axis: .mobility, tier: 1)]
        )
    }

    func testNoCrossingWhenAlreadyPast() {
        var prior = Counters(); prior.linkedSessionsCount = 50
        var current = Counters(); current.linkedSessionsCount = 60
        XCTAssertTrue(SquadTitleThresholdEvaluator.crossings(prior: prior, current: current).isEmpty)
    }

    func testNoCrossingWhenBelow() {
        var prior = Counters(); prior.linkedSessionsCount = 5
        var current = Counters(); current.linkedSessionsCount = 9
        XCTAssertTrue(SquadTitleThresholdEvaluator.crossings(prior: prior, current: current).isEmpty)
    }

    func testSimultaneousMultiCategory() {
        var prior = Counters()
        prior.linkedSessionsCount = 9
        prior.squadStreakWeeks = 3
        var current = Counters()
        current.linkedSessionsCount = 10
        current.squadStreakWeeks = 4
        let crossings = SquadTitleThresholdEvaluator.crossings(prior: prior, current: current)
        XCTAssertEqual(crossings.count, 2)
        XCTAssertTrue(crossings.contains(SquadTitleID(category: .linkedSessions, axis: nil, tier: 1)))
        XCTAssertTrue(crossings.contains(SquadTitleID(category: .squadStreak, axis: nil, tier: 1)))
    }
}
