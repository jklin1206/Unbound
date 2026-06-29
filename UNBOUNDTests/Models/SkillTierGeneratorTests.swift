import XCTest
@testable import UNBOUND

// Generator: real strength data → a full 9-tier ladder. Grind moves spread across
// all 9 (accelerating, no creep, elite-not-freak top); apex feats scale on their
// OWN movement — Initiate = 1 rep/second, climbing geometrically to an elite
// ceiling at Unbound (no regressions or borrowed exercises in the ladder).

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
        XCTAssertEqual(reps(ladder[.unbound]), 32)   // Elite level = peak
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

    func testScaledFeatStartsAtOneAndStrictlyIncreases() {
        // one-arm pull-up: ranks on its OWN movement. Initiate = 1 rep, climbing
        // with no repeats to an elite ceiling at Unbound. No regressions in the
        // ladder — the route to the first rep lives in the unlock gate + program.
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.one-arm-pullup"]!)
        XCTAssertEqual(ladder.count, 9)
        XCTAssertEqual(reps(ladder[.initiate]), 1, "Initiate = 1 rep of the real movement")
        let values = SkillTier.allCases.map { reps(ladder[$0]) ?? -1 }
        for i in 1..<values.count {
            XCTAssertGreaterThan(values[i], values[i - 1], "tier \(i) must exceed tier \(i-1) — no repeats")
        }
        XCTAssertEqual(reps(ladder[.unbound]), 12)   // elite one-arm pull-up ceiling
    }

    func testScaledFeatHitsCeilingAtUnbound() {
        // ring muscle-up scales 1 → 11 on its own reps.
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.ring-muscle-up"]!)
        XCTAssertEqual(reps(ladder[.initiate]), 1)
        XCTAssertEqual(reps(ladder[.unbound]), 11)
    }

    func testEveryPullAnchorGeneratesNineCompleteTiers() {
        // Catches a malformed feat ladder count or any missing tier.
        XCTAssertEqual(PullSkillAnchors.table.count, 26, "all 26 pull nodes should be authored")
        for (id, anchor) in PullSkillAnchors.table {
            let ladder = SkillTierGenerator.generate(anchor)
            XCTAssertEqual(ladder.count, 9, "\(id) must generate exactly 9 tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(ladder[tier], "\(id) missing tier \(tier)")
            }
        }
    }

    func testWeightedUsesBodyweightRatioCriterion() {
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.weighted-pullup"]!)
        guard case .exerciseBodyweightRatio(let ratio, let ex)? = ladder[.unbound] else {
            return XCTFail("weighted pull-up peak should be a bodyweight-ratio criterion")
        }
        XCTAssertEqual(ratio, 1.0, accuracy: 0.001)   // Elite = +100% bw
        XCTAssertEqual(ex, "weighted pullup")
    }

    func testHoldUsesExerciseSecondsCriterion() {
        let ladder = SkillTierGenerator.generate(PullSkillAnchors.table["pp.dead-hang"]!)
        guard case .exerciseSeconds(let secs, _)? = ladder[.unbound] else {
            return XCTFail("dead hang peak should be an exercise-seconds criterion")
        }
        XCTAssertEqual(secs, 120)   // Elite = 2 min
    }
}
