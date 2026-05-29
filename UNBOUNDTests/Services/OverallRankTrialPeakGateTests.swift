import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialPeakGateTests: XCTestCase {

    /// Profile where every attribute has PEAKED at `peak` but `current` has
    /// drifted down to `current` (a layoff).
    private func profile(peak: Double, current: Double) -> AttributeProfile {
        var p = AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0))
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: peak, current: current, lastContributionAt: Date(timeIntervalSince1970: 0)))
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

    /// Kickoff/WS-C decision: trials gate on PEAK. A proven peak that later
    /// drifts in `current` must still satisfy the attribute requirement.
    func testAttributeGateUsesPeakNotCurrent() {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: .apprentice),
              definition.topAttributeCount > 0 else {
            return XCTFail("Expected a rank gate with an attribute requirement after Apprentice")
        }
        let floor = definition.topAttributeFloor

        // Peaked at floor, but current drifted to zero.
        let peakOnly = profile(peak: floor, current: 0)
        let line = topAttributesLine(currentRank: .apprentice, profile: peakOnly)
        XCTAssertEqual(line?.isMet, true, "Peaked attributes must satisfy the gate even after drift")
    }

    /// Negative control: never having reached the floor (peak below) stays locked.
    func testAttributeGateStillLocksWhenPeakBelowFloor() {
        guard let definition = OverallRankTrialDefinitions.nextTrial(after: .apprentice),
              definition.topAttributeCount > 0 else {
            return XCTFail("Expected a rank gate with an attribute requirement after Apprentice")
        }
        let belowFloor = profile(peak: definition.topAttributeFloor - 5, current: definition.topAttributeFloor - 5)
        let line = topAttributesLine(currentRank: .apprentice, profile: belowFloor)
        XCTAssertEqual(line?.isMet, false, "A peak below the floor must keep the gate locked")
    }
}
