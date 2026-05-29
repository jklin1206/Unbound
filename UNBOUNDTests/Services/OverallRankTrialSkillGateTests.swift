import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialSkillGateTests: XCTestCase {

    // MARK: - Pure group semantics

    private let group = OverallRankTrialSkillGroup(
        id: "g",
        label: "Signature skill",
        minimumCount: 1,
        options: [
            OverallRankTrialSkillStandard(skillId: "pp.muscle-up", displayName: "Muscle-up", minimumTier: .novice),
            OverallRankTrialSkillStandard(skillId: "ld.pistol-squat", displayName: "Pistol squat", minimumTier: .novice)
        ]
    )

    func testGroupClearsViaEitherPath() {
        XCTAssertFalse(group.isMet(skillTiers: [:]), "Neither path → locked")
        XCTAssertTrue(group.isMet(skillTiers: ["pp.muscle-up": .novice]), "Pull path clears it")
        XCTAssertTrue(group.isMet(skillTiers: ["ld.pistol-squat": .apprentice]), "Leg path clears it")
        XCTAssertFalse(group.isMet(skillTiers: ["pp.muscle-up": .initiate]), "Below the tier → locked")
    }

    func testGroupCountReflectsMetOptions() {
        XCTAssertEqual(group.metCount(skillTiers: [:]), 0)
        XCTAssertEqual(group.metCount(skillTiers: ["pp.muscle-up": .novice, "ld.pistol-squat": .novice]), 2)
    }

    // MARK: - Wired into readiness (the representative Master gate)

    private func masterReadiness(skillTiers: [String: SkillTier]) -> OverallRankTrialReadiness {
        var profile = AttributeProfile.empty(userId: "u", at: Date(timeIntervalSince1970: 0))
        for key in AttributeKey.allCases {
            profile.set(key, AttributeValue(peak: 100, current: 100, lastContributionAt: Date(timeIntervalSince1970: 0)))
        }
        return TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u",
                currentRank: .veteran,          // next trial = Master gauntlet
                overallLevel: 9_999,
                movementProgress: [:],
                skillTiers: skillTiers,
                attributeProfile: profile
            )
        )
    }

    func testMasterGateExposesPathAwareSkillLine() {
        let locked = masterReadiness(skillTiers: [:])
        guard let line = locked.requirements.first(where: { $0.id == "skill-group-master-signature-skill" }) else {
            return XCTFail("Master gate must expose a path-aware skill-group line")
        }
        XCTAssertFalse(line.isMet, "No signature skill → group locked")
        XCTAssertEqual(line.current, "0/1")

        // Either path satisfies the group.
        let viaPull = masterReadiness(skillTiers: ["pp.muscle-up": .novice])
            .requirements.first { $0.id == "skill-group-master-signature-skill" }
        XCTAssertEqual(viaPull?.isMet, true)

        let viaLegs = masterReadiness(skillTiers: ["ld.pistol-squat": .novice])
            .requirements.first { $0.id == "skill-group-master-signature-skill" }
        XCTAssertEqual(viaLegs?.isMet, true)
    }
}
