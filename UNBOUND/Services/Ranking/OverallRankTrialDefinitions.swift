import Foundation

enum OverallRankTrialDefinitions {
    private static func option(
        _ movementId: String,
        _ displayName: String? = nil,
        requiredEquipment: Set<MovementEquipment>? = nil,
        floorOverride: Int? = nil
    ) -> TrialMovementOption {
        let normalizedRequirement: Set<MovementEquipment>?
        if let requiredEquipment {
            normalizedRequirement = requiredEquipment
        } else {
            switch movementId {
            case "exercise.step-up":
                normalizedRequirement = [.openSpace]
            case "exercise.incline-pushup":
                normalizedRequirement = [.bodyweight]
            default:
                normalizedRequirement = nil
            }
        }

        return TrialMovementOption(
            movementId: movementId,
            displayName: displayName,
            requiredEquipment: normalizedRequirement,
            floorOverride: floorOverride
        )
    }

    private static func performanceStandard(
        _ movementId: String,
        metric: TrainingMetricKind,
        minimumValue: Int,
        minimumQualifyingSets: Int = 1,
        plannedSets: Int? = nil,
        restSeconds: Int? = nil,
        displayName: String? = nil
    ) -> OverallRankTrialPerformanceStandard {
        OverallRankTrialPerformanceStandard(
            movementId: movementId,
            displayName: displayName ?? MovementCatalog.definition(for: movementId)?.displayName ?? movementId,
            metric: metric,
            minimumValue: minimumValue,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: plannedSets,
            restSeconds: restSeconds
        )
    }

    private static func station(
        _ id: String,
        title: String,
        category: TrialMovementCategory,
        movementId: String,
        displayName: String? = nil,
        metric: TrainingMetricKind,
        minimumValue: Int,
        minimumQualifyingSets: Int = 1,
        plannedSets: Int? = nil,
        restSeconds: Int? = nil,
        capSeconds: Int? = nil,
        loadPercentOfBodyweight: Double? = nil,
        strengthTier: RankTier? = nil,
        dynamicGroupKey: String? = nil,
        isScored: Bool = true,
        movementOptions: [TrialMovementOption]? = nil,
        restRule: String? = nil
    ) -> TrialStation {
        let standard = performanceStandard(
            movementId,
            metric: metric,
            minimumValue: minimumValue,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: plannedSets,
            restSeconds: restSeconds,
            displayName: displayName
        )
        return TrialStation(
            id: id,
            title: title,
            category: category,
            standard: standard,
            capSeconds: capSeconds,
            loadPercentOfBodyweight: loadPercentOfBodyweight,
            strengthTier: strengthTier,
            dynamicGroupKey: dynamicGroupKey,
            isScored: isScored,
            movementOptions: movementOptions ?? [option(movementId, displayName)],
            restRule: restRule ?? "Clean reps only. Pain or form-break flags fail the station.",
            qualityFlags: [.clean]
        )
    }

    private static func variant(
        _ loadout: TrialLoadout,
        promise: String,
        stations: [TrialStation]
    ) -> TrialLoadoutVariant {
        TrialLoadoutVariant(
            loadout: loadout,
            requiredEquipment: [.bodyweight, .openSpace],
            promise: promise,
            stations: stations
        )
    }

    private static func definition(
        id: String,
        targetRank: RankTitle,
        displayName: String,
        subtitle: String,
        estimatedMinutes: Int,
        format: RankTrialFormat,
        minOverallLevel: Int,
        loadoutVariants: [TrialLoadoutVariant],
        legacyIds: Set<String> = [],
        enforcesTotalTimeCap: Bool = true
    ) -> OverallRankTrialDefinition {
        let defaultVariant = loadoutVariants.first { $0.loadout == .homeKit } ?? loadoutVariants[0]
        return OverallRankTrialDefinition(
            id: id,
            targetRank: targetRank,
            displayName: displayName,
            subtitle: subtitle,
            estimatedMinutes: estimatedMinutes,
            format: format,
            minOverallLevel: minOverallLevel,
            requiredEquipment: defaultVariant.requiredEquipment,
            performanceStandards: defaultVariant.stations.map(\.standard),
            loadoutVariants: loadoutVariants,
            legacyIds: legacyIds,
            enforcesTotalTimeCap: enforcesTotalTimeCap
        )
    }

    private static func loadoutVariants(
        noGym: [TrialStation],
        home: [TrialStation],
        gym: [TrialStation]
    ) -> [TrialLoadoutVariant] {
        [
            variant(
                .noGymField,
                promise: "Apartment and travel-safe station set with no commercial gym requirement.",
                stations: noGym
            ),
            variant(
                .homeKit,
                promise: "Home equipment version with stronger row, hinge, and carry options.",
                stations: home
            ),
            variant(
                .gymHybrid,
                promise: "Gym version with premium variety, never a mandatory sled or box-jump gate.",
                stations: gym
            )
        ]
    }

    private static func engineMovement(
        loadout: TrialLoadout,
        runMeters: Int
    ) -> (id: String, displayName: String, value: Int, equipment: Set<MovementEquipment>) {
        switch loadout {
        case .noGymField, .homeKit:
            return ("cardio.run", "\(runMeters)m run/walk", runMeters, [.openSpace])
        case .gymHybrid:
            return ("cardio.row", "\(Int(Double(runMeters) * 1.15))m row", Int(Double(runMeters) * 1.15), [.cardioMachine])
        }
    }

    private static func engineStation(
        _ id: String,
        title: String,
        loadout: TrialLoadout,
        runMeters: Int,
        minimumQualifyingSets: Int = 1,
        capSeconds: Int? = nil,
        dynamicGroupKey: String? = nil,
        isScored: Bool = true
    ) -> TrialStation {
        let movement = engineMovement(loadout: loadout, runMeters: runMeters)
        return station(
            id,
            title: title,
            category: .engine,
            movementId: movement.id,
            displayName: movement.displayName,
            metric: .distanceMeters,
            minimumValue: movement.value,
            minimumQualifyingSets: minimumQualifyingSets,
            plannedSets: minimumQualifyingSets,
            restSeconds: 45,
            capSeconds: capSeconds,
            dynamicGroupKey: dynamicGroupKey,
            isScored: isScored,
            movementOptions: [option(movement.id, movement.displayName, requiredEquipment: movement.equipment)]
        )
    }

    private static func movementSet(
        loadout: TrialLoadout,
        noGym: TrialMovementOption,
        home: [TrialMovementOption],
        gym: [TrialMovementOption]
    ) -> [TrialMovementOption] {
        switch loadout {
        case .noGymField: return [noGym]
        case .homeKit: return home
        case .gymHybrid: return gym
        }
    }

    private struct DeckRankSpec {
        let code: String
        let reps: Int
    }

    private struct DeckSuitSpec {
        let code: String
        let title: String
        let category: TrialMovementCategory
        let movementId: String
        let displayName: String
        let movementOptions: [TrialMovementOption]
    }

    private static let deckRanks: [DeckRankSpec] = [
        DeckRankSpec(code: "A", reps: TrialStandards.DeckOfProof.aceReps),
        DeckRankSpec(code: "2", reps: 2),
        DeckRankSpec(code: "3", reps: 3),
        DeckRankSpec(code: "4", reps: 4),
        DeckRankSpec(code: "5", reps: 5),
        DeckRankSpec(code: "6", reps: 6),
        DeckRankSpec(code: "7", reps: 7),
        DeckRankSpec(code: "8", reps: 8),
        DeckRankSpec(code: "9", reps: 9),
        DeckRankSpec(code: "10", reps: 10),
        DeckRankSpec(code: "J", reps: TrialStandards.DeckOfProof.faceCardReps),
        DeckRankSpec(code: "Q", reps: TrialStandards.DeckOfProof.faceCardReps),
        DeckRankSpec(code: "K", reps: TrialStandards.DeckOfProof.faceCardReps)
    ]

    private static func firstLightStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            station("firstlight-path", title: "The Path Lantern", category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.bodyweight-squat",
                metric: .reps, minimumValue: TrialStandards.FirstLight.lowerReps,
                capSeconds: TrialStandards.FirstLight.stationCapSeconds,
                movementOptions: movementSet(loadout: loadout,
                    noGym: option("exercise.bodyweight-squat"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.bodyweight-squat")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])])),
            station("firstlight-posts", title: "The Post Lantern", category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.pushup" : "exercise.incline-pushup",
                metric: .reps, minimumValue: TrialStandards.FirstLight.pushReps,
                capSeconds: TrialStandards.FirstLight.stationCapSeconds,
                movementOptions: movementSet(loadout: loadout,
                    noGym: option("exercise.incline-pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")])),
            station("firstlight-banner", title: "The Banner Lantern", category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps, minimumValue: TrialStandards.FirstLight.pullReps,
                capSeconds: TrialStandards.FirstLight.stationCapSeconds,
                movementOptions: movementSet(loadout: loadout,
                    noGym: option("exercise.inverted-row"),
                    home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band]), option("exercise.inverted-row")],
                    gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("firstlight-steps", title: "The Steps Lantern", category: .engine,
                movementId: "exercise.step-up", metric: .reps,
                minimumValue: TrialStandards.FirstLight.stepReps,
                capSeconds: TrialStandards.FirstLight.stepWindowSeconds,
                movementOptions: [option("exercise.step-up")]),
            station("firstlight-door", title: "The Door Light", category: .carryCore,
                movementId: "exercise.plank", metric: .holdSeconds,
                minimumValue: TrialStandards.FirstLight.trunkHoldSeconds,
                capSeconds: TrialStandards.FirstLight.stationCapSeconds,
                movementOptions: [option("exercise.plank")])
        ]
    }

    private static func theCountStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation(
                "count-long-bell",
                title: "The Long Bell",
                loadout: loadout,
                runMeters: TrialStandards.TheCount.engineMeters,
                capSeconds: TrialStandards.TheCount.engineCapSeconds
            ),
            station(
                "count-second",
                title: "The Second Count",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.TheCount.lowerReps,
                capSeconds: TrialStandards.TheCount.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.step-up")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.step-up")]
                )
            ),
            station(
                "count-third",
                title: "The Third Count",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                metric: .reps,
                minimumValue: TrialStandards.TheCount.pushReps,
                capSeconds: TrialStandards.TheCount.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                )
            ),
            station(
                "count-fourth",
                title: "The Fourth Count",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: TrialStandards.TheCount.pullReps,
                capSeconds: TrialStandards.TheCount.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.inverted-row"),
                    home: [
                        option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]),
                        option("exercise.band-row", requiredEquipment: [.band]),
                        option("exercise.pullup", requiredEquipment: [.pullupBar])
                    ],
                    gym: [
                        option("exercise.cable-row-seated", requiredEquipment: [.cable]),
                        option("exercise.machine-row", requiredEquipment: [.machine]),
                        option("exercise.assisted-pullup-machine", requiredEquipment: [.machine])
                    ]
                )
            ),
            station(
                "count-water-carry",
                title: "The Water Carry",
                category: .carryCore,
                movementId: loadout == .gymHybrid ? "carry.farmer-carry" : loadout == .homeKit ? "carry.suitcase-carry" : "carry.loaded-march",
                metric: .distanceMeters,
                minimumValue: TrialStandards.TheCount.carryMeters,
                capSeconds: TrialStandards.TheCount.carryCapSeconds,
                loadPercentOfBodyweight: TrialStandards.TheCount.carryLoadPercent,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                    home: [
                        option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            ),
            station(
                "count-stillness",
                title: "Stillness",
                category: .mobilityControl,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.TheCount.stillnessHoldSeconds,
                capSeconds: TrialStandards.TheCount.stationCapSeconds,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func theForgingStations(loadout: TrialLoadout) -> [TrialStation] {
        let loadedHingeOptions = [
            option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]),
            option("exercise.romanian-deadlift", requiredEquipment: [.barbell])
        ]
        let loadedPushOptions = loadout == .gymHybrid
            ? [
                option("exercise.machine-chest-press", requiredEquipment: [.machine]),
                option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
            ]
            : [option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])]
        let pullupOption = option("exercise.pullup", "Pull-Up", requiredEquipment: [.pullupBar])
        let rowFallback = option("exercise.inverted-row", "Inverted Row", floorOverride: 5)

        return [
            engineStation(
                "forging-stoke",
                title: "Stoke the Fire",
                loadout: loadout,
                runMeters: TrialStandards.TheForging.stokeEngineMeters,
                isScored: false
            ),
            station(
                "forging-strike-hinge",
                title: "The Strikes - Hinge",
                category: .hingePower,
                movementId: loadout == .noGymField ? "exercise.single-leg-rdl" : "exercise.dumbbell-romanian-deadlift",
                metric: .reps,
                minimumValue: TrialStandards.TheForging.scoredStrikeReps,
                minimumQualifyingSets: 1,
                plannedSets: 3,
                loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.TheForging.noGymHingeLoadPercent : nil,
                strengthTier: loadout == .noGymField ? nil : .forged,
                movementOptions: loadout == .noGymField
                    ? [option("exercise.single-leg-rdl", "Backpack Single-Leg RDL", requiredEquipment: [.bodyweight, .openSpace])]
                    : loadedHingeOptions
            ),
            station(
                "forging-strike-push",
                title: "The Strikes - Push",
                category: .push,
                movementId: loadout == .noGymField ? "exercise.pushup" : loadedPushOptions[0].movementId,
                metric: .reps,
                minimumValue: TrialStandards.TheForging.scoredStrikeReps,
                minimumQualifyingSets: 1,
                plannedSets: 3,
                strengthTier: loadout == .noGymField ? nil : .forged,
                movementOptions: loadout == .noGymField
                    ? [option("exercise.pushup", "Tempo Push-Up", floorOverride: 3)]
                    : loadedPushOptions
            ),
            station(
                "forging-strike-pull",
                title: "The Strikes - Pull",
                category: .pull,
                movementId: loadout == .noGymField ? "exercise.inverted-row" : "exercise.pullup",
                metric: .reps,
                minimumValue: TrialStandards.TheForging.scoredPullReps,
                minimumQualifyingSets: 1,
                plannedSets: 3,
                movementOptions: loadout == .noGymField
                    ? [option("exercise.inverted-row", "Elevated Inverted Row", floorOverride: 5)]
                    : [pullupOption, rowFallback]
            ),
            station(
                "forging-quench",
                title: "The Quench",
                category: .carryCore,
                movementId: loadout == .gymHybrid ? "carry.farmer-carry" : loadout == .homeKit ? "carry.suitcase-carry" : "carry.loaded-march",
                metric: .distanceMeters,
                minimumValue: TrialStandards.TheForging.quenchCarryMeters,
                loadPercentOfBodyweight: loadout == .noGymField ? 0.25 : 0.30,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                    home: [
                        option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            )
        ]
    }

    private static func deckStations(loadout: TrialLoadout) -> [TrialStation] {
        let suits = deckSuitSpecs(loadout: loadout)

        return suits.enumerated().flatMap { suitIndex, suit in
            deckRanks.enumerated().map { rankIndex, rank in
                let cardNumber = String(format: "%02d", suitIndex * deckRanks.count + rankIndex + 1)
                let cardCode = "\(rank.code)\(suit.code)"
                return station(
                    "deck-card-\(cardNumber)",
                    title: "Card \(cardCode) \(suit.title)",
                    category: suit.category,
                    movementId: suit.movementId,
                    displayName: suit.displayName,
                    metric: .reps,
                    minimumValue: rank.reps,
                    restSeconds: TrialStandards.DeckOfProof.restSeconds,
                    movementOptions: deckMovementOptions(for: suit, cardValue: rank.reps),
                    restRule: "Short rest, then flip the next card."
                )
            }
        }
    }

    private static func deckMovementOptions(for suit: DeckSuitSpec, cardValue: Int) -> [TrialMovementOption] {
        guard suit.category == .pull else { return suit.movementOptions }
        let rowFloor = Int(ceil(Double(cardValue) * TrialStandards.DeckOfProof.rowConversionMultiplier))
        let rowMovementIds: Set<String> = [
            "exercise.inverted-row",
            "exercise.dumbbell-row",
            "exercise.band-row",
            "exercise.cable-row-seated",
            "exercise.machine-row"
        ]

        return suit.movementOptions.map { movementOption in
            guard rowMovementIds.contains(movementOption.movementId) else {
                return movementOption
            }
            return TrialMovementOption(
                movementId: movementOption.movementId,
                displayName: movementOption.displayName,
                requiredEquipment: movementOption.requiredEquipment,
                floorOverride: rowFloor
            )
        }
    }

    private static func deckSuitSpecs(loadout: TrialLoadout) -> [DeckSuitSpec] {
        let pullup = option("exercise.pullup", "Pull-Up", requiredEquipment: [.pullupBar])
        let rowFallback = option("exercise.inverted-row", "Inverted Row")
        let situp = option("exercise.decline-situp", "Sit-Up", requiredEquipment: [.bodyweight])

        let pullOptions: [TrialMovementOption]
        switch loadout {
        case .noGymField:
            pullOptions = [pullup, rowFallback]
        case .homeKit:
            pullOptions = [
                pullup,
                rowFallback,
                option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]),
                option("exercise.band-row", requiredEquipment: [.band])
            ]
        case .gymHybrid:
            pullOptions = [
                pullup,
                option("exercise.cable-row-seated", requiredEquipment: [.cable]),
                option("exercise.machine-row", requiredEquipment: [.machine]),
                rowFallback
            ]
        }

        return [
            DeckSuitSpec(
                code: "H",
                title: "Pushups",
                category: .push,
                movementId: "exercise.pushup",
                displayName: "Push-Up",
                movementOptions: [option("exercise.pushup", "Push-Up")]
            ),
            DeckSuitSpec(
                code: "D",
                title: "Squats",
                category: .lower,
                movementId: "exercise.bodyweight-squat",
                displayName: "Bodyweight Squat",
                movementOptions: [option("exercise.bodyweight-squat")]
            ),
            DeckSuitSpec(
                code: "C",
                title: "Pullups",
                category: .pull,
                movementId: "exercise.pullup",
                displayName: "Pull-Up",
                movementOptions: pullOptions
            ),
            DeckSuitSpec(
                code: "S",
                title: "Sit-Ups",
                category: .carryCore,
                movementId: "exercise.decline-situp",
                displayName: "Sit-Up",
                movementOptions: [situp]
            )
        ]
    }

    private static func theAscentPullOptions(loadout: TrialLoadout, rowFloor: Int) -> [TrialMovementOption] {
        let pullup = option("exercise.pullup", "Pull-Up", requiredEquipment: [.pullupBar])
        let invertedRow = option("exercise.inverted-row", "Inverted Row", floorOverride: rowFloor)

        switch loadout {
        case .noGymField:
            return [pullup, invertedRow]
        case .homeKit:
            return [
                pullup,
                invertedRow,
                option("exercise.dumbbell-row", requiredEquipment: [.dumbbell], floorOverride: rowFloor),
                option("exercise.band-row", requiredEquipment: [.band], floorOverride: rowFloor)
            ]
        case .gymHybrid:
            return [
                pullup,
                option("exercise.cable-row-seated", requiredEquipment: [.cable], floorOverride: rowFloor),
                option("exercise.machine-row", requiredEquipment: [.machine], floorOverride: rowFloor),
                invertedRow
            ]
        }
    }

    private static func theAscentStations(loadout: TrialLoadout) -> [TrialStation] {
        let carryLoadPercent = loadout == .noGymField
            ? TrialStandards.TheAscent.carryLoadPercentNoGym
            : TrialStandards.TheAscent.carryLoadPercentLoaded

        return [
            engineStation(
                "ascent-floor-01",
                title: "Floor 1 — The Path",
                loadout: loadout,
                runMeters: TrialStandards.TheAscent.floor1Meters
            ),
            station(
                "ascent-floor-02",
                title: "Floor 2 — The Work Floors",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.lowerReps,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]),
                        option("exercise.goblet-squat", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.leg-press", requiredEquipment: [.machine]),
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "ascent-floor-03",
                title: "Floor 3 — The Work Floors",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.dumbbell-bench-press" : "exercise.pushup",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.pushReps,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.pushup"),
                    home: [
                        option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell]),
                        option("exercise.pushup")
                    ],
                    gym: [
                        option("exercise.machine-chest-press", requiredEquipment: [.machine]),
                        option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "ascent-floor-04",
                title: "Floor 4 — The Work Floors",
                category: .pull,
                movementId: "exercise.pullup",
                displayName: "Pull-Up",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.pullUpReps,
                movementOptions: theAscentPullOptions(
                    loadout: loadout,
                    rowFloor: TrialStandards.TheAscent.rowFallbackReps
                )
            ),
            station(
                "ascent-floor-05",
                title: "Floor 5 — The Work Floors",
                category: .hingePower,
                movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.hingeReps,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.glute-bridge"),
                    home: [
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]),
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])
                    ],
                    gym: [
                        option("exercise.cable-pull-through", requiredEquipment: [.cable]),
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "ascent-floor-06",
                title: "Floor 6 — The Work Floors",
                category: .carryCore,
                movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: TrialStandards.TheAscent.carryMeters,
                loadPercentOfBodyweight: carryLoadPercent,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                    home: [
                        option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            ),
            engineStation(
                "ascent-floor-07",
                title: "Floor 7 — The Cloudline",
                loadout: loadout,
                runMeters: TrialStandards.TheAscent.longEngineMeters
            ),
            station(
                "ascent-floor-08",
                title: "Floor 8 — Thin Air",
                category: .explosive,
                movementId: loadout == .gymHybrid ? "exercise.kettlebell-swing" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.explosiveReps,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]),
                        option("exercise.step-up")
                    ],
                    gym: [
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]),
                        option("exercise.step-up")
                    ]
                )
            ),
            station(
                "ascent-floor-09-push",
                title: "Floor 9 — Thin Air",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.blendPushReps,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.pushup"),
                    home: [
                        option("exercise.pushup"),
                        option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.machine-chest-press", requiredEquipment: [.machine]),
                        option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "ascent-floor-09-pull",
                title: "Floor 9 — Thin Air",
                category: .pull,
                movementId: "exercise.pullup",
                displayName: "Pull-Up",
                metric: .reps,
                minimumValue: TrialStandards.TheAscent.blendPullUpReps,
                movementOptions: theAscentPullOptions(
                    loadout: loadout,
                    rowFloor: TrialStandards.TheAscent.blendRowFallbackReps
                )
            ),
            station(
                "ascent-floor-10",
                title: "Floor 10 — The Summit Gate",
                category: .carryCore,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.TheAscent.bossHoldSeconds,
                capSeconds: TrialStandards.TheAscent.bossHoldCapSeconds,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func sevenSealsStations(loadout: TrialLoadout) -> [TrialStation] {
        let homePowerOptions = [
            option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
        ]
        let gymPowerOptions = [
            option("exercise.romanian-deadlift", requiredEquipment: [.barbell]),
            option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
        ]
        let homePressOptions = [
            option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
        ]
        let gymPressOptions = [
            option("exercise.machine-chest-press", requiredEquipment: [.machine]),
            option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
        ]

        return [
            engineStation(
                "seals-endurance",
                title: "Seal I — Endurance",
                loadout: loadout,
                runMeters: TrialStandards.SevenSeals.enduranceEngineMeters,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds
            ),
            station(
                "seals-vitality",
                title: "Seal II — Vitality",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.vitalityLowerReps,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]),
                        option("exercise.goblet-squat", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.leg-press", requiredEquipment: [.machine]),
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "seals-explosiveness",
                title: "Seal III — Explosiveness",
                category: .explosive,
                movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge",
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.explosivenessReps,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.glute-bridge"),
                    home: [
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]),
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.cable-pull-through", requiredEquipment: [.cable]),
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])
                    ]
                )
            ),
            station(
                "seals-power-hinge",
                title: "Seal IV — Power (Hinge)",
                category: .hingePower,
                movementId: loadout == .gymHybrid ? "exercise.romanian-deadlift" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.single-leg-rdl",
                displayName: loadout == .noGymField ? "Backpack Single-Leg RDL" : nil,
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.powerStrikeReps,
                minimumQualifyingSets: 1,
                plannedSets: 3,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                loadPercentOfBodyweight: loadout == .noGymField ? 0.25 : nil,
                strengthTier: loadout == .noGymField ? nil : .vessel,
                movementOptions: loadout == .noGymField
                    ? [option("exercise.single-leg-rdl", "Backpack Single-Leg RDL", requiredEquipment: [.bodyweight, .openSpace])]
                    : loadout == .gymHybrid ? gymPowerOptions : homePowerOptions
            ),
            station(
                "seals-power-press",
                title: "Seal IV — Power (Press)",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.dumbbell-bench-press" : "exercise.pushup",
                displayName: loadout == .noGymField ? "Tempo Push-Up" : nil,
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.powerStrikeReps,
                minimumQualifyingSets: 1,
                plannedSets: 3,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                strengthTier: loadout == .noGymField ? nil : .vessel,
                movementOptions: loadout == .noGymField
                    ? [option("exercise.pushup", "Tempo Push-Up", floorOverride: TrialStandards.SevenSeals.powerStrikeReps)]
                    : loadout == .gymHybrid ? gymPressOptions : homePressOptions
            ),
            station(
                "seals-control",
                title: "Seal V — Control",
                category: .mobilityControl,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.SevenSeals.controlHoldSeconds,
                minimumQualifyingSets: TrialStandards.SevenSeals.controlSets,
                plannedSets: TrialStandards.SevenSeals.controlSets,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                movementOptions: [option("exercise.plank")]
            ),
            station(
                "seals-mobility-hold",
                title: "Seal VI — Mobility (Hold)",
                category: .mobilityControl,
                movementId: "mobility.deep-squat-hold",
                metric: .holdSeconds,
                minimumValue: TrialStandards.SevenSeals.mobilityDeepSquatHoldSeconds,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.SevenSeals.mobilityHoldLoadPercentNoGym : TrialStandards.SevenSeals.mobilityHoldLoadPercentLoaded,
                movementOptions: [option("mobility.deep-squat-hold", "Weighted Deep-Squat Hold", requiredEquipment: [.bodyweight, .openSpace])]
            ),
            station(
                "seals-mobility-cossack",
                title: "Seal VI — Mobility (Flow)",
                category: .mobilityControl,
                movementId: "exercise.cossack-squat",
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.mobilityCossackRepsPerSide,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                movementOptions: [option("exercise.cossack-squat", "Cossack Squat (per side)", requiredEquipment: [.bodyweight, .openSpace])]
            ),
            station(
                "seals-spirit",
                title: "Seal VII — Spirit",
                category: .carryCore,
                movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: TrialStandards.SevenSeals.spiritCarryMeters,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.SevenSeals.spiritCarryLoadPercentNoGym : TrialStandards.SevenSeals.spiritCarryLoadPercentLoaded,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                    home: [
                        option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            )
        ]
    }

    private static func theThresholdPullOptions(loadout: TrialLoadout) -> [TrialMovementOption] {
        let rowFloor = 15
        let pullup = option("exercise.pullup", "Pull-Up", requiredEquipment: [.pullupBar])
        let invertedRow = option("exercise.inverted-row", "Inverted Row", floorOverride: rowFloor)

        switch loadout {
        case .noGymField:
            return [invertedRow]
        case .homeKit:
            return [
                pullup,
                option("exercise.dumbbell-row", requiredEquipment: [.dumbbell], floorOverride: rowFloor),
                option("exercise.band-row", requiredEquipment: [.band], floorOverride: rowFloor)
            ]
        case .gymHybrid:
            return [
                pullup,
                option("exercise.cable-row-seated", requiredEquipment: [.cable], floorOverride: rowFloor),
                option("exercise.machine-row", requiredEquipment: [.machine], floorOverride: rowFloor)
            ]
        }
    }

    private static func theThresholdStations(loadout: TrialLoadout) -> [TrialStation] {
        return [
            engineStation(
                "threshold-approach",
                title: "The Approach",
                loadout: loadout,
                runMeters: TrialStandards.TheThreshold.approachEngineMeters,
                minimumQualifyingSets: TrialStandards.TheThreshold.approachSets,
                capSeconds: TrialStandards.TheThreshold.approachCapSeconds
            ),
            station(
                "threshold-breach-hinge",
                title: "The Breach - Hinge",
                category: .hingePower,
                movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge",
                metric: .reps,
                minimumValue: TrialStandards.TheThreshold.breachReps,
                minimumQualifyingSets: TrialStandards.TheThreshold.breachSets,
                plannedSets: TrialStandards.TheThreshold.breachSets,
                capSeconds: TrialStandards.TheThreshold.breachCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.glute-bridge"),
                    home: [
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]),
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])
                    ],
                    gym: [
                        option("exercise.cable-pull-through", requiredEquipment: [.cable]),
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "threshold-breach-upper",
                title: "The Breach - Upper",
                category: .pull,
                movementId: "exercise.pullup",
                displayName: "Pull-Up",
                metric: .reps,
                minimumValue: TrialStandards.TheThreshold.breachReps,
                minimumQualifyingSets: TrialStandards.TheThreshold.breachSets,
                plannedSets: TrialStandards.TheThreshold.breachSets,
                capSeconds: TrialStandards.TheThreshold.breachCapSeconds,
                movementOptions: theThresholdPullOptions(loadout: loadout)
            ),
            station(
                "threshold-breach-carry",
                title: "The Breach - Carry",
                category: .carryCore,
                movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry",
                metric: .distanceMeters,
                minimumValue: TrialStandards.TheThreshold.breachCarryMeters,
                minimumQualifyingSets: TrialStandards.TheThreshold.breachSets,
                plannedSets: TrialStandards.TheThreshold.breachSets,
                capSeconds: TrialStandards.TheThreshold.breachCapSeconds,
                loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.TheThreshold.carryLoadPercentNoGym : TrialStandards.TheThreshold.carryLoadPercentLoaded,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                    home: [
                        option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            ),
            station(
                "threshold-hold-the-light",
                title: "Hold the Light",
                category: .mobilityControl,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.TheThreshold.holdTheLightSeconds,
                minimumQualifyingSets: TrialStandards.TheThreshold.holdSets,
                plannedSets: TrialStandards.TheThreshold.holdSets,
                capSeconds: TrialStandards.TheThreshold.holdCapSeconds,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func lastGateLanding1Stations(loadout: TrialLoadout) -> [TrialStation] {
        return [
            station(
                "lastgate-landing-1-path",
                title: "Landing 1 - The Path Lantern",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.bodyweight-squat",
                metric: .reps,
                minimumValue: TrialStandards.TheLastGate.landing1LowerReps,
                capSeconds: TrialStandards.TheLastGate.landing1CapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.bodyweight-squat"),
                    home: [
                        option("exercise.goblet-squat", requiredEquipment: [.dumbbell]),
                        option("exercise.bodyweight-squat")
                    ],
                    gym: [
                        option("exercise.leg-press", requiredEquipment: [.machine]),
                        option("exercise.goblet-squat", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "lastgate-landing-1-posts",
                title: "Landing 1 - The Post Lantern",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.pushup" : "exercise.incline-pushup",
                metric: .reps,
                minimumValue: TrialStandards.TheLastGate.landing1PushReps,
                capSeconds: TrialStandards.TheLastGate.landing1CapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.incline-pushup"),
                    home: [
                        option("exercise.pushup"),
                        option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.machine-chest-press", requiredEquipment: [.machine]),
                        option("exercise.pushup")
                    ]
                )
            ),
            station(
                "lastgate-landing-1-banner",
                title: "Landing 1 - The Banner Lantern",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: TrialStandards.TheLastGate.landing1PullReps,
                capSeconds: TrialStandards.TheLastGate.landing1CapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.inverted-row"),
                    home: [
                        option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]),
                        option("exercise.band-row", requiredEquipment: [.band]),
                        option("exercise.inverted-row")
                    ],
                    gym: [
                        option("exercise.cable-row-seated", requiredEquipment: [.cable]),
                        option("exercise.machine-row", requiredEquipment: [.machine])
                    ]
                )
            ),
            station(
                "lastgate-landing-1-steps",
                title: "Landing 1 - The Steps Lantern",
                category: .engine,
                movementId: "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.TheLastGate.landing1StepReps,
                capSeconds: TrialStandards.TheLastGate.landing1CapSeconds,
                movementOptions: [option("exercise.step-up")]
            ),
            station(
                "lastgate-landing-1-door",
                title: "Landing 1 - The Door Light",
                category: .carryCore,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.TheLastGate.landing1HoldSeconds,
                capSeconds: TrialStandards.TheLastGate.landing1CapSeconds,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func lastGatePowerStrikeStation(
        _ id: String,
        title: String,
        loadout: TrialLoadout,
        minimumValue: Int,
        capSeconds: Int? = nil,
        noGymLoadPercent: Double,
        dynamicGroupKey: String? = nil
    ) -> TrialStation {
        let homePowerOptions = [
            option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
        ]
        let gymPowerOptions = [
            option("exercise.romanian-deadlift", requiredEquipment: [.barbell]),
            option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
        ]

        return station(
            id,
            title: title,
            category: .hingePower,
            movementId: loadout == .gymHybrid ? "exercise.romanian-deadlift" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.single-leg-rdl",
            displayName: loadout == .noGymField ? "Backpack Single-Leg RDL" : nil,
            metric: .reps,
            minimumValue: minimumValue,
            minimumQualifyingSets: 1,
            plannedSets: 3,
            capSeconds: capSeconds,
            loadPercentOfBodyweight: loadout == .noGymField ? noGymLoadPercent : nil,
            strengthTier: loadout == .noGymField ? nil : .unbound,
            dynamicGroupKey: dynamicGroupKey,
            movementOptions: loadout == .noGymField
                ? [option("exercise.single-leg-rdl", "Backpack Single-Leg RDL", requiredEquipment: [.bodyweight, .openSpace])]
                : loadout == .gymHybrid ? gymPowerOptions : homePowerOptions
        )
    }

    private static func lastGateHandStations(loadout: TrialLoadout) -> [TrialStation] {
        let suits = deckSuitSpecs(loadout: loadout)
        let ranks = deckRanks.prefix(TrialStandards.TheLastGate.landing4CardCount)

        return ranks.enumerated().map { index, rank in
            let suit = suits[index % suits.count]
            let cardNumber = String(format: "%02d", index + 1)
            let cardCode = "\(rank.code)\(suit.code)"
            return station(
                "lastgate-landing-4-card-\(cardNumber)",
                title: "Landing 4 - Card \(cardCode) \(suit.title)",
                category: suit.category,
                movementId: suit.movementId,
                displayName: suit.displayName,
                metric: .reps,
                minimumValue: rank.reps,
                restSeconds: TrialStandards.DeckOfProof.restSeconds,
                capSeconds: TrialStandards.TheLastGate.landing4CapSeconds,
                movementOptions: deckMovementOptions(for: suit, cardValue: rank.reps),
                restRule: "Short rest, then flip the next card."
            )
        }
    }

    private static func lastGateLanding6Stations(loadout: TrialLoadout) -> [TrialStation] {
        let dynamicGroupKey = "lastgate-landing-6"
        return [
            lastGatePowerStrikeStation(
                "lastgate-landing-6-power",
                title: "Landing 6 - Power Seal",
                loadout: loadout,
                minimumValue: TrialStandards.SevenSeals.powerStrikeReps,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                noGymLoadPercent: TrialStandards.SevenSeals.spiritCarryLoadPercentNoGym + 0.10,
                dynamicGroupKey: dynamicGroupKey
            ),
            station(
                "lastgate-landing-6-vitality",
                title: "Landing 6 - Vitality Seal",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.vitalityLowerReps,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                dynamicGroupKey: dynamicGroupKey,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]),
                        option("exercise.goblet-squat", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.leg-press", requiredEquipment: [.machine]),
                        option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])
                    ]
                )
            ),
            station(
                "lastgate-landing-6-control",
                title: "Landing 6 - Control Seal",
                category: .mobilityControl,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.SevenSeals.controlHoldSeconds,
                minimumQualifyingSets: TrialStandards.SevenSeals.controlSets,
                plannedSets: TrialStandards.SevenSeals.controlSets,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                dynamicGroupKey: dynamicGroupKey,
                movementOptions: [option("exercise.plank")]
            ),
            engineStation(
                "lastgate-landing-6-endurance",
                title: "Landing 6 - Endurance Seal",
                loadout: loadout,
                runMeters: TrialStandards.SevenSeals.enduranceEngineMeters,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                dynamicGroupKey: dynamicGroupKey
            ),
            station(
                "lastgate-landing-6-mobility",
                title: "Landing 6 - Mobility Seal",
                category: .mobilityControl,
                movementId: "mobility.deep-squat-hold",
                metric: .holdSeconds,
                minimumValue: TrialStandards.SevenSeals.mobilityDeepSquatHoldSeconds,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                dynamicGroupKey: dynamicGroupKey,
                movementOptions: [option("mobility.deep-squat-hold", requiredEquipment: [.bodyweight, .openSpace])]
            ),
            station(
                "lastgate-landing-6-explosiveness",
                title: "Landing 6 - Explosiveness Seal",
                category: .explosive,
                movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge",
                metric: .reps,
                minimumValue: TrialStandards.SevenSeals.explosivenessReps,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                dynamicGroupKey: dynamicGroupKey,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.glute-bridge"),
                    home: [
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]),
                        option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])
                    ],
                    gym: [
                        option("exercise.cable-pull-through", requiredEquipment: [.cable]),
                        option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])
                    ]
                )
            )
        ]
    }

    private static func theLastGateStations(loadout: TrialLoadout) -> [TrialStation] {
        return lastGateLanding1Stations(loadout: loadout) + [
            engineStation(
                "lastgate-landing-2-count",
                title: "Landing 2 - The Count",
                loadout: loadout,
                runMeters: TrialStandards.TheLastGate.landing2EngineMeters,
                capSeconds: TrialStandards.TheLastGate.landing2WindowSeconds
            ),
            lastGatePowerStrikeStation(
                "lastgate-landing-3-strike",
                title: "Landing 3 - The Strike",
                loadout: loadout,
                minimumValue: TrialStandards.TheLastGate.landing3StrikeReps,
                noGymLoadPercent: 0.30
            )
        ]
            + lastGateHandStations(loadout: loadout)
            + [
                engineStation(
                    "lastgate-landing-5-engine",
                    title: "Landing 5 - The Engine",
                    loadout: loadout,
                    runMeters: TrialStandards.TheLastGate.landing5EngineMeters
                ),
                station(
                    "lastgate-landing-5-hold",
                    title: "Landing 5 - The Hold",
                    category: .mobilityControl,
                    movementId: "exercise.plank",
                    metric: .holdSeconds,
                    minimumValue: TrialStandards.TheLastGate.landing5HoldSeconds,
                    movementOptions: [option("exercise.plank")]
                )
            ]
            + lastGateLanding6Stations(loadout: loadout)
            + [
                station(
                    "lastgate-landing-7-carry",
                    title: "Landing 7 - The Carry",
                    category: .carryCore,
                    movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry",
                    metric: .distanceMeters,
                    minimumValue: TrialStandards.TheLastGate.landing7CarryMeters,
                    loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.TheLastGate.landing7CarryLoadPercentNoGym : TrialStandards.TheLastGate.landing7CarryLoadPercentLoaded,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                        home: [
                            option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]),
                            option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                        ],
                        gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                    )
                ),
                station(
                    "lastgate-summit",
                    title: "The Summit",
                    category: .mobilityControl,
                    movementId: "exercise.plank",
                    metric: .holdSeconds,
                    minimumValue: TrialStandards.TheLastGate.summitHoldSeconds,
                    capSeconds: TrialStandards.TheLastGate.summitCapSeconds,
                    movementOptions: [option("exercise.plank")]
                )
            ]
    }

    static let firstLight = OverallRankTrialDefinition(
        id: "gate-01-first-light",
        targetRank: .novice,
        displayName: "First Light",
        subtitle: "Rank Gate I — light the courtyard",
        estimatedMinutes: 15,
        format: .firstLight,
        minOverallLevel: 1,
        requiredEquipment: [.bodyweight],
        performanceStandards: firstLightStations(loadout: .homeKit).map(\.standard),
        loadoutVariants: loadoutVariants(
            noGym: firstLightStations(loadout: .noGymField),
            home: firstLightStations(loadout: .homeKit),
            gym: firstLightStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-novice-awakening", "overall-rank-trial-novice-foundation-proof"]
    )

    static let theCount = OverallRankTrialDefinition(
        id: "gate-02-the-count",
        targetRank: .apprentice,
        displayName: "The Count",
        subtitle: "Rank Gate II — answer the dojo bell",
        estimatedMinutes: 20,
        format: .theCount,
        minOverallLevel: 8,
        requiredEquipment: [.bodyweight],
        performanceStandards: theCountStations(loadout: .homeKit).map(\.standard),
        loadoutVariants: loadoutVariants(
            noGym: theCountStations(loadout: .noGymField),
            home: theCountStations(loadout: .homeKit),
            gym: theCountStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-apprentice-calibration"]
    )

    static let theForging = definition(
        id: "gate-03-the-forging",
        targetRank: .forged,
        displayName: "The Forging",
        subtitle: "Rank Gate III - heavy strikes and quench",
        estimatedMinutes: 30,
        format: .theForging,
        minOverallLevel: 15,
        loadoutVariants: loadoutVariants(
            noGym: theForgingStations(loadout: .noGymField),
            home: theForgingStations(loadout: .homeKit),
            gym: theForgingStations(loadout: .gymHybrid)
        ),
        legacyIds: [
            "overall-rank-trial-forged-forge",
            "overall-rank-trial-honed-forge",
            "overall-rank-trial-master-forge"
        ],
        enforcesTotalTimeCap: false
    )

    static let deckOfProof = definition(
        id: "gate-04-deck-of-proof",
        targetRank: .veteran,
        displayName: "Deck of Proof",
        subtitle: "Forged to Veteran rank gate",
        estimatedMinutes: 42,
        format: .deckOfProof,
        minOverallLevel: 22,
        loadoutVariants: loadoutVariants(
            noGym: deckStations(loadout: .noGymField),
            home: deckStations(loadout: .homeKit),
            gym: deckStations(loadout: .gymHybrid)
        ),
        legacyIds: [
            "overall-rank-trial-veteran-reckoning",
            "overall-rank-trial-forged-reckoning"
        ]
    )

    static let theAscent = definition(
        id: "gate-05-the-ascent",
        targetRank: .master,
        displayName: "The Ascent",
        subtitle: "Veteran to Master rank gate",
        estimatedMinutes: 50,
        format: .theAscent,
        minOverallLevel: 40,
        loadoutVariants: loadoutVariants(
            noGym: theAscentStations(loadout: .noGymField),
            home: theAscentStations(loadout: .homeKit),
            gym: theAscentStations(loadout: .gymHybrid)
        ),
        legacyIds: [
            "overall-rank-trial-master-gauntlet",
            "overall-rank-trial-veteran-gauntlet"
        ]
    )

    static let sevenSeals = definition(
        id: "gate-06-seven-seals",
        targetRank: .vessel,
        displayName: "The Seven Seals",
        subtitle: "Master to Vessel rank gate",
        estimatedMinutes: 58,
        format: .sevenSeals,
        minOverallLevel: 55,
        loadoutVariants: loadoutVariants(
            noGym: sevenSealsStations(loadout: .noGymField),
            home: sevenSealsStations(loadout: .homeKit),
            gym: sevenSealsStations(loadout: .gymHybrid)
        ),
        legacyIds: [
            "overall-rank-trial-vessel-ten-hundred",
            "overall-rank-trial-vessel-crucible"
        ]
    )

    static let theThreshold = definition(
        id: "gate-07-the-threshold",
        targetRank: .ascendant,
        displayName: "The Threshold",
        subtitle: "Vessel to Ascendant rank gate",
        estimatedMinutes: 65,
        format: .theThreshold,
        minOverallLevel: 72,
        loadoutVariants: loadoutVariants(
            noGym: theThresholdStations(loadout: .noGymField),
            home: theThresholdStations(loadout: .homeKit),
            gym: theThresholdStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-unbound-threshold"]
    )

    static let theLastGate = definition(
        id: "gate-08-the-last-gate",
        targetRank: .unbound,
        displayName: "The Last Gate",
        subtitle: "Ascendant to Unbound rank gate",
        estimatedMinutes: 75,
        format: .theLastGate,
        minOverallLevel: 90,
        loadoutVariants: loadoutVariants(
            noGym: theLastGateStations(loadout: .noGymField),
            home: theLastGateStations(loadout: .homeKit),
            gym: theLastGateStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-ascendant-ascension"]
    )

    static let all: [OverallRankTrialDefinition] = [
        firstLight,
        theCount,
        theForging,
        deckOfProof,
        theAscent,
        sevenSeals,
        theThreshold,
        theLastGate
    ]

    static func definition(id: String) -> OverallRankTrialDefinition? {
        if let definition = all.first(where: { $0.id == id || $0.legacyIds.contains(id) }) {
            return definition
        }
        return nil
    }

    static func nextTrial(after rank: RankTitle) -> OverallRankTrialDefinition? {
        switch rank {
        case .initiate:
            return firstLight
        case .novice:
            return theCount
        case .apprentice:
            return theForging
        case .forged:
            return deckOfProof
        case .veteran:
            return theAscent
        case .master:
            return sevenSeals
        case .vessel:
            return theThreshold
        case .ascendant:
            return theLastGate
        default:
            return nil
        }
    }
}

/// How a rank crossing is claimed once eligibility (accumulation + LVL) is met.
/// Derived purely from the target rank — not new config.
///   - Novice through Veteran (rawValue 1–4): `benchmark` — one short
///     qualifying session, infinitely retryable. Early ranks still get real,
///     playable trials instead of synthetic claims.
///   - Master+ (rawValue ≥ 5 — the crown crossings): `gauntlet` —
///     the epic themed conditioning gauntlet (The Ascent onward).
enum OverallRankCeremonyTier: String, Equatable, Sendable {
    case benchmark
    case gauntlet
}

extension OverallRankTrialDefinitions {
    static func ceremonyTier(for targetRank: RankTier) -> OverallRankCeremonyTier {
        switch targetRank.rawValue {
        case ...4:           // Novice through Veteran
            return .benchmark
        default:             // Master and up — the epic gauntlets
            return .gauntlet
        }
    }
}

extension RankTitle {
    var overallRankTrialOrder: Int {
        switch self {
        case .initiate: return 0
        case .novice: return 1
        case .apprentice: return 2
        case .forged: return 3
        case .veteran: return 4
        case .master: return 5
        case .vessel: return 6
        case .ascendant: return 7
        case .unbound: return 8
        }
    }
}
