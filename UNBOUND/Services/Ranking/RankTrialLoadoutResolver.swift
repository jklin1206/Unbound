import Foundation

final class RankTrialLoadoutResolver {
    static let shared = RankTrialLoadoutResolver()

    private init() {}

    func resolve(
        definition: OverallRankTrialDefinition,
        userId: String,
        equipment rawEquipment: Set<MovementEquipment>,
        generatedAt: Date = Date()
    ) -> RankTrialResolution {
        let equipment = normalizedEquipment(rawEquipment)
        let variants = definition.loadoutVariants.isEmpty
            ? [fallbackVariant(for: definition)]
            : definition.loadoutVariants
        let preferred = preferredLoadouts(for: equipment)
        let preferredVariants = preferred.compactMap { loadout in variants.first { $0.loadout == loadout } }
        let exactVariant = preferredVariants.first { variant in
            variant.requiredEquipment.isSubset(of: equipment) && stationEquipmentGaps(for: variant, equipment: equipment).isEmpty
        }
        let chosenVariant = exactVariant
            ?? preferredVariants.first { $0.requiredEquipment.isSubset(of: equipment) }
            ?? variants.first

        guard let chosenVariant else {
            return RankTrialResolution(
                definition: definition,
                resolvedTrial: nil,
                blockers: [
                    RankTrialResolutionBlocker(
                        id: "no-loadout",
                        title: "No official loadout",
                        message: "This rank gate needs an official protocol before it can start.",
                        missingEquipment: []
                    )
                ]
            )
        }

        var blockers: [RankTrialResolutionBlocker] = []
        let missingLoadoutEquipment = chosenVariant.requiredEquipment.subtracting(equipment)
        if !missingLoadoutEquipment.isEmpty {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "loadout-equipment",
                    title: "Missing loadout gear",
                    message: missingLoadoutEquipment.map(\.displayName).sorted().joined(separator: ", "),
                    missingEquipment: missingLoadoutEquipment
                )
            )
        }

        if requiresPullSolution(definition), !hasPullSolution(equipment) {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "pull-solution",
                    title: "Pull station blocked",
                    message: "Add a safe row or pull option before this gate can clear Overall Rank.",
                    missingEquipment: [.pullupBar, .band, .dumbbell, .cable, .machine, .rings]
                )
            )
        }

        var resolvedStations: [ResolvedTrialStation] = []
        var missingResolvedStationEquipment: Set<MovementEquipment> = []

        for station in chosenVariant.stations {
            let selected = station.movementOptions.first { option in
                option.requiredEquipment.isSubset(of: equipment)
            } ?? station.primaryMovement
            missingResolvedStationEquipment.formUnion(selected.requiredEquipment.subtracting(equipment))
            resolvedStations.append(
                ResolvedTrialStation(
                    id: station.id,
                    station: station,
                    selectedMovement: selected
                )
            )
        }

        if !missingResolvedStationEquipment.isEmpty {
            blockers.append(
                RankTrialResolutionBlocker(
                    id: "station-equipment",
                    title: "Missing station gear",
                    message: missingResolvedStationEquipment.map(\.displayName).sorted().joined(separator: ", "),
                    missingEquipment: missingResolvedStationEquipment
                )
            )
        }

        let resolvedTrial = ResolvedRankTrial(
            id: "\(definition.id):\(chosenVariant.loadout.rawValue):v1",
            definitionId: definition.id,
            userId: userId,
            selectedLoadout: chosenVariant.loadout,
            stations: resolvedStations,
            generatedAt: generatedAt,
            version: 1
        )

        return RankTrialResolution(
            definition: definition,
            resolvedTrial: resolvedTrial,
            blockers: blockers
        )
    }

    private func normalizedEquipment(_ equipment: Set<MovementEquipment>) -> Set<MovementEquipment> {
        var normalized = equipment
        normalized.insert(.bodyweight)
        normalized.insert(.openSpace)
        if normalized.contains(.machine) || normalized.contains(.cable) || normalized.contains(.cardioMachine) {
            normalized.formUnion([.machine, .cable, .cardioMachine])
        }
        return normalized
    }

    private func preferredLoadouts(for equipment: Set<MovementEquipment>) -> [TrialLoadout] {
        if equipment.contains(.machine) || equipment.contains(.cable) || equipment.contains(.cardioMachine) || equipment.contains(.barbell) {
            return [.gymHybrid, .homeKit, .noGymField]
        }
        if equipment.contains(.dumbbell) || equipment.contains(.kettlebell) || equipment.contains(.band) || equipment.contains(.pullupBar) {
            return [.homeKit, .noGymField, .gymHybrid]
        }
        return [.noGymField, .homeKit, .gymHybrid]
    }

    private func stationEquipmentGaps(
        for variant: TrialLoadoutVariant,
        equipment: Set<MovementEquipment>
    ) -> Set<MovementEquipment> {
        variant.stations.reduce(into: Set<MovementEquipment>()) { result, station in
            if station.movementOptions.contains(where: { $0.requiredEquipment.isSubset(of: equipment) }) {
                return
            }
            result.formUnion(station.primaryMovement.requiredEquipment.subtracting(equipment))
        }
    }

    private func requiresPullSolution(_ definition: OverallRankTrialDefinition) -> Bool {
        definition.targetRank.overallRankTrialOrder >= RankTitle.apprentice.overallRankTrialOrder
    }

    private func hasPullSolution(_ equipment: Set<MovementEquipment>) -> Bool {
        !equipment.intersection([.pullupBar, .band, .dumbbell, .kettlebell, .cable, .machine, .rings]).isEmpty
    }

    private func fallbackVariant(for definition: OverallRankTrialDefinition) -> TrialLoadoutVariant {
        TrialLoadoutVariant(
            loadout: .homeKit,
            requiredEquipment: definition.requiredEquipment,
            promise: "Legacy rank gate compatibility.",
            stations: definition.performanceStandards.enumerated().map { index, standard in
                TrialStation(
                    id: "legacy-\(index + 1)",
                    title: standard.displayName,
                    category: category(for: standard),
                    standard: standard,
                    capSeconds: nil,
                    loadPercentOfBodyweight: nil,
                    movementOptions: [TrialMovementOption(movementId: standard.movementId, displayName: standard.displayName)],
                    restRule: "Rest \(standard.restSeconds)s.",
                    qualityFlags: [.clean]
                )
            }
        )
    }

    private func category(for standard: OverallRankTrialPerformanceStandard) -> TrialMovementCategory {
        switch standard.blockKind {
        case .cardio:
            return .engine
        case .carry:
            return .carryCore
        case .skill:
            return .mobilityControl
        case .bodyweight:
            if standard.movementId.contains("pull") || standard.movementId.contains("row") {
                return .pull
            }
            if standard.movementId.contains("squat") || standard.movementId.contains("lunge") || standard.movementId.contains("step") {
                return .lower
            }
            return .push
        case .strength:
            if standard.movementId.contains("row") || standard.movementId.contains("pulldown") {
                return .pull
            }
            if standard.movementId.contains("deadlift") || standard.movementId.contains("swing") || standard.movementId.contains("hinge") {
                return .hingePower
            }
            return .lower
        case .routine, .custom:
            return .mobilityControl
        }
    }
}
