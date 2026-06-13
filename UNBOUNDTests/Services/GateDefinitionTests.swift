import XCTest
@testable import UNBOUND

final class GateDefinitionTests: XCTestCase {
    func testGate1FirstLightStations() {
        let gate = OverallRankTrialDefinitions.firstLight
        XCTAssertEqual(gate.id, "gate-01-first-light")
        XCTAssertEqual(gate.format, .firstLight)
        XCTAssertEqual(gate.displayName, "First Light")
        XCTAssertEqual(gate.targetRank, .novice)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-novice-awakening"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-novice-foundation-proof"))

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 5, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home.map(\.id), [
            "firstlight-path", "firstlight-posts", "firstlight-banner",
            "firstlight-steps", "firstlight-door"
        ])
        XCTAssertEqual(home[3].capSeconds, TrialStandards.FirstLight.stepWindowSeconds)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.FirstLight.trunkHoldSeconds)
    }
}

private extension OverallRankTrialDefinition {
    func stations(for loadout: TrialLoadout) -> [TrialStation] {
        loadoutVariants.first { $0.loadout == loadout }?.stations ?? []
    }
}
