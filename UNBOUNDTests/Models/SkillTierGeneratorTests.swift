import XCTest
@testable import UNBOUND

// Generator: real strength data → a full 9-tier ladder. Grind moves spread across
// all 9 (accelerating, no creep, elite-not-freak top); hard feats start high — the
// first rep jumps to a floor rank, ranks below it are "not yet" (never padded).

final class SkillTierGeneratorTests: XCTestCase {

    private func reps(_ c: TierCriterion?) -> Int? {
        if case .reps(let n, _) = c { return n }
        return nil
    }

    func testInterpolationAnchorsAndMidpoints() {
        let t = SkillTierGenerator.interpolate(levels: [1, 6, 13, 23, 32])
        XCTAssertEqual(t[0], 1)
        XCTAssertEqual(t[2], 6)
        XCTAssertEqual(t[4], 13)
        XCTAssertEqual(t[6], 23)
        XCTAssertEqual(t[8], 32)
        XCTAssertEqual(t[1], 3.5)   // midpoint(1,6)
        XCTAssertEqual(t[5], 18)    // midpoint(13,23)
    }

    func testPullupGeneratesSensibleLadder() {
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.pullup"]!)
        XCTAssertEqual(ladder.count, 9)
        // 1, 4, 6, 10, 13, 18, 23, 28, 32 — real, accelerating, no creep.
        XCTAssertEqual(reps(ladder[.initiate]), 1)
        XCTAssertEqual(reps(ladder[.apprentice]), 6)   // Novice level
        XCTAssertEqual(reps(ladder[.veteran]), 13)     // Intermediate level
        XCTAssertEqual(reps(ladder[.vessel]), 23)      // Advanced level
        XCTAssertEqual(reps(ladder[.ascendant]), 32)   // Elite level = peak
    }

    func testFullAnchorsAreNinePresentAndStrictlyIncreasing() {
        for (id, anchor) in PullSkillAnchors.table {
            guard case .full = anchor.spec, anchor.metric == .reps else { continue }
            let ladder = SkillTierGenerator.generate(anchor)
            XCTAssertEqual(ladder.count, 9, "\(id) must have 9 tiers")
            let values = SkillTier.allCases.map { reps(ladder[$0]) ?? -1 }
            for i in 1..<values.count {
                XCTAssertGreaterThan(values[i], values[i - 1], "\(id) tier \(i) must exceed tier \(i-1)")
            }
        }
    }

    func testFeatStartsHighAndJumps() {
        // one-arm pull-up: floor = Master. The first rep should satisfy everything up
        // to Master (the jump); above that it climbs 2 / 3 / 5. Below the floor nothing
        // harder than 1 rep is asked — no double-down on other exercises.
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.one-arm-pullup"]!)
        XCTAssertEqual(ladder.count, 9)
        for tier in [SkillTier.initiate, .novice, .apprentice, .forged, .veteran, .master] {
            XCTAssertEqual(reps(ladder[tier]), 1, "\(tier) is the entry (1 rep → jump to Master)")
        }
        XCTAssertEqual(reps(ladder[.vessel]), 2)
        XCTAssertEqual(reps(ladder[.unbound]), 3)
        XCTAssertEqual(reps(ladder[.ascendant]), 5)   // peak = elite one-arm pull-up
    }

    func testFeatTopStrictlyIncreasesAboveFloor() {
        // ring muscle-up: floor Veteran, ladder climbs above it.
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.ring-muscle-up"]!)
        let above = [SkillTier.veteran, .master, .vessel, .unbound, .ascendant].map { reps(ladder[$0]) ?? -1 }
        for i in 1..<above.count {
            XCTAssertGreaterThan(above[i], above[i - 1])
        }
        XCTAssertEqual(reps(ladder[.veteran]), 1)   // first ring MU = Veteran
        XCTAssertEqual(reps(ladder[.ascendant]), 9)
    }

    func testWeightedUsesBodyweightRatioCriterion() {
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.weighted-pullup"]!)
        guard case .exerciseBodyweightRatio(let ratio, let ex)? = ladder[.ascendant] else {
            return XCTFail("weighted pull-up peak should be a bodyweight-ratio criterion")
        }
        XCTAssertEqual(ratio, 1.0, accuracy: 0.001)   // Elite = +100% bw
        XCTAssertEqual(ex, "weighted pullup")
    }

    func testHoldUsesExerciseSecondsCriterion() {
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.dead-hang"]!)
        guard case .exerciseSeconds(let secs, _)? = ladder[.ascendant] else {
            return XCTFail("dead hang peak should be an exercise-seconds criterion")
        }
        XCTAssertEqual(secs, 120)   // Elite = 2 min
    }
}
