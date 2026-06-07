import Foundation

enum BodyRegionSetRole: String, Codable, CaseIterable, Hashable, Sendable {
    case directHardSet
    case secondaryExposure
    case skillPractice
    case mobilityControl
    case jointTendonStress
}

struct BodyRegionTrainingLoad: Codable, Hashable, Sendable, Identifiable {
    var id: String { region.rawValue }

    var region: BodyRegion
    var directHardSets: Double
    var secondaryExposureSets: Double
    var skillPracticeSets: Double
    var mobilityControlSets: Double
    var jointTendonStressSets: Double
    var rawTaggedSets: Double

    init(
        region: BodyRegion,
        directHardSets: Double = 0,
        secondaryExposureSets: Double = 0,
        skillPracticeSets: Double = 0,
        mobilityControlSets: Double = 0,
        jointTendonStressSets: Double = 0,
        rawTaggedSets: Double = 0
    ) {
        self.region = region
        self.directHardSets = directHardSets
        self.secondaryExposureSets = secondaryExposureSets
        self.skillPracticeSets = skillPracticeSets
        self.mobilityControlSets = mobilityControlSets
        self.jointTendonStressSets = jointTendonStressSets
        self.rawTaggedSets = rawTaggedSets
    }

    var coachLoadScore: Double {
        directHardSets
            + secondaryExposureSets * 0.35
            + skillPracticeSets * 0.6
            + mobilityControlSets * 0.2
            + jointTendonStressSets * 0.5
    }

    mutating func add(_ sets: Double, as role: BodyRegionSetRole) {
        guard sets > 0 else { return }
        rawTaggedSets += sets
        switch role {
        case .directHardSet:
            directHardSets += sets
        case .secondaryExposure:
            secondaryExposureSets += sets
        case .skillPractice:
            skillPracticeSets += sets
        case .mobilityControl:
            mobilityControlSets += sets
        case .jointTendonStress:
            jointTendonStressSets += sets
        }
    }

    mutating func merge(_ other: BodyRegionTrainingLoad) {
        directHardSets += other.directHardSets
        secondaryExposureSets += other.secondaryExposureSets
        skillPracticeSets += other.skillPracticeSets
        mobilityControlSets += other.mobilityControlSets
        jointTendonStressSets += other.jointTendonStressSets
        rawTaggedSets += other.rawTaggedSets
    }
}

enum BodyRegionTrainingLedger {
    static func loads(for workout: Workout, includeWarmupCooldown: Bool = false) -> [BodyRegionTrainingLoad] {
        let exercises = includeWarmupCooldown
            ? workout.warmup + workout.mainExercises + workout.cooldown
            : workout.mainExercises
        return loads(for: exercises)
    }

    static func loads(for exercises: [Exercise]) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for exercise in exercises {
            add(
                name: exercise.name,
                movementId: nil,
                rankStandardMovementId: nil,
                sets: exercise.sets,
                muscleGroups: exercise.muscleGroups,
                blockKind: nil,
                to: &rows
            )
        }
        return sorted(rows)
    }

    static func loads(for performanceLog: PerformanceLog) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for block in performanceLog.blocks {
            for exercise in block.exercises where !exercise.skipped {
                let completedSets = exercise.sets.filter { !$0.isWarmup }.count
                add(
                    name: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId,
                    sets: completedSets > 0 ? completedSets : exercise.plannedSets,
                    muscleGroups: [],
                    blockKind: block.kind,
                    to: &rows
                )
            }
        }
        return sorted(rows)
    }

    static func loads(for draft: TrainingSessionDraft) -> [BodyRegionTrainingLoad] {
        var rows: [BodyRegion: BodyRegionTrainingLoad] = [:]
        for block in draft.blocks {
            for prescription in block.prescriptions {
                add(
                    name: prescription.exerciseName,
                    movementId: prescription.movementId,
                    rankStandardMovementId: prescription.rankStandardMovementId,
                    sets: prescription.sets,
                    muscleGroups: prescription.muscleGroups,
                    blockKind: block.kind,
                    to: &rows
                )
            }
        }
        return sorted(rows)
    }

    private static func add(
        name: String,
        movementId: String?,
        rankStandardMovementId: String?,
        sets: Int,
        muscleGroups: [MuscleGroup],
        blockKind: TrainingBlockKind?,
        to rows: inout [BodyRegion: BodyRegionTrainingLoad]
    ) {
        let setCount = Double(max(0, sets))
        guard setCount > 0 else { return }

        let definition = MovementCatalog.resolvedTrainingMovement(
            name: name,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId
        )?.exact
        let catalogRegions = bodyRegions(definition: definition, name: name, fallbackMuscleGroups: muscleGroups)
        let regions = blockKind == .carry
            ? Array(Set(catalogRegions + bodyRegions(from: muscleGroups))).sorted { $0.rawValue < $1.rawValue }
            : catalogRegions
        guard !regions.isEmpty else { return }

        let primary = Set(primaryRegions(definition: definition, name: name, regions: regions))
        for region in regions {
            let role = role(
                for: region,
                primaryRegions: primary,
                definition: definition,
                blockKind: blockKind
            )
            var load = rows[region] ?? BodyRegionTrainingLoad(region: region)
            load.add(setCount, as: role)
            if shouldOverlayJointTendonStress(
                region: region,
                role: role,
                definition: definition
            ) {
                load.add(setCount, as: .jointTendonStress)
            }
            rows[region] = load
        }
    }

    private static func shouldOverlayJointTendonStress(
        region: BodyRegion,
        role: BodyRegionSetRole,
        definition: MovementDefinition?
    ) -> Bool {
        guard role == .skillPractice,
              let definition,
              definition.movementSlot == .skill || definition.role == .skillDrill || definition.role == .skillTarget
        else { return false }

        if region == .forearms, definition.contraindicationTags.contains("wrist-sensitive") {
            return true
        }
        if (region == .shoulders || region == .frontSideDelts || region == .rearDelts),
           definition.contraindicationTags.contains("shoulder-sensitive") {
            return true
        }
        return false
    }

    private static func role(
        for region: BodyRegion,
        primaryRegions: Set<BodyRegion>,
        definition: MovementDefinition?,
        blockKind: TrainingBlockKind?
    ) -> BodyRegionSetRole {
        if blockKind == .skill
            || definition?.movementSlot == .skill
            || definition?.role == .skillTarget
            || definition?.role == .skillDrill {
            return .skillPractice
        }

        if definition?.movementSlot == .mobility || definition?.loggerMode == .mobility {
            return .mobilityControl
        }

        if blockKind == .carry || definition?.movementSlot == .carry {
            return [.forearms, .traps, .lowerBack, .shoulders, .frontSideDelts].contains(region)
                ? .jointTendonStress
                : .secondaryExposure
        }

        return primaryRegions.contains(region) ? .directHardSet : .secondaryExposure
    }

    private static func primaryRegions(
        definition: MovementDefinition?,
        name: String,
        regions: [BodyRegion]
    ) -> [BodyRegion] {
        let normalized = MovementCatalog.normalized(name)
        let present = Set(regions)

        func filtered(_ candidates: [BodyRegion]) -> [BodyRegion] {
            let matches = candidates.filter { present.contains($0) }
            return matches.isEmpty ? regions : matches
        }

        guard let definition else {
            if isAdductorName(normalized) {
                return filtered([.adductors])
            }
            if isAbductorName(normalized) {
                return filtered([.abductors, .glutes])
            }
            if isRearDeltDominantPullName(normalized) {
                return filtered([.rearDelts, .rhomboids, .traps])
            }
            if isBackRowName(normalized) {
                return filtered([.lats, .rhomboids])
            }
            if isLatPullName(normalized) {
                return filtered([.lats])
            }
            if isChestPressName(normalized) {
                return filtered(chestPrimaryRegions(for: normalized))
            }
            if present.contains(.lowerBack), present.contains(.abs) || present.contains(.obliques) {
                if isLowerBackDominantCoreName(normalized) {
                    return filtered([.lowerBack, .glutes])
                }
                return filtered([.abs, .obliques])
            }
            return regions
        }

        switch definition.movementSlot {
        case .horizontalPush:
            return filtered(chestPrimaryRegions(for: normalized))
        case .verticalPush:
            if isRearDeltDominantPullName(normalized) {
                return filtered([.rearDelts, .rhomboids, .traps])
            }
            return filtered([.frontSideDelts, .shoulders])
        case .horizontalPull, .verticalPull:
            if isRearDeltDominantPullName(normalized) {
                return filtered([.rearDelts, .rhomboids, .traps])
            }
            if isBackRowName(normalized) {
                return filtered([.lats, .rhomboids])
            }
            if isLatPullName(normalized) {
                return filtered([.lats])
            }
            return filtered([.lats, .rhomboids, .traps])
        case .squat:
            if isAdductorName(normalized) {
                return filtered([.adductors])
            }
            if isAbductorName(normalized) {
                return filtered([.abductors, .glutes])
            }
            if normalized.contains("leg extension") {
                return filtered([.quads])
            }
            if normalized.contains("sumo") || normalized.contains("cossack") || normalized.contains("lateral lunge") {
                return filtered([.quads, .glutes, .adductors])
            }
            return filtered([.quads, .glutes])
        case .hinge:
            if isAbductorName(normalized) {
                return filtered([.abductors, .glutes])
            }
            if normalized.contains("leg curl") || normalized.contains("nordic") {
                return filtered([.hamstrings])
            }
            return filtered([.hamstrings, .glutes, .lowerBack])
        case .arms:
            if normalized.contains("tricep")
                || normalized.contains("skull")
                || normalized.contains("extension")
                || normalized.contains("close grip") {
                return filtered([.triceps])
            }
            if normalized.contains("curl") {
                return filtered([.biceps, .forearms])
            }
            return filtered([.biceps, .triceps, .forearms])
        case .core:
            if isLowerBackDominantCoreName(normalized) {
                return filtered([.lowerBack, .glutes])
            }
            return filtered([.abs, .obliques])
        case .calves:
            return filtered([.calves])
        case .carry:
            return filtered([.forearms, .traps, .lowerBack])
        case .cardio, .mobility, .routine, .skill:
            return regions
        }
    }

    private static func isLowerBackDominantCoreName(_ normalized: String) -> Bool {
        normalized.contains("back extension")
            || normalized.contains("reverse hyper")
            || normalized.contains("superman")
            || normalized.contains("bird dog")
    }

    private static func chestPrimaryRegions(for normalized: String) -> [BodyRegion] {
        if normalized.contains("incline")
            || normalized.contains("low to high")
            || normalized.contains("low high") {
            return [.upperChest, .chest]
        }
        return [.midLowerChest, .chest]
    }

    private static func isChestPressName(_ normalized: String) -> Bool {
        normalized.contains("bench")
            || normalized.contains("chest press")
            || normalized.contains("pushup")
            || normalized.contains("dip")
            || normalized.contains("cable fly")
            || normalized.contains("dumbbell fly")
            || normalized.contains("pec dec")
            || normalized.contains("pec deck")
    }

    private static func isRearDeltDominantPullName(_ normalized: String) -> Bool {
        normalized.contains("face pull")
            || normalized.contains("rear delt")
            || normalized.contains("reverse pec")
            || normalized.contains("reverse fly")
            || normalized.contains("band pull apart")
    }

    private static func isBackRowName(_ normalized: String) -> Bool {
        normalized.contains("row") && !normalized.contains("upright row")
    }

    private static func isLatPullName(_ normalized: String) -> Bool {
        normalized.contains("pullup")
            || normalized.contains("chin up")
            || normalized.contains("pulldown")
            || normalized.contains("pullover")
    }

    private static func isAdductorName(_ normalized: String) -> Bool {
        normalized.contains("adductor") || normalized.contains("adduction")
    }

    private static func isAbductorName(_ normalized: String) -> Bool {
        normalized.contains("abductor")
            || normalized.contains("abduction")
            || normalized.contains("lateral band walk")
            || normalized.contains("monster walk")
            || normalized.contains("clamshell")
            || normalized.contains("side lying leg raise")
    }

    private static func bodyRegions(
        definition: MovementDefinition?,
        name: String,
        fallbackMuscleGroups: [MuscleGroup]
    ) -> [BodyRegion] {
        if let regions = definition?.bodyRegions, !regions.isEmpty {
            return refined(regions: regions, definition: definition, name: name)
        }
        let regions = bodyRegions(from: fallbackMuscleGroups)
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func bodyRegions(from muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest: return [.upperChest, .midLowerChest]
            case .back: return [.lats, .traps]
            case .shoulders: return [.frontSideDelts]
            case .arms: return [.biceps, .triceps, .forearms]
            case .forearms: return [.forearms]
            case .legs: return [.quads, .hamstrings, .glutes, .calves]
            case .glutes: return [.glutes]
            case .core: return [.abs, .obliques, .lowerBack]
            case .traps: return [.traps]
            case .lats: return [.lats]
            case .calves: return [.calves]
            case .neck: return []
            }
        }
    }

    private static func refined(
        regions: [BodyRegion],
        definition: MovementDefinition?,
        name: String
    ) -> [BodyRegion] {
        guard let definition else {
            return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
        }

        let normalized = MovementCatalog.normalized(name)
        let filtered: [BodyRegion]
        switch definition.movementSlot {
        case .horizontalPush, .verticalPush:
            filtered = regions.filter { $0 != .biceps }
        case .horizontalPull, .verticalPull:
            if isRearDeltDominantPullName(normalized) {
                filtered = regions.filter { [.rearDelts, .rhomboids, .traps].contains($0) }
            } else if isLatPullName(normalized) {
                filtered = regions.filter { [.lats, .biceps, .forearms, .traps].contains($0) }
            } else {
                filtered = regions.filter { $0 != .triceps }
            }
        case .squat where isAdductorName(normalized):
            filtered = regions.filter { $0 == .adductors }
        case .squat where isAbductorName(normalized):
            filtered = regions.filter { [.abductors, .glutes].contains($0) }
        case .squat where normalized.contains("leg extension"):
            filtered = regions.filter { $0 == .quads }
        case .hinge where isAbductorName(normalized):
            filtered = regions.filter { [.abductors, .glutes].contains($0) }
        case .hinge where normalized.contains("leg curl") || normalized.contains("nordic"):
            filtered = regions.filter { $0 == .hamstrings }
        case .arms where normalized.contains("curl"):
            filtered = regions.filter { $0 != .triceps }
        case .arms where normalized.contains("tricep")
            || normalized.contains("skull")
            || normalized.contains("extension")
            || normalized.contains("close grip"):
            filtered = regions.filter { $0 != .biceps }
        default:
            filtered = regions
        }

        let normalizedFiltered = filtered.isEmpty ? regions : filtered
        return Array(Set(normalizedFiltered)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func sorted(_ rows: [BodyRegion: BodyRegionTrainingLoad]) -> [BodyRegionTrainingLoad] {
        rows.values.sorted { $0.region.rawValue < $1.region.rawValue }
    }
}
