import Foundation

enum OverallRankTrialDefinitions {
    private static func option(
        _ movementId: String,
        _ displayName: String? = nil,
        requiredEquipment: Set<MovementEquipment>? = nil
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
            requiredEquipment: normalizedRequirement
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

    private static func daily100Stations(loadout: TrialLoadout) -> [TrialStation] {
        [
            station(
                "daily-lower",
                title: "Lower Oath",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.bodyweight-squat",
                metric: .reps,
                minimumValue: TrialStandards.Daily100.lowerReps,
                capSeconds: TrialStandards.Daily100.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.bodyweight-squat"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.bodyweight-squat")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])]
                )
            ),
            station(
                "daily-push",
                title: "Push Oath",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.pushup" : "exercise.incline-pushup",
                metric: .reps,
                minimumValue: TrialStandards.Daily100.pushReps,
                capSeconds: TrialStandards.Daily100.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.incline-pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                )
            ),
            station(
                "daily-pull",
                title: "Posture Oath",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: TrialStandards.Daily100.pullReps,
                capSeconds: TrialStandards.Daily100.stationCapSeconds,
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
                "daily-engine",
                title: "Step Oath",
                category: .engine,
                movementId: "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.Daily100.engineReps,
                capSeconds: TrialStandards.Daily100.stationCapSeconds,
                movementOptions: [option("exercise.step-up")]
            ),
            station(
                "daily-trunk",
                title: "Trunk Oath",
                category: .carryCore,
                movementId: "exercise.plank",
                metric: .holdSeconds,
                minimumValue: TrialStandards.Daily100.trunkHoldSeconds,
                capSeconds: TrialStandards.Daily100.stationCapSeconds,
                movementOptions: [option("exercise.plank")]
            )
        ]
    }

    private static func operatorStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("operator-engine", title: "6-Minute Engine Floor", loadout: loadout, runMeters: TrialStandards.OperatorScreen.engineMeters, capSeconds: TrialStandards.OperatorScreen.engineCapSeconds),
            station(
                "operator-lower",
                title: "2-Minute Lower Floor",
                category: .lower,
                movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.goblet-squat" : "exercise.step-up",
                metric: .reps,
                minimumValue: TrialStandards.OperatorScreen.lowerReps,
                capSeconds: TrialStandards.OperatorScreen.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.step-up"),
                    home: [option("exercise.goblet-squat", requiredEquipment: [.dumbbell]), option("exercise.step-up")],
                    gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.step-up")]
                )
            ),
            station(
                "operator-push",
                title: "2-Minute Push Floor",
                category: .push,
                movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                metric: .reps,
                minimumValue: TrialStandards.OperatorScreen.pushReps,
                capSeconds: TrialStandards.OperatorScreen.stationCapSeconds,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.pushup"),
                    home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                    gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                )
            ),
            station(
                "operator-pull",
                title: "2-Minute Pull Floor",
                category: .pull,
                movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                metric: .reps,
                minimumValue: TrialStandards.OperatorScreen.pullReps,
                capSeconds: TrialStandards.OperatorScreen.stationCapSeconds,
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
                "operator-carry-core",
                title: "Carry / Core Floor",
                category: .carryCore,
                movementId: loadout == .noGymField ? "exercise.plank" : "carry.suitcase-carry",
                metric: loadout == .noGymField ? .holdSeconds : .distanceMeters,
                minimumValue: loadout == .noGymField ? TrialStandards.OperatorScreen.coreHoldSeconds : TrialStandards.OperatorScreen.carryMeters,
                capSeconds: TrialStandards.OperatorScreen.carryCapSeconds,
                loadPercentOfBodyweight: loadout == .noGymField ? nil : TrialStandards.OperatorScreen.carryLoadPercent,
                movementOptions: movementSet(
                    loadout: loadout,
                    noGym: option("exercise.plank"),
                    home: [
                        option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]),
                        option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])
                    ],
                    gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                )
            )
        ]
    }

    private static func finisherStations(loadout: TrialLoadout) -> [TrialStation] {
        let reps = TrialStandards.Finisher.roundReps
        return reps.enumerated().flatMap { index, count in
            let round = index + 1
            return [
                engineStation("finisher-r\(round)-engine", title: "Round \(round) Engine Buy-In", loadout: loadout, runMeters: TrialStandards.Finisher.engineMeters),
                station(
                    "finisher-r\(round)-hinge",
                    title: "Round \(round) Hinge \(count)",
                    category: .hingePower,
                    movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge",
                    metric: .reps,
                    minimumValue: count,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.glute-bridge"),
                        home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])]
                    )
                ),
                station(
                    "finisher-r\(round)-push",
                    title: "Round \(round) Push \(count)",
                    category: .push,
                    movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup",
                    metric: .reps,
                    minimumValue: count,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.pushup"),
                        home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])],
                        gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.pushup")]
                    )
                ),
                station(
                    "finisher-r\(round)-pull",
                    title: "Round \(round) Pull \(max(3, count / 3))",
                    category: .pull,
                    movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row",
                    metric: .reps,
                    minimumValue: max(3, count / 3),
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("exercise.inverted-row"),
                        home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])],
                        gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])]
                    )
                ),
                station(
                    "finisher-r\(round)-carry",
                    title: "Round \(round) Carry",
                    category: .carryCore,
                    movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.suitcase-carry",
                    metric: .distanceMeters,
                    minimumValue: TrialStandards.Finisher.carryMeters,
                    movementOptions: movementSet(
                        loadout: loadout,
                        noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]),
                        home: [option("carry.suitcase-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])],
                        gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]
                    )
                )
            ]
        }
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
                    movementOptions: suit.movementOptions,
                    restRule: "Short rest, then flip the next card."
                )
            }
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

    private static func towerStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("tower-floor-01", title: "Floor 1 Engine", loadout: loadout, runMeters: TrialStandards.Tower.floor1Meters),
            station("tower-floor-02", title: "Floor 2 Lower", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up", metric: .reps, minimumValue: TrialStandards.Tower.lowerReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])])),
            station("tower-floor-03", title: "Floor 3 Push", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : loadout == .homeKit ? "exercise.dumbbell-bench-press" : "exercise.pushup", metric: .reps, minimumValue: TrialStandards.Tower.pushReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell]), option("exercise.pushup")], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("tower-floor-04", title: "Floor 4 Pull", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: TrialStandards.Tower.pullReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("tower-floor-05", title: "Floor 5 Hinge / Power", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.dumbbell-romanian-deadlift" : "exercise.glute-bridge", metric: .reps, minimumValue: TrialStandards.Tower.hingeReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])])),
            station("tower-floor-06", title: "Floor 6 Carry", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: TrialStandards.Tower.carryMeters, loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.Tower.carryLoadPercentNoGym : TrialStandards.Tower.carryLoadPercentLoaded, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])])),
            engineStation("tower-floor-07", title: "Floor 7 Long Engine", loadout: loadout, runMeters: TrialStandards.Tower.longEngineMeters),
            station("tower-floor-08", title: "Floor 8 Explosive", category: .explosive, movementId: loadout == .gymHybrid ? "exercise.kettlebell-swing" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.step-up", metric: .reps, minimumValue: TrialStandards.Tower.explosiveReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")], gym: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.step-up")])),
            station("tower-floor-09-push", title: "Floor 9 Push Blend", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: TrialStandards.Tower.blendPushReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("tower-floor-09-pull", title: "Floor 9 Pull Blend", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: TrialStandards.Tower.blendPullReps, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("tower-floor-10", title: "Floor 10 Boss Hold", category: .carryCore, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: TrialStandards.Tower.bossHoldSeconds, capSeconds: TrialStandards.Tower.bossHoldCapSeconds, movementOptions: [option("exercise.plank")])
        ]
    }

    private static func bossRushStations(loadout: TrialLoadout) -> [TrialStation] {
        [
            engineStation("boss-engine", title: "Engine Boss", loadout: loadout, runMeters: TrialStandards.BossRush.engineMeters, capSeconds: TrialStandards.BossRush.stationCapSeconds),
            station("boss-lower", title: "Lower Boss", category: .lower, movementId: loadout == .gymHybrid ? "exercise.leg-press" : loadout == .homeKit ? "exercise.dumbbell-step-up" : "exercise.step-up", metric: .reps, minimumValue: TrialStandards.BossRush.lowerReps, capSeconds: TrialStandards.BossRush.stationCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.step-up"), home: [option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell]), option("exercise.goblet-squat", requiredEquipment: [.dumbbell])], gym: [option("exercise.leg-press", requiredEquipment: [.machine]), option("exercise.dumbbell-step-up", requiredEquipment: [.dumbbell])])),
            station("boss-power", title: "Power Boss", category: .hingePower, movementId: loadout == .gymHybrid ? "exercise.cable-pull-through" : loadout == .homeKit ? "exercise.kettlebell-swing" : "exercise.glute-bridge", metric: .reps, minimumValue: TrialStandards.BossRush.powerReps, capSeconds: TrialStandards.BossRush.stationCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.glute-bridge"), home: [option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell]), option("exercise.dumbbell-romanian-deadlift", requiredEquipment: [.dumbbell])], gym: [option("exercise.cable-pull-through", requiredEquipment: [.cable]), option("exercise.kettlebell-swing", requiredEquipment: [.kettlebell])])),
            station("boss-upper-push", title: "Upper Boss Push", category: .push, movementId: loadout == .gymHybrid ? "exercise.machine-chest-press" : "exercise.pushup", metric: .reps, minimumValue: TrialStandards.BossRush.pushReps, capSeconds: TrialStandards.BossRush.stationCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.pushup"), home: [option("exercise.pushup"), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])], gym: [option("exercise.machine-chest-press", requiredEquipment: [.machine]), option("exercise.dumbbell-bench-press", requiredEquipment: [.dumbbell])])),
            station("boss-upper-pull", title: "Upper Boss Pull", category: .pull, movementId: loadout == .gymHybrid ? "exercise.cable-row-seated" : loadout == .homeKit ? "exercise.dumbbell-row" : "exercise.inverted-row", metric: .reps, minimumValue: TrialStandards.BossRush.pullReps, capSeconds: TrialStandards.BossRush.stationCapSeconds, movementOptions: movementSet(loadout: loadout, noGym: option("exercise.inverted-row"), home: [option("exercise.dumbbell-row", requiredEquipment: [.dumbbell]), option("exercise.band-row", requiredEquipment: [.band])], gym: [option("exercise.cable-row-seated", requiredEquipment: [.cable]), option("exercise.machine-row", requiredEquipment: [.machine])])),
            station("boss-control", title: "Control Boss", category: .mobilityControl, movementId: "exercise.plank", metric: .holdSeconds, minimumValue: TrialStandards.BossRush.controlHoldSeconds, minimumQualifyingSets: TrialStandards.BossRush.controlSets, plannedSets: TrialStandards.BossRush.controlSets, capSeconds: TrialStandards.BossRush.stationCapSeconds, movementOptions: [option("exercise.plank")]),
            station("boss-carry", title: "Carry Boss", category: .carryCore, movementId: loadout == .noGymField ? "carry.loaded-march" : "carry.farmer-carry", metric: .distanceMeters, minimumValue: TrialStandards.BossRush.carryMeters, capSeconds: TrialStandards.BossRush.stationCapSeconds, loadPercentOfBodyweight: loadout == .noGymField ? TrialStandards.BossRush.carryLoadPercentNoGym : TrialStandards.BossRush.carryLoadPercentLoaded, movementOptions: movementSet(loadout: loadout, noGym: option("carry.loaded-march", "Backpack Carry", requiredEquipment: [.openSpace]), home: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace]), option("carry.suitcase-carry", requiredEquipment: [.kettlebell, .openSpace])], gym: [option("carry.farmer-carry", requiredEquipment: [.dumbbell, .openSpace])]))
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

    static let foundationProof = OverallRankTrialDefinition(
        id: "overall-rank-trial-novice-awakening",
        targetRank: .novice,
        displayName: "Daily 100",
        subtitle: "Initiate to Novice rank gate",
        estimatedMinutes: 14,
        format: .daily100,
        minOverallLevel: 1,
        requiredEquipment: [.bodyweight],
        performanceStandards: daily100Stations(loadout: .homeKit).map(\.standard),
        loadoutVariants: loadoutVariants(
            noGym: daily100Stations(loadout: .noGymField),
            home: daily100Stations(loadout: .homeKit),
            gym: daily100Stations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-novice-foundation-proof"]
    )

    static let calibration = definition(
        id: "overall-rank-trial-apprentice-calibration",
        targetRank: .apprentice,
        displayName: "Operator Screen",
        subtitle: "Novice to Apprentice rank gate",
        estimatedMinutes: 20,
        format: .operatorScreen,
        minOverallLevel: 8,
        loadoutVariants: loadoutVariants(
            noGym: operatorStations(loadout: .noGymField),
            home: operatorStations(loadout: .homeKit),
            gym: operatorStations(loadout: .gymHybrid)
        )
    )

    static let forge = definition(
        id: "overall-rank-trial-forged-forge",
        targetRank: .forged,
        displayName: "The Finisher",
        subtitle: "Apprentice to Forged rank gate",
        estimatedMinutes: 30,
        format: .finisher,
        minOverallLevel: 15,
        loadoutVariants: loadoutVariants(
            noGym: finisherStations(loadout: .noGymField),
            home: finisherStations(loadout: .homeKit),
            gym: finisherStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-honed-forge", "overall-rank-trial-master-forge"]
    )

    static let reckoning = definition(
        id: "overall-rank-trial-veteran-reckoning",
        targetRank: .veteran,
        displayName: "Deck of Proof",
        subtitle: "Forged to Veteran rank gate",
        estimatedMinutes: 42,
        format: .fixedDeck,
        minOverallLevel: 22,
        loadoutVariants: loadoutVariants(
            noGym: deckStations(loadout: .noGymField),
            home: deckStations(loadout: .homeKit),
            gym: deckStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-forged-reckoning"]
    )

    static let gauntlet = definition(
        id: "overall-rank-trial-master-gauntlet",
        targetRank: .master,
        displayName: "The Tower",
        subtitle: "Veteran to Master rank gate",
        estimatedMinutes: 50,
        format: .tower,
        minOverallLevel: 40,
        loadoutVariants: loadoutVariants(
            noGym: towerStations(loadout: .noGymField),
            home: towerStations(loadout: .homeKit),
            gym: towerStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-veteran-gauntlet"]
    )

    static let crucible = definition(
        id: "overall-rank-trial-vessel-ten-hundred",
        targetRank: .vessel,
        displayName: "Boss Rush",
        subtitle: "Master to Vessel rank gate",
        estimatedMinutes: 58,
        format: .bossRush,
        minOverallLevel: 55,
        loadoutVariants: loadoutVariants(
            noGym: bossRushStations(loadout: .noGymField),
            home: bossRushStations(loadout: .homeKit),
            gym: bossRushStations(loadout: .gymHybrid)
        ),
        legacyIds: ["overall-rank-trial-vessel-crucible"]
    )

    static let threshold = definition(
        id: "overall-rank-trial-unbound-threshold",
        targetRank: .ascendant,
        displayName: "Threshold Raid",
        subtitle: "Vessel to Ascendant rank gate",
        estimatedMinutes: 65,
        format: .raid,
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
        format: .finalExam,
        minOverallLevel: 90,
        loadoutVariants: loadoutVariants(
            noGym: finalExamStations(loadout: .noGymField),
            home: finalExamStations(loadout: .homeKit),
            gym: finalExamStations(loadout: .gymHybrid)
        )
    )

    static let all: [OverallRankTrialDefinition] = [
        foundationProof,
        calibration,
        forge,
        reckoning,
        gauntlet,
        crucible,
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
            return foundationProof
        case .novice:
            return calibration
        case .apprentice:
            return forge
        case .forged:
            return reckoning
        case .veteran:
            return gauntlet
        case .master:
            return crucible
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
