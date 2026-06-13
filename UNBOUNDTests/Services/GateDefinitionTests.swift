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

    func testGate4DeckOfProofStations() {
        let gate = OverallRankTrialDefinitions.deckOfProof
        XCTAssertEqual(gate.id, "gate-04-deck-of-proof")
        XCTAssertEqual(gate.format, .deckOfProof)
        XCTAssertEqual(gate.displayName, "Deck of Proof")
        XCTAssertEqual(gate.targetRank, .veteran)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-veteran-reckoning"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-forged-reckoning"))

        let expectedIds = (1...52).map { String(format: "deck-card-%02d", $0) }
        let rankValues = [
            TrialStandards.DeckOfProof.aceReps,
            2, 3, 4, 5, 6, 7, 8, 9, 10,
            TrialStandards.DeckOfProof.faceCardReps,
            TrialStandards.DeckOfProof.faceCardReps,
            TrialStandards.DeckOfProof.faceCardReps
        ]
        let expectedValues = Array(repeating: rankValues, count: 4).flatMap { $0 }

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 52, loadout.displayName)
            XCTAssertEqual(stations.map(\.id), expectedIds, loadout.displayName)
            XCTAssertEqual(stations.map(\.standard.minimumValue), expectedValues, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { $0.standard.restSeconds == TrialStandards.DeckOfProof.restSeconds }, loadout.displayName)
            XCTAssertEqual(stations.prefix(13).map(\.category), Array(repeating: .push, count: 13), loadout.displayName)
            XCTAssertEqual(stations.dropFirst(13).prefix(13).map(\.category), Array(repeating: .lower, count: 13), loadout.displayName)
            XCTAssertEqual(stations.dropFirst(26).prefix(13).map(\.category), Array(repeating: .pull, count: 13), loadout.displayName)
            XCTAssertEqual(stations.dropFirst(39).prefix(13).map(\.category), Array(repeating: .carryCore, count: 13), loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home[0].title, "Card AH Pushups")
        XCTAssertEqual(home[13].title, "Card AD Squats")
        XCTAssertEqual(home[26].title, "Card AC Pullups")
        XCTAssertEqual(home[39].title, "Card AS Sit-Ups")
        XCTAssertEqual(home[26].standard.movementId, "exercise.pullup")
        XCTAssertEqual(home[26].standard.minimumValue, TrialStandards.DeckOfProof.aceReps)
    }

    func testGate4DeckOfProofPullRowOptionResolvesConvertedFloor() throws {
        let gate = OverallRankTrialDefinitions.deckOfProof
        let tenValuePullCard = try XCTUnwrap(gate.stations(for: .homeKit).first { $0.id == "deck-card-36" })

        XCTAssertEqual(tenValuePullCard.title, "Card 10C Pullups")
        XCTAssertEqual(tenValuePullCard.standard.minimumValue, 10)
        XCTAssertNil(tenValuePullCard.movementOptions.first { $0.movementId == "exercise.pullup" }?.floorOverride)
        XCTAssertEqual(tenValuePullCard.resolvedMinimum(forMovementId: "exercise.pullup"), 10)
        XCTAssertEqual(tenValuePullCard.resolvedMinimum(forMovementId: "exercise.inverted-row"), 15)
        XCTAssertEqual(tenValuePullCard.resolvedMinimum(forMovementId: "exercise.dumbbell-row"), 15)
    }

    func testGate5TheAscentStations() throws {
        let gate = OverallRankTrialDefinitions.theAscent
        XCTAssertEqual(gate.id, "gate-05-the-ascent")
        XCTAssertEqual(gate.format, .theAscent)
        XCTAssertEqual(gate.displayName, "The Ascent")
        XCTAssertEqual(gate.targetRank, .master)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-master-gauntlet"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-veteran-gauntlet"))

        let expectedIds = [
            "ascent-floor-01", "ascent-floor-02", "ascent-floor-03",
            "ascent-floor-04", "ascent-floor-05", "ascent-floor-06",
            "ascent-floor-07", "ascent-floor-08", "ascent-floor-09-push",
            "ascent-floor-09-pull", "ascent-floor-10"
        ]

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 11, loadout.displayName)
            XCTAssertEqual(stations.map(\.id), expectedIds, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home.map(\.title), [
            "Floor 1 — The Path", "Floor 2 — The Work Floors", "Floor 3 — The Work Floors",
            "Floor 4 — The Work Floors", "Floor 5 — The Work Floors", "Floor 6 — The Work Floors",
            "Floor 7 — The Cloudline", "Floor 8 — Thin Air", "Floor 9 — Thin Air",
            "Floor 9 — Thin Air", "Floor 10 — The Summit Gate"
        ])
        XCTAssertEqual(home[0].standard.minimumValue, TrialStandards.TheAscent.floor1Meters)
        XCTAssertEqual(home[1].standard.minimumValue, TrialStandards.TheAscent.lowerReps)
        XCTAssertEqual(home[2].standard.minimumValue, TrialStandards.TheAscent.pushReps)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.TheAscent.hingeReps)
        XCTAssertEqual(home[5].standard.minimumValue, TrialStandards.TheAscent.carryMeters)
        XCTAssertEqual(home[5].loadPercentOfBodyweight, TrialStandards.TheAscent.carryLoadPercentLoaded)
        XCTAssertEqual(home[6].standard.minimumValue, TrialStandards.TheAscent.longEngineMeters)
        XCTAssertEqual(home[7].standard.minimumValue, TrialStandards.TheAscent.explosiveReps)
        XCTAssertEqual(home[8].standard.minimumValue, TrialStandards.TheAscent.blendPushReps)
        XCTAssertEqual(home[10].standard.minimumValue, TrialStandards.TheAscent.bossHoldSeconds)
        XCTAssertEqual(home[10].capSeconds, TrialStandards.TheAscent.bossHoldCapSeconds)

        let floor4 = try XCTUnwrap(home.first { $0.id == "ascent-floor-04" })
        XCTAssertEqual(floor4.standard.movementId, "exercise.pullup")
        XCTAssertEqual(floor4.standard.minimumValue, TrialStandards.TheAscent.pullUpReps)
        let floor4Pullup = try XCTUnwrap(floor4.movementOptions.first { $0.movementId == "exercise.pullup" })
        XCTAssertEqual(floor4Pullup.requiredEquipment, Set([.pullupBar]))
        XCTAssertEqual(floor4.resolvedMinimum(forMovementId: "exercise.pullup"), TrialStandards.TheAscent.pullUpReps)
        XCTAssertEqual(floor4.resolvedMinimum(forMovementId: "exercise.inverted-row"), TrialStandards.TheAscent.rowFallbackReps)
        XCTAssertEqual(floor4.resolvedMinimum(forMovementId: "exercise.dumbbell-row"), TrialStandards.TheAscent.rowFallbackReps)

        let floor9Pull = try XCTUnwrap(home.first { $0.id == "ascent-floor-09-pull" })
        XCTAssertEqual(floor9Pull.standard.movementId, "exercise.pullup")
        XCTAssertEqual(floor9Pull.standard.minimumValue, TrialStandards.TheAscent.blendPullUpReps)
        XCTAssertEqual(floor9Pull.resolvedMinimum(forMovementId: "exercise.pullup"), TrialStandards.TheAscent.blendPullUpReps)
        XCTAssertEqual(floor9Pull.resolvedMinimum(forMovementId: "exercise.inverted-row"), TrialStandards.TheAscent.blendRowFallbackReps)

        let noGym = gate.stations(for: .noGymField)
        let noGymFloor4 = try XCTUnwrap(noGym.first { $0.id == "ascent-floor-04" })
        XCTAssertEqual(noGymFloor4.resolvedMinimum(forMovementId: "exercise.inverted-row"), TrialStandards.TheAscent.rowFallbackReps)
        XCTAssertEqual(noGym.first { $0.id == "ascent-floor-06" }?.loadPercentOfBodyweight, TrialStandards.TheAscent.carryLoadPercentNoGym)
    }
}

private extension OverallRankTrialDefinition {
    func stations(for loadout: TrialLoadout) -> [TrialStation] {
        loadoutVariants.first { $0.loadout == loadout }?.stations ?? []
    }
}
