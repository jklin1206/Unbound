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
        legacyIds: Set<String> = []
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
            legacyIds: legacyIds
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
        capSeconds: Int? = nil
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
                runMeters: TrialStandards.TheForging.stokeEngineMeters
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
                "seals-power",
                title: "Seal IV — Power",
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
                "seals-mobility",
                title: "Seal VI — Mobility",
                category: .mobilityControl,
                movementId: "mobility.deep-squat-hold",
                metric: .holdSeconds,
                minimumValue: TrialStandards.SevenSeals.mobilityDeepSquatHoldSeconds,
                capSeconds: TrialStandards.SevenSeals.sealCapSeconds,
                movementOptions: [option("mobility.deep-squat-hold", requiredEquipment: [.bodyweight, .openSpace])]
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

    private static func raidStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("raid-stage-1", title: "Stage 1 Engine Repeats", loadout: loadout, runMeters: TrialStandards.Raid.engineMeters, minimumQualifyingSets: TrialStandards.Raid.engineSets, capSeconds: TrialStandards.Raid.engineCapSeconds),
            station("raid-stage-2-hinge", title: "Stage 2 Hinge Raid", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge", metric: .reps, minimumValue: TrialStandards.Raid.workReps, minimumQualifyingSets: TrialStandards.Raid.workSets, plannedSets: TrialStandards.Raid.workSets, capSeconds: TrialStandards.Raid.workCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])])),
            station("raid-stage-2-upper", title: "Stage 2 Press / Row Raid", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: TrialStandards.Raid.workReps, minimumQualifyingSets: TrialStandards.Raid.workSets, plannedSets: TrialStandards.Raid.workSets, capSeconds: TrialStandards.Raid.workCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("raid-stage-2-carry", title: "Stage 2 Carry Raid", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: TrialStandards.Raid.carryMeters, minimumQualifyingSets: TrialStandards.Raid.workSets, plannedSets: TrialStandards.Raid.workSets, capSeconds: TrialStandards.Raid.workCapSeconds, loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.Raid.carryLoadPercentNoGym : TrialStandards.Raid.carryLoadPercentLoaded, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            station("raid-stage-3-control", title: "Stage 3 Recovery-Control Hold", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: TrialStandards.Raid.controlHoldSeconds, minimumQualifyingSets: TrialStandards.Raid.controlSets, plannedSets: TrialStandards.Raid.controlSets, capSeconds: TrialStandards.Raid.controlCapSeconds, movementOptions: [option("exercise.plank")])
        ]
    }

    private static func finalExamStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            station("exam-part-a-explosive", title: "Part A Explosive Control", category: .explosive, movementId: loadout == .gymHybrid ? "exercise.kettlebell-swing" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.step-up", metric: .reps, minimumValue: TrialStandards.FinalExam.explosiveReps, capSeconds: TrialStandards.FinalExam.explosiveCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")], gym: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")])),
            engineStation("exam-part-b-engine", title: "Part B Capacity", loadout: loadout, runMeters: TrialStandards.FinalExam.engineMeters, capSeconds: TrialStandards.FinalExam.engineCapSeconds),
            station("exam-part-c-pull", title: "Part C Pull Volume", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: TrialStandards.FinalExam.pullReps, capSeconds: TrialStandards.FinalExam.volumeCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("exam-part-c-push", title: "Part C Push Volume", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: TrialStandards.FinalExam.pushReps, capSeconds: TrialStandards.FinalExam.volumeCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")])),
            station("exam-part-c-lower", title: "Part C Lower Volume", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up", metric: .reps, minimumValue: TrialStandards.FinalExam.lowerReps, capSeconds: TrialStandards.FinalExam.volumeCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])])),
            station("exam-part-c-carry", title: "Part C Carry Finish", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: TrialStandards.FinalExam.carryMeters, capSeconds: TrialStandards.FinalExam.volumeCapSeconds, loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.FinalExam.carryLoadPercentNoGym : TrialStandards.FinalExam.carryLoadPercentLoaded, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            station("exam-part-c-trunk", title: "Part C Trunk Finish", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: TrialStandards.FinalExam.trunkHoldSeconds, capSeconds: TrialStandards.FinalExam.volumeCapSeconds, movementOptions: [option("exercise.plank")])
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
        ]
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

    static let threshold = definition(
        id: "overall-rank-trial-unbound-threshold",
        targetRank: .ascendant,
        displayName: "Threshold Raid",
        subtitle: "Vessel to Ascendant rank gate",
        estimatedMinutes: 65,
        format: .theThreshold,
        minOverallLevel: 72,
        loadoutVariants: loadoutVariants(
            noGym: raidStations(loadout: .noGymField),
            home: raidStations(loadout: .homeKit),
            gym: raidStations(loadout: .gymHybrid)
        )
    )

    static let ascension = definition(
        id: "overall-rank-trial-ascendant-ascension",
        targetRank: .unbound,
        displayName: "Final Exam",
        subtitle: "Ascendant to Unbound rank gate",
        estimatedMinutes: 75,
        format: .theLastGate,
        minOverallLevel: 90,
        loadoutVariants: loadoutVariants(
            noGym: finalExamStations(loadout: .noGymField),
            home: finalExamStations(loadout: .homeKit),
            gym: finalExamStations(loadout: .gymHybrid)
        )
    )

    static let all: [OverallRankTrialDefinition] = [
        firstLight,
        theCount,
        theForging,
        deckOfProof,
        theAscent,
        sevenSeals,
        threshold,
        ascension
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
            return threshold
        case .ascendant:
            return ascension
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
///   - Master+ (rawValue ≥ 5 — the crown crossings, Tower onward): `gauntlet` —
///     the epic themed conditioning gauntlet (Tower / Boss Rush / Raid /
///     Final Exam).
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
