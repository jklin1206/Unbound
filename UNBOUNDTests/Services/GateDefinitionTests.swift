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

    func testGate3TheForgingStations() {
        let gate = OverallRankTrialDefinitions.theForging
        XCTAssertEqual(gate.id, "gate-03-the-forging")
        XCTAssertEqual(gate.format, .theForging)
        XCTAssertEqual(gate.displayName, "The Forging")
        XCTAssertEqual(gate.targetRank, .forged)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-forged-forge"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-honed-forge"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-master-forge"))

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.map(\.id), [
                "forging-stoke", "forging-strike-hinge", "forging-strike-push",
                "forging-strike-pull", "forging-quench"
            ], loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home[0].standard.minimumValue, TrialStandards.TheForging.stokeEngineMeters)
        XCTAssertEqual(home[0].standard.minimumQualifyingSets, 1)
        XCTAssertNil(home[0].capSeconds)
        XCTAssertEqual(home[1].standard.minimumValue, TrialStandards.TheForging.scoredStrikeReps)
        XCTAssertEqual(home[1].standard.minimumQualifyingSets, 1)
        XCTAssertEqual(home[1].standard.plannedSets, 3)
        XCTAssertEqual(home[1].strengthTier, .forged)
        XCTAssertEqual(home[2].standard.minimumValue, TrialStandards.TheForging.scoredStrikeReps)
        XCTAssertEqual(home[2].standard.plannedSets, 3)
        XCTAssertEqual(home[2].strengthTier, .forged)
        XCTAssertEqual(home[3].standard.movementId, "exercise.pullup")
        XCTAssertEqual(home[3].standard.minimumValue, TrialStandards.TheForging.scoredPullReps)
        XCTAssertEqual(home[3].movementOptions.first { $0.movementId == "exercise.inverted-row" }?.floorOverride, 5)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.TheForging.quenchCarryMeters)
        XCTAssertEqual(home[4].loadPercentOfBodyweight, 0.30)

        let noGym = gate.stations(for: .noGymField)
        XCTAssertEqual(noGym[1].standard.movementId, "exercise.single-leg-rdl")
        XCTAssertEqual(noGym[1].loadPercentOfBodyweight, TrialStandards.TheForging.noGymHingeLoadPercent)
        XCTAssertNil(noGym[1].strengthTier)
        XCTAssertEqual(noGym[2].standard.movementId, "exercise.pushup")
        XCTAssertEqual(noGym[2].movementOptions.first?.floorOverride, 3)
        XCTAssertEqual(noGym[3].standard.movementId, "exercise.inverted-row")
        XCTAssertEqual(noGym[3].movementOptions.first?.floorOverride, 5)
        XCTAssertEqual(noGym[4].loadPercentOfBodyweight, 0.25)
    }

    func testGate3TheForgingStrikeStationsResolveForgedStrengthRatios() {
        let gate = OverallRankTrialDefinitions.theForging

        for loadout in [TrialLoadout.homeKit, .gymHybrid] {
            let strikeStations = gate.stations(for: loadout).filter { $0.strengthTier == .forged }
            XCTAssertEqual(strikeStations.map(\.id), [
                "forging-strike-hinge", "forging-strike-push"
            ], loadout.displayName)

            for station in strikeStations {
                let movementId = station.primaryMovement.movementId
                let movementKey = MovementCatalog.definition(for: movementId)?.canonicalExerciseName ?? movementId
                let ratio = StrengthStandards.ratio(exerciseKey: movementKey, tier: .forged, sex: nil)
                XCTAssertNotNil(ratio, "\(station.id) \(movementId) must resolve a Forged strength ratio")
                XCTAssertNotNil(
                    station.resolvedStrikeLoadKg(bodyweightKg: 80),
                    "\(station.id) \(movementId) must resolve a strike load"
                )
            }
        }
    }
}

private extension OverallRankTrialDefinition {
    func stations(for loadout: TrialLoadout) -> [TrialStation] {
        loadoutVariants.first { $0.loadout == loadout }?.stations ?? []
    }
}
