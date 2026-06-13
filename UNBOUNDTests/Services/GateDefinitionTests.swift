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

    func testGate6SevenSealsStations() throws {
        let gate = OverallRankTrialDefinitions.sevenSeals
        XCTAssertEqual(gate.id, "gate-06-seven-seals")
        XCTAssertEqual(gate.format, .sevenSeals)
        XCTAssertEqual(gate.displayName, "The Seven Seals")
        XCTAssertEqual(gate.targetRank, .vessel)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-vessel-ten-hundred"))
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-vessel-crucible"))

        let expectedIds = [
            "seals-endurance", "seals-vitality", "seals-explosiveness",
            "seals-power", "seals-control", "seals-mobility", "seals-spirit"
        ]

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 7, loadout.displayName)
            XCTAssertEqual(stations.map(\.id), expectedIds, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { $0.capSeconds == TrialStandards.SevenSeals.sealCapSeconds }, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
            XCTAssertEqual(stations.last?.id, "seals-spirit", loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home[0].standard.minimumValue, TrialStandards.SevenSeals.enduranceEngineMeters)
        XCTAssertEqual(home[1].standard.minimumValue, TrialStandards.SevenSeals.vitalityLowerReps)
        XCTAssertEqual(home[2].category, .explosive)
        XCTAssertEqual(home[2].standard.minimumValue, TrialStandards.SevenSeals.explosivenessReps)
        XCTAssertEqual(home[3].category, .hingePower)
        XCTAssertEqual(home[3].standard.minimumValue, TrialStandards.SevenSeals.powerStrikeReps)
        XCTAssertEqual(home[3].standard.minimumQualifyingSets, 1)
        XCTAssertEqual(home[3].standard.plannedSets, 3)
        XCTAssertEqual(home[3].strengthTier, .vessel)
        XCTAssertEqual(home[4].standard.movementId, "exercise.plank")
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.SevenSeals.controlHoldSeconds)
        XCTAssertEqual(home[4].standard.minimumQualifyingSets, TrialStandards.SevenSeals.controlSets)
        XCTAssertEqual(home[4].standard.plannedSets, TrialStandards.SevenSeals.controlSets)
        XCTAssertEqual(home[5].standard.movementId, "mobility.deep-squat-hold")
        XCTAssertEqual(home[5].standard.metric, .holdSeconds)
        XCTAssertEqual(home[5].standard.minimumValue, TrialStandards.SevenSeals.mobilityDeepSquatHoldSeconds)
        XCTAssertEqual(home[5].movementOptions.first?.requiredEquipment, Set([.bodyweight, .openSpace]))
        XCTAssertEqual(home[6].standard.minimumValue, TrialStandards.SevenSeals.spiritCarryMeters)
        XCTAssertEqual(home[6].loadPercentOfBodyweight, TrialStandards.SevenSeals.spiritCarryLoadPercentLoaded)

        let noGym = gate.stations(for: .noGymField)
        let noGymPower = try XCTUnwrap(noGym.first { $0.id == "seals-power" })
        XCTAssertEqual(noGymPower.standard.movementId, "exercise.single-leg-rdl")
        XCTAssertEqual(noGymPower.loadPercentOfBodyweight, 0.25)
        XCTAssertNil(noGymPower.strengthTier)
        XCTAssertEqual(noGym.first { $0.id == "seals-spirit" }?.loadPercentOfBodyweight, TrialStandards.SevenSeals.spiritCarryLoadPercentNoGym)
    }

    func testGate6PowerSealLoadedMovementsResolveVesselStrengthRatios() throws {
        let gate = OverallRankTrialDefinitions.sevenSeals

        for loadout in [TrialLoadout.homeKit, .gymHybrid] {
            let power = try XCTUnwrap(gate.stations(for: loadout).first { $0.id == "seals-power" }, loadout.displayName)
            XCTAssertEqual(power.strengthTier, .vessel, loadout.displayName)

            for option in power.movementOptions {
                let movementKey = MovementCatalog.definition(for: option.movementId)?.canonicalExerciseName ?? option.movementId
                let ratio = StrengthStandards.ratio(exerciseKey: movementKey, tier: .vessel, sex: nil)
                XCTAssertNotNil(ratio, "\(loadout.displayName) \(option.movementId) must resolve a Vessel strength ratio")
            }

            XCTAssertNotNil(
                power.resolvedStrikeLoadKg(bodyweightKg: 80),
                "\(loadout.displayName) seals-power must resolve a strike load"
            )
        }
    }

    func testGate7TheThresholdStations() throws {
        let gate = OverallRankTrialDefinitions.theThreshold
        XCTAssertEqual(gate.id, "gate-07-the-threshold")
        XCTAssertEqual(gate.format, .theThreshold)
        XCTAssertEqual(gate.displayName, "The Threshold")
        XCTAssertEqual(gate.targetRank, .ascendant)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-unbound-threshold"))

        let expectedIds = [
            "threshold-approach", "threshold-breach-hinge", "threshold-breach-upper",
            "threshold-breach-carry", "threshold-hold-the-light"
        ]

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 5, loadout.displayName)
            XCTAssertEqual(stations.map(\.id), expectedIds, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)

            // Engine floor: run-based loadouts use the raw meters; gymHybrid converts
            // run→row at ×1.15 inside engineMovement, so assert the raw value only for
            // the run loadouts and a >= sanity floor for the rower (no magic number here).
            if loadout == .gymHybrid {
                XCTAssertGreaterThanOrEqual(stations[0].standard.minimumValue, TrialStandards.TheThreshold.approachEngineMeters, loadout.displayName)
            } else {
                XCTAssertEqual(stations[0].standard.minimumValue, TrialStandards.TheThreshold.approachEngineMeters, loadout.displayName)
            }
            XCTAssertEqual(stations[0].standard.minimumQualifyingSets, TrialStandards.TheThreshold.approachSets, loadout.displayName)
            XCTAssertEqual(stations[0].capSeconds, TrialStandards.TheThreshold.approachCapSeconds, loadout.displayName)
            XCTAssertEqual(stations[1].standard.minimumValue, TrialStandards.TheThreshold.breachReps, loadout.displayName)
            XCTAssertEqual(stations[1].standard.minimumQualifyingSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[1].standard.plannedSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[1].capSeconds, TrialStandards.TheThreshold.breachCapSeconds, loadout.displayName)
            XCTAssertEqual(stations[2].standard.movementId, "exercise.pullup", loadout.displayName)
            XCTAssertEqual(stations[2].standard.minimumValue, TrialStandards.TheThreshold.breachReps, loadout.displayName)
            XCTAssertEqual(stations[2].standard.minimumQualifyingSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[2].standard.plannedSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[2].capSeconds, TrialStandards.TheThreshold.breachCapSeconds, loadout.displayName)
            XCTAssertEqual(stations[3].standard.minimumValue, TrialStandards.TheThreshold.breachCarryMeters, loadout.displayName)
            XCTAssertEqual(stations[3].standard.minimumQualifyingSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[3].standard.plannedSets, TrialStandards.TheThreshold.breachSets, loadout.displayName)
            XCTAssertEqual(stations[3].capSeconds, TrialStandards.TheThreshold.breachCapSeconds, loadout.displayName)
            XCTAssertEqual(stations[4].standard.movementId, "exercise.plank", loadout.displayName)
            XCTAssertEqual(stations[4].standard.minimumValue, TrialStandards.TheThreshold.holdTheLightSeconds, loadout.displayName)
            XCTAssertEqual(stations[4].standard.minimumQualifyingSets, TrialStandards.TheThreshold.holdSets, loadout.displayName)
            XCTAssertEqual(stations[4].standard.plannedSets, TrialStandards.TheThreshold.holdSets, loadout.displayName)
            XCTAssertEqual(stations[4].capSeconds, TrialStandards.TheThreshold.holdCapSeconds, loadout.displayName)
        }

        let homeUpper = try XCTUnwrap(gate.stations(for: .homeKit).first { $0.id == "threshold-breach-upper" })
        XCTAssertEqual(homeUpper.resolvedMinimum(forMovementId: "exercise.pullup"), TrialStandards.TheThreshold.breachReps)
        XCTAssertEqual(homeUpper.resolvedMinimum(forMovementId: "exercise.dumbbell-row"), 15)
        XCTAssertEqual(homeUpper.resolvedMinimum(forMovementId: "exercise.band-row"), 15)

        let noGymUpper = try XCTUnwrap(gate.stations(for: .noGymField).first { $0.id == "threshold-breach-upper" })
        XCTAssertEqual(noGymUpper.resolvedMinimum(forMovementId: "exercise.inverted-row"), 15)
        XCTAssertFalse(noGymUpper.movementOptions.contains { $0.movementId == "exercise.pullup" })
        XCTAssertEqual(noGymUpper.movementOptions.first?.floorOverride, 15)

        let homeCarry = try XCTUnwrap(gate.stations(for: .homeKit).first { $0.id == "threshold-breach-carry" })
        let noGymCarry = try XCTUnwrap(gate.stations(for: .noGymField).first { $0.id == "threshold-breach-carry" })
        XCTAssertEqual(homeCarry.loadPercentOfBodyweight, TrialStandards.TheThreshold.carryLoadPercentLoaded)
        XCTAssertEqual(noGymCarry.loadPercentOfBodyweight, TrialStandards.TheThreshold.carryLoadPercentNoGym)
    }

    func testGate8TheLastGateStations() throws {
        let gate = OverallRankTrialDefinitions.theLastGate
        XCTAssertEqual(gate.id, "gate-08-the-last-gate")
        XCTAssertEqual(gate.format, .theLastGate)
        XCTAssertEqual(gate.displayName, "The Last Gate")
        XCTAssertEqual(gate.targetRank, .unbound)
        XCTAssertTrue(gate.legacyIds.contains("overall-rank-trial-ascendant-ascension"))

        let expectedIds = [
            "lastgate-landing-1-path",
            "lastgate-landing-1-posts",
            "lastgate-landing-1-banner",
            "lastgate-landing-1-steps",
            "lastgate-landing-1-door",
            "lastgate-landing-2-count",
            "lastgate-landing-3-strike"
        ]
            + (1...13).map { String(format: "lastgate-landing-4-card-%02d", $0) }
            + [
                "lastgate-landing-5-engine",
                "lastgate-landing-5-hold",
                "lastgate-landing-6-power",
                "lastgate-landing-6-vitality",
                "lastgate-landing-6-control",
                "lastgate-landing-6-endurance",
                "lastgate-landing-6-mobility",
                "lastgate-landing-6-explosiveness",
                "lastgate-landing-7-carry",
                "lastgate-summit"
            ]

        for loadout in TrialLoadout.allCases {
            let stations = gate.stations(for: loadout)
            XCTAssertEqual(stations.count, 30, loadout.displayName)
            XCTAssertEqual(stations.map(\.id), expectedIds, loadout.displayName)
            XCTAssertTrue(stations.allSatisfy { !$0.movementOptions.isEmpty }, loadout.displayName)
            XCTAssertTrue(stations.prefix(5).allSatisfy { $0.capSeconds == TrialStandards.TheLastGate.landing1CapSeconds }, loadout.displayName)
            XCTAssertEqual(stations.last?.id, "lastgate-summit", loadout.displayName)
        }

        let home = gate.stations(for: .homeKit)
        XCTAssertEqual(home[0].standard.minimumValue, TrialStandards.TheLastGate.landing1LowerReps)
        XCTAssertEqual(home[1].standard.minimumValue, TrialStandards.TheLastGate.landing1PushReps)
        XCTAssertEqual(home[2].standard.minimumValue, TrialStandards.TheLastGate.landing1PullReps)
        XCTAssertEqual(home[3].standard.minimumValue, TrialStandards.TheLastGate.landing1StepReps)
        XCTAssertEqual(home[4].standard.minimumValue, TrialStandards.TheLastGate.landing1HoldSeconds)
        XCTAssertEqual(home[5].standard.minimumValue, TrialStandards.TheLastGate.landing2EngineMeters)
        XCTAssertEqual(home[5].capSeconds, TrialStandards.TheLastGate.landing2WindowSeconds)
        XCTAssertEqual(home[6].category, .hingePower)
        XCTAssertEqual(home[6].standard.minimumValue, TrialStandards.TheLastGate.landing3StrikeReps)
        XCTAssertEqual(home[6].standard.plannedSets, 3)
        XCTAssertEqual(home[6].strengthTier, .unbound)

        let noGymStrike = try XCTUnwrap(gate.stations(for: .noGymField).first { $0.id == "lastgate-landing-3-strike" })
        XCTAssertEqual(noGymStrike.standard.movementId, "exercise.single-leg-rdl")
        XCTAssertEqual(noGymStrike.loadPercentOfBodyweight, 0.30)
        XCTAssertNil(noGymStrike.strengthTier)

        let cards = Array(home[7..<20])
        XCTAssertEqual(cards.map(\.title), [
            "Landing 4 - Card AH Pushups",
            "Landing 4 - Card 2D Squats",
            "Landing 4 - Card 3C Pullups",
            "Landing 4 - Card 4S Sit-Ups",
            "Landing 4 - Card 5H Pushups",
            "Landing 4 - Card 6D Squats",
            "Landing 4 - Card 7C Pullups",
            "Landing 4 - Card 8S Sit-Ups",
            "Landing 4 - Card 9H Pushups",
            "Landing 4 - Card 10D Squats",
            "Landing 4 - Card JC Pullups",
            "Landing 4 - Card QS Sit-Ups",
            "Landing 4 - Card KH Pushups"
        ])
        XCTAssertEqual(cards.map(\.category), [
            .push, .lower, .pull, .carryCore,
            .push, .lower, .pull, .carryCore,
            .push, .lower, .pull, .carryCore,
            .push
        ])
        XCTAssertEqual(cards[0].standard.minimumValue, TrialStandards.DeckOfProof.aceReps)
        XCTAssertEqual(cards[10].standard.minimumValue, TrialStandards.DeckOfProof.faceCardReps)
        XCTAssertEqual(cards[10].capSeconds, TrialStandards.TheLastGate.landing4CapSeconds)
        XCTAssertEqual(cards[10].resolvedMinimum(forMovementId: "exercise.pullup"), TrialStandards.DeckOfProof.faceCardReps)
        XCTAssertEqual(cards[10].resolvedMinimum(forMovementId: "exercise.inverted-row"), 15)
        XCTAssertEqual(cards[10].resolvedMinimum(forMovementId: "exercise.dumbbell-row"), 15)

        XCTAssertEqual(home[20].standard.minimumValue, TrialStandards.TheLastGate.landing5EngineMeters)
        XCTAssertEqual(home[21].standard.movementId, "exercise.plank")
        XCTAssertEqual(home[21].standard.minimumValue, TrialStandards.TheLastGate.landing5HoldSeconds)

        XCTAssertEqual(home[22].standard.minimumValue, TrialStandards.SevenSeals.powerStrikeReps)
        XCTAssertEqual(home[22].strengthTier, .unbound)
        XCTAssertEqual(home[23].standard.minimumValue, TrialStandards.SevenSeals.vitalityLowerReps)
        XCTAssertEqual(home[24].standard.minimumValue, TrialStandards.SevenSeals.controlHoldSeconds)
        XCTAssertEqual(home[24].standard.minimumQualifyingSets, TrialStandards.SevenSeals.controlSets)
        XCTAssertEqual(home[24].standard.plannedSets, TrialStandards.SevenSeals.controlSets)
        XCTAssertEqual(home[25].standard.minimumValue, TrialStandards.SevenSeals.enduranceEngineMeters)
        XCTAssertEqual(home[26].standard.movementId, "mobility.deep-squat-hold")
        XCTAssertEqual(home[26].standard.minimumValue, TrialStandards.SevenSeals.mobilityDeepSquatHoldSeconds)
        XCTAssertEqual(home[27].standard.minimumValue, TrialStandards.SevenSeals.explosivenessReps)
        XCTAssertEqual(home[28].standard.minimumValue, TrialStandards.TheLastGate.landing7CarryMeters)
        XCTAssertEqual(home[28].loadPercentOfBodyweight, TrialStandards.TheLastGate.landing7CarryLoadPercentLoaded)
        XCTAssertEqual(home[29].standard.movementId, "exercise.plank")
        XCTAssertEqual(home[29].standard.minimumValue, TrialStandards.TheLastGate.summitHoldSeconds)
        XCTAssertEqual(home[29].capSeconds, TrialStandards.TheLastGate.summitCapSeconds)

        let noGymCarry = try XCTUnwrap(gate.stations(for: .noGymField).first { $0.id == "lastgate-landing-7-carry" })
        XCTAssertEqual(noGymCarry.loadPercentOfBodyweight, TrialStandards.TheLastGate.landing7CarryLoadPercentNoGym)
    }

    func testGate8TheLastGateLoadedStrikeMovementsResolveUnboundStrengthRatios() throws {
        let gate = OverallRankTrialDefinitions.theLastGate

        for loadout in [TrialLoadout.homeKit, .gymHybrid] {
            for stationId in ["lastgate-landing-3-strike", "lastgate-landing-6-power"] {
                let strike = try XCTUnwrap(gate.stations(for: loadout).first { $0.id == stationId }, "\(loadout.displayName) \(stationId)")
                XCTAssertEqual(strike.strengthTier, .unbound, "\(loadout.displayName) \(stationId)")

                for option in strike.movementOptions {
                    let movementKey = MovementCatalog.definition(for: option.movementId)?.canonicalExerciseName ?? option.movementId
                    let ratio = StrengthStandards.ratio(exerciseKey: movementKey, tier: .unbound, sex: nil)
                    XCTAssertNotNil(ratio, "\(loadout.displayName) \(stationId) \(option.movementId) must resolve an Unbound strength ratio")
                }

                XCTAssertNotNil(
                    strike.resolvedStrikeLoadKg(bodyweightKg: 80),
                    "\(loadout.displayName) \(stationId) must resolve a strike load"
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
