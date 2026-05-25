import XCTest
@testable import UNBOUND

final class RewardPayloadBuilderTests: XCTestCase {
    func testSingleStandardCreatesOneBeatWithoutIgnitionWhenNoRankCrosses() {
        let result = result(standards: [standard(.forged)], unlocks: [], multiRankEvent: nil)

        let payload = RewardPayloadBuilder.proofPayload(from: result)

        XCTAssertEqual(payload.beats.count, 1)
        XCTAssertEqual(payload.tally.standardsCleared, 1)
        XCTAssertEqual(payload.tally.ranksAdvanced, 0)
        XCTAssertFalse(payload.emblemIgnition)
    }

    func testSixStandardsCollapseIntoOneTallyAndOneIgnition() {
        let standards = [
            standard(.initiate),
            standard(.novice),
            standard(.apprentice),
            standard(.forged),
            standard(.veteran),
            standard(.honed)
        ]
        let rankEvent = RankAdvancement(
            skillId: "pp.pullup",
            skillTitle: "Pull-Up",
            fromTier: nil,
            toTier: .honed,
            ranksAdvanced: 6
        )

        let payload = RewardPayloadBuilder.proofPayload(
            from: result(
                standards: standards.shuffled(),
                unlocks: [SkillUnlock(skillId: "pp.pullup", skillTitle: "Pull-Up", tier: .honed)],
                multiRankEvent: rankEvent
            )
        )

        XCTAssertEqual(payload.beats.count, 6)
        XCTAssertEqual(payload.beats.map(\.tier), standards.map(\.tier))
        XCTAssertEqual(payload.tally.standardsCleared, 6)
        XCTAssertEqual(payload.tally.unlocksGained, 1)
        XCTAssertEqual(payload.tally.ranksAdvanced, 6)
        XCTAssertTrue(payload.emblemIgnition)
    }

    func testAttachProofRewardsExtendsExistingWorkoutSummary() {
        let summary = WorkoutRewardSequenceSummary.simpleReceipt(
            workoutName: "Pull Day",
            durationMinutes: 20,
            workSets: 3,
            xpTotal: 10,
            xpLabel: "Session",
            sourceName: "Program"
        )
        let attached = RewardPayloadBuilder.attachProofRewards(
            result(standards: [standard(.forged)], unlocks: [], multiRankEvent: nil),
            to: summary
        )

        XCTAssertEqual(attached.beats.count, 1)
        XCTAssertEqual(attached.tally.standardsCleared, 1)
        XCTAssertFalse(attached.emblemIgnition)
        XCTAssertEqual(attached.workoutName, "Pull Day")
    }

    private func standard(_ tier: SkillTier) -> SkillStandard {
        SkillStandard(
            skillId: "pp.pullup",
            skillTitle: "Pull-Up",
            tier: tier,
            criterion: .reps(max(1, tier.rawValue + 1), exerciseName: "pullup"),
            proofFamily: .reps
        )
    }

    private func result(
        standards: [SkillStandard],
        unlocks: [SkillUnlock],
        multiRankEvent: RankAdvancement?
    ) -> ProofEngineResult {
        ProofEngineResult(
            logId: "log-1",
            source: .custom,
            achievedProofs: [],
            standardsCleared: standards,
            prereqsCleared: [],
            unlocks: unlocks,
            multiRankEvent: multiRankEvent,
            newBests: []
        )
    }
}
