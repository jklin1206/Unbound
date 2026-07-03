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

    func testQuestItemDetailShowsConcreteRequirement() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                .init(id: "lvl", kind: .overallLevel, label: "Overall LVL",
                      current: "LVL 3", required: "LVL 15", isMet: false),
                .init(id: "equip", kind: .equipment, label: "Equipment",
                      current: "Bodyweight", required: "Pull-up Bar", isMet: false),
                .init(id: "rank", kind: .rank, label: "Build to Forged",
                      current: "Apprentice", required: "Forged", isMet: false)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.questItems.map(\.detail),
                       ["LVL 3 / LVL 15", "Needs Pull-up Bar", "Now Apprentice"])
    }

    func testQuestItemDetailQuietsWhenMetOrEmpty() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                .init(id: "lvl", kind: .overallLevel, label: "Overall LVL",
                      current: "LVL 20", required: "LVL 15", isMet: true),
                .init(id: "bare", kind: .overallLevel, label: "bare",
                      current: "", required: "", isMet: false)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.questItems.map(\.detail), ["LVL 20", nil])
    }

    func testMetEquipmentIsNotAQuestItem() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                .init(id: "lvl", kind: .overallLevel, label: "Overall LVL",
                      current: "LVL 20", required: "LVL 15", isMet: true),
                .init(id: "equip", kind: .equipment, label: "Equipment",
                      current: "Full Gym", required: "Barbell", isMet: true)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.questItems.map(\.id), ["lvl"])
    }

    func testMissingEquipmentSurfacesAsBlockerQuestItem() {
        let model = NextGateCardModel(
            readiness: readiness(status: .locked, requirements: [
                .init(id: "equip", kind: .equipment, label: "Equipment",
                      current: "Bodyweight", required: "Pull-up Bar", isMet: false)
            ]),
            world: GateWorldCatalog.world(for: .theForging))
        XCTAssertEqual(model.questItems.map(\.id), ["equip"])
        XCTAssertEqual(model.questItems.first?.detail, "Needs Pull-up Bar")
    }

    func testNoDefinitionIsCleared() {
        let r = OverallRankTrialReadiness(status: .passed, currentRank: .unbound, targetRank: nil,
            definition: nil, resolvedTrial: nil, blockerSummary: nil, requirements: [], latestAttempt: nil)
        let model = NextGateCardModel(readiness: r, world: GateWorldCatalog.world(for: .theLastGate))
        XCTAssertEqual(model.presentation, .cleared)
    }
}
