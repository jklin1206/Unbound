// Phase 5: the attribute trial gate now reads permanent xp-derived LEVEL
// (peak/current/drift were deleted). Level never decays, so a proven axis
// stays met across any layoff — these tests assert that with the new model.
import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialPeakGateTests: XCTestCase {

    /// Profile where every attribute sits at `level`.
    private func profile(level: Int) -> AttributeProfile {
        var p = AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0))
        let xp = AttributeLevelCurve.xpRequired(forLevel: level)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(xp: xp, lastContributionAt: Date(timeIntervalSince1970: 0)))
        }
        return p
    }

    private func topAttributesLine(currentRank: RankTitle, profile: AttributeProfile) -> OverallRankTrialRequirementLine? {
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: currentRank,
                overallLevel: 9_999,                 // saturate non-attribute gates
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: profile
            )
        )
        return readiness.requirements.first { $0.id == "top-attributes" }
    }

    /// At or above the floor LEVEL satisfies the gate (and stays satisfied —
    /// level is permanent, never lost to a layoff).
    func testAttributeGateMetAtFloorLevel() {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: .apprentice),
              definition.topAttributeCount > 0 else {
            return XCTFail("Expected a rank gate with an attribute requirement after Apprentice")
        }
        let atFloor = profile(level: Int(definition.topAttributeFloor))
        let line = topAttributesLine(currentRank: .apprentice, profile: atFloor)
        XCTAssertEqual(line?.isMet, true, "Level at/above the floor must satisfy the gate")
    }

    /// Negative control: below the floor level stays locked.
    func testAttributeGateLocksBelowFloorLevel() {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: .apprentice),
              definition.topAttributeCount > 0 else {
            return XCTFail("Expected a rank gate with an attribute requirement after Apprentice")
        }
        let belowFloor = profile(level: max(0, Int(definition.topAttributeFloor) - 5))
        let line = topAttributesLine(currentRank: .apprentice, profile: belowFloor)
        XCTAssertEqual(line?.isMet, false, "A level below the floor must keep the gate locked")
    }
}
