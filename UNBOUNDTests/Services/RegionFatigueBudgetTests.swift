import XCTest
@testable import UNBOUND

final class RegionFatigueBudgetTests: XCTestCase {
    func testCrossRegionAddsDoNotCreateTrim() {
        let sources = [
            RegionFatigueSource(kind: .skillBlock, regionLoad: RegionLoad([.pull: 2])),
            RegionFatigueSource(kind: .weeklyVow, regionLoad: RegionLoad([.legs: 2]))
        ]
        let budget = RegionLoad([.pull: 3, .legs: 3])

        XCTAssertTrue(RegionFatigueBudget.trimRecommendations(sources: sources, budget: budget).isEmpty)
    }

    func testSameRegionOverBudgetTrimsOnlyThatRegion() throws {
        let sources = [
            RegionFatigueSource(kind: .plannedWorkout, regionLoad: RegionLoad([.pull: 3])),
            RegionFatigueSource(kind: .skillBlock, regionLoad: RegionLoad([.pull: 2]), protected: true),
            RegionFatigueSource(kind: .weeklyVow, regionLoad: RegionLoad([.legs: 1]))
        ]
        let budget = RegionLoad([.pull: 4, .legs: 3])

        let trims = RegionFatigueBudget.trimRecommendations(sources: sources, budget: budget)

        XCTAssertEqual(trims.map(\.region), [.pull])
        XCTAssertEqual(trims.first?.excessLoad, 1)
        XCTAssertEqual(trims.first?.protectedLoad, 2)
        XCTAssertEqual(trims.first?.reason.reasonCategory, .accessoryRemoved)
        XCTAssertEqual(trims.first?.reason.regionScope, .pull)
        XCTAssertEqual(trims.first?.reason.revertible, true)
    }

    func testEmptyWeekHasNoTrim() {
        XCTAssertTrue(
            RegionFatigueBudget.trimRecommendations(sources: [], budget: RegionLoad()).isEmpty
        )
    }
}
