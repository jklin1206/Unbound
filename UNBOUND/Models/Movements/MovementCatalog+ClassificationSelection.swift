import Foundation

// Program-generation selection: movement slots, alternative/program scoring,
// and equipment capability resolution.
extension MovementCatalog {
    static func movementSlot(for exercise: CatalogExercise) -> MovementSlot {
        switch pattern(for: exercise.name) {
        case .legsQuad: return .squat
        case .legsPosterior: return .hinge
        case .pushHorizontal: return .horizontalPush
        case .pushVertical: return .verticalPush
        case .pullHorizontal: return .horizontalPull
        case .pullVertical: return .verticalPull
        case .arms: return .arms
        case .core: return .core
        case .calves: return .calves
        case nil: return .routine
        }
    }

    static func movementSlot(for pattern: MovementPattern) -> MovementSlot {
        switch pattern {
        case .legsQuad: return .squat
        case .legsPosterior: return .hinge
        case .pushHorizontal: return .horizontalPush
        case .pushVertical: return .verticalPush
        case .pullHorizontal: return .horizontalPull
        case .pullVertical: return .verticalPull
        case .arms: return .arms
        case .core: return .core
        case .calves: return .calves
        }
    }

    static func exerciseSortKey(_ definition: MovementDefinition) -> String {
        let tier = definition.progressionTier ?? 999
        return String(format: "%03d-%@", tier, definition.displayName)
    }

    static func alternativeScore(_ candidate: MovementDefinition, replacing current: MovementDefinition) -> Int {
        var score = 0
        if candidate.substitutionGroup != current.substitutionGroup {
            score += 1_000
        }
        if candidate.rankStandardMovementId != current.rankStandardMovementId {
            score += 100
        }
        if candidate.rankTemplate != current.rankTemplate {
            score += 50
        }
        score += difficultyScore(candidate.difficulty) * 5
        if candidate.variantOfMovementId != nil {
            score += 1
        }
        return score
    }

    static func alternativeDefinitions(replacing current: MovementDefinition) -> [MovementDefinition] {
        legacyExercises
            .filter { candidate in
                candidate.id != current.id
                    && candidate.role == .canonicalExercise
                    && candidate.movementSlot == current.movementSlot
                    && candidate.canonicalExerciseName != nil
            }
            .sorted { lhs, rhs in
                let lhsScore = alternativeScore(lhs, replacing: current)
                let rhsScore = alternativeScore(rhs, replacing: current)
                if lhsScore != rhsScore { return lhsScore < rhsScore }
                return lhs.displayName < rhs.displayName
            }
    }

    static func uniqueCatalogExercises(from definitions: [MovementDefinition]) -> [CatalogExercise] {
        var seen: Set<String> = []
        return definitions.compactMap(catalogExercise(for:)).filter { exercise in
            guard !seen.contains(exercise.name) else { return false }
            seen.insert(exercise.name)
            return true
        }
    }

    static func programScore(_ definition: MovementDefinition, style: TrainingStyle) -> Int {
        var score = 0

        switch style {
        case .bodyweight:
            if definition.blockKind != .bodyweight { score += 1_000 }
            if definition.rankTemplate == .holdControl { score -= 15 }
            if definition.rankTemplate == .bodyweightReps { score -= 10 }
        case .freeWeights:
            if definition.equipment.contains(.barbell) { score -= 20 }
            if definition.equipment.contains(.dumbbell) || definition.equipment.contains(.kettlebell) { score -= 10 }
            // Machines and cables are first-class for a full gym - no penalty. The
            // best tool for the pattern (e.g. a cable lat pulldown for a vertical
            // pull) should win on its own merits, not be pushed below a band.
        case .machines:
            if definition.equipment.contains(.machine) || definition.equipment.contains(.cable) || definition.equipment.contains(.smithMachine) { score -= 20 }
            if definition.equipment.contains(.barbell) || definition.equipment.contains(.dumbbell) { score += 50 }
        case .hybrid:
            break
        }

        // Bands are a substitute for when better equipment isn't available, not a
        // first pick. Deprioritize them across every style so a barbell / dumbbell /
        // cable / machine variant of the same pattern wins whenever the user's gear
        // includes one. The equipment-filtered movement pool still falls back to a
        // band when it is genuinely the only option for that slot.
        if definition.equipment.contains(.band) {
            score += 40
        }

        if definition.variantOfMovementId != nil {
            score += 5
        }
        score += difficultyScore(definition.difficulty) * 10
        score += (definition.progressionTier ?? 0)
        return score
    }

    static func difficultyScore(_ difficulty: MovementDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .elite: return 3
        }
    }

    static func requiredProgramEquipment(for definition: MovementDefinition) -> Set<MovementEquipment> {
        var required = Set(definition.equipment)
        required.remove(.bodyweight)
        required.remove(.openSpace)

        let stationEquipment: Set<MovementEquipment> = [.machine, .cable, .smithMachine]
        if !required.isDisjoint(with: stationEquipment) {
            required.remove(.pullupBar)
            required.remove(.dipStation)
            required.remove(.rings)
        }

        return required
    }

    static func movementCapabilities(for equipment: [Equipment]) -> Set<MovementEquipment> {
        var capabilities: Set<MovementEquipment> = [.bodyweight, .openSpace]

        for item in equipment {
            switch item {
            case .fullGym:
                capabilities.formUnion(MovementEquipment.allCases)
            case .machines:
                capabilities.formUnion([.machine, .cable, .smithMachine, .cardioMachine])
            case .barbell:
                capabilities.insert(.barbell)
            case .dumbbells:
                capabilities.formUnion([.dumbbell, .kettlebell])
            case .bench:
                capabilities.insert(.bench)
            case .pullupBar:
                capabilities.insert(.pullupBar)
            case .dipStation:
                capabilities.insert(.dipStation)
            case .rings:
                capabilities.insert(.rings)
            case .bodyweight:
                capabilities.formUnion([.bodyweight, .openSpace])
            case .bands:
                capabilities.insert(.band)
            case .homeWeights:
                capabilities.formUnion([
                    .bodyweight, .openSpace, .barbell, .dumbbell, .kettlebell,
                    .bench, .box, .band, .pullupBar
                ])
            }
        }

        return capabilities
    }

    static func hasExternalLoadCapability(_ equipment: [Equipment]) -> Bool {
        equipment.contains(.fullGym)
            || equipment.contains(.homeWeights)
            || equipment.contains(.barbell)
            || equipment.contains(.dumbbells)
            || equipment.contains(.machines)
    }

    static func pattern(for exerciseName: String) -> MovementPattern? {
        let key = exerciseName.lowercased()
        return MovementPattern.allCases.first { pattern in
            (ExerciseCatalog.exercisesByPattern[pattern] ?? []).contains { $0.name == key }
        }
    }
}
