import XCTest
@testable import UNBOUND

final class NextGateCardModelTests: XCTestCase {
    private func readiness(
        status: OverallRankTrialStatus,
        requirements: [OverallRankTrialRequirementLine]
    ) -> OverallRankTrialReadiness {
        OverallRankTrialReadiness(
            status: status, currentRank: .apprentice, targetRank: .forged,
            definition: OverallRankTrialDefinitions.theForging,
            resolvedTrial: nil, blockerSummary: nil,
            requirements: requirements, latestAttempt: nil
        )
    }

    private func req(_ id: String, _ kind: OverallRankTrialRequirementKind, met: Bool) -> OverallRankTrialRequirementLine {
        .init(id: id, kind: kind, label: id, current: "", required: "", isMet: met)
    }

    func testLockedWithUnmetRequirementsIsSealed() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [req("lvl", .overallLevel, met: false)]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .sealed)
        XCTAssertNil(model.ctaTitle)
    }

    func testReadyIsOpenWithBeginCTA() {
        let model = NextGateCardModel(
            readiness: readiness(status: .ready, requirements: [req("lvl", .overallLevel, met: true)]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .open)
        XCTAssertEqual(model.ctaTitle, "OPEN THE GATE")
    }

    func testFailedIsOpenWithReenterCTA() {
        let model = NextGateCardModel(
            readiness: readiness(status: .failed, requirements: []),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.presentation, .open)
        XCTAssertEqual(model.ctaTitle, "ENTER AGAIN")
    }

    func testKeyFragmentsComeFromGateKeyRequirementsOnly() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                req("lvl", .overallLevel, met: true),
                req("key-forge-pullups", .gateKey, met: true),
                req("key-forge-hinge", .gateKey, met: false)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.keyFragments.map(\.id), ["key-forge-pullups", "key-forge-hinge"])
        XCTAssertEqual(model.keyFragments.filter(\.isLit).count, 1)
        XCTAssertEqual(model.questItems.map(\.id), ["lvl"])
    }

    func testNoDefinitionIsCleared() {
        let r = OverallRankTrialReadiness(status: .passed, currentRank: .unbound, targetRank: nil,
            definition: nil, resolvedTrial: nil, blockerSummary: nil, requirements: [], latestAttempt: nil)
        let model = NextGateCardModel(readiness: r, world: GateWorldCatalog.world(for: .theLastGate))
        XCTAssertEqual(model.presentation, .cleared)
    }
}
