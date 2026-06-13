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

    func testGate2TheCountStations() {
        let gate = OverallRankTrialDefinitions.theCount
        XCTAssertEqual(gate.id, "gate-02-the-count")
        XCTAssertEqual(gate.format, .theCount)
        XCTAssertEqual(gate.displayName, "The Count")
        XCTAssertEqual(gate.targetRank, .apprentice)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-apprentice-calibration"))

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.map(\.id), [
                "count-long-bell", "count-second", "count-third",
                "count-fourth", "count-water-carry", "count-stillness"
            ], loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)

            let stillness = stations.first { $0.id == "count-stillness" }
            XCTAssertEqual(stillness?.standard.movementId, "exercise.plank", loadout.displayName)
            XCTAssertEqual(stillness?.standard.metric, .holdSeconds, loadout.displayName)
            XCTAssertEqual(stillness?.standard.minimumValue, TrialStandards.TheCount.stillnessHoldSeconds, loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home[0].standard.minimumValue, TrialStandards.TheCount.engineMeters)
        XCTAssertEqual(home[0].capSeconds, TrialStandards.TheCount.engineCapSeconds)
        XCTAssertEqual(home[1].standard.minimumValue, TrialStandards.TheCount.lowerReps)
        XCTAssertEqual(home[2].standard.minimumValue, TrialStandards.TheCount.pushReps)
        XCTAssertEqual(home[3].standard.minimumValue, TrialStandards.TheCount.pullReps)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.TheCount.carryMeters)
        XCTAssertEqual(home[4].loadPercentOfBodyweight, TrialStandards.TheCount.carryLoadPercent)
        XCTAssertEqual(home[4].capSeconds, TrialStandards.TheCount.carryCapSeconds)
        XCTAssertEqual(home[5].capSeconds, TrialStandards.TheCount.stationCapSeconds)
    }
}

private extension OverallRankTrialDefinition {
    func stations(for loadout: TrialLoadout) -> [TrialStation] {
        loadoutVariants.first { $0.loadout == loadout }?.stations ?? []
    }
}
