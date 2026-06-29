import XCTest
@testable import UNBOUND

/// Locks the Target Map precision contract: a movement's authored precise
/// `bodyRegions` must narrow the broad muscle-group expansion, so an isolation
/// lift stops lighting every region under its group. Regression guard for the
/// rank-library redesign, which briefly ranked from `muscleGroups` only and so
/// fanned leg extension (quads-only) out into quads/hamstrings/glutes/calves.
final class ProgramRankTargetRegionSetTests: XCTestCase {

    private func regions(
        _ result: [ProgramRankTargetRegionSet.RankedTargetRegion]
    ) -> [BodyRegion] {
        result.map(\.region)
    }

    private func tier(
        _ result: [ProgramRankTargetRegionSet.RankedTargetRegion],
        _ region: BodyRegion
    ) -> Int? {
        result.first { $0.region == region }?.rank
    }

    /// Leg extension: broad `muscleGroups` is [.legs] but the authored precise
    /// regions are [.quads]. The map must light ONLY quads (at PRIMARY), never
    /// the rest of the leg group.
    func testIsolationPreciseRegionsNarrowTheGroupExpansion() {
        let result = ProgramRankTargetRegionSet.rankedRegions(
            muscleGroups: [.legs],
            bodyRegions: [.quads]
        )
        XCTAssertEqual(regions(result), [.quads])
        XCTAssertEqual(tier(result, .quads), 0)
        XCTAssertFalse(regions(result).contains(.hamstrings))
        XCTAssertFalse(regions(result).contains(.glutes))
        XCTAssertFalse(regions(result).contains(.calves))
    }

    /// No precise data: the broad group still expands in full (prior behavior
    /// preserved for movements that carry no per-exercise regions).
    func testNoPreciseRegionsExpandsTheFullGroup() {
        let result = ProgramRankTargetRegionSet.rankedRegions(
            muscleGroups: [.legs],
            bodyRegions: []
        )
        XCTAssertEqual(Set(regions(result)), [.quads, .hamstrings, .glutes, .calves])
    }

    /// A precise region that belongs to no listed group (rear delts on a
    /// [.shoulders] movement, e.g. a face pull) must still show as a trailing
    /// tier; precision must never silently drop a real target.
    func testPreciseRegionOutsideGroupStillShows() {
        let result = ProgramRankTargetRegionSet.rankedRegions(
            muscleGroups: [.shoulders],
            bodyRegions: [.rearDelts, .rhomboids, .traps]
        )
        let lit = Set(regions(result))
        XCTAssertTrue(lit.contains(.rearDelts))
        XCTAssertTrue(lit.contains(.rhomboids))
        XCTAssertTrue(lit.contains(.traps))
        // The group's own region is dropped because it is not in the precise set.
        XCTAssertFalse(lit.contains(.frontSideDelts))
    }

    /// The skill-node path keeps its authored group importance (no precise
    /// filter), so a core skill still expands core into all three regions.
    func testNoPreciseFilterKeepsFullCoreExpansion() {
        let result = ProgramRankTargetRegionSet.rankedRegions(
            muscleGroups: [.core],
            bodyRegions: []
        )
        XCTAssertEqual(Set(regions(result)), [.abs, .obliques, .lowerBack])
    }

    /// Ranking still caps at the top 3 importance tiers regardless of input.
    func testRanksCapAtThreeTiers() {
        let result = ProgramRankTargetRegionSet.rankedRegions(
            muscleGroups: [.chest, .arms, .core, .legs],
            bodyRegions: []
        )
        XCTAssertLessThanOrEqual(result.map(\.rank).max() ?? -1, 2)
    }
}
