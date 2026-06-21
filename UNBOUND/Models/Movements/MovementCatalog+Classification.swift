import Foundation

extension MovementCatalog {
    static let variantRankStandardNames: [String: String] = [
        "lat pulldown neutral": "lat pulldown",
        "wide grip lat pulldown": "lat pulldown",
        "close grip lat pulldown": "lat pulldown",
        "reverse grip lat pulldown": "lat pulldown",
        "single arm pulldown": "lat pulldown",
        "low to high cable fly": "cable fly",
        "high to low cable fly": "cable fly",
        "plate loaded chest press": "machine chest press",
        "hammer strength chest press": "machine chest press",
        "converging chest press": "machine chest press",
        "plate loaded shoulder press": "seated machine press",
        "wide grip cable row": "cable row seated",
        "single arm cable row": "cable row seated",
        "plate loaded row": "machine row",
        "hammer strength row": "machine row",
        "hammer strength low row": "machine row",
        "machine chest supported row": "machine row",
        "rope cable curl": "cable curl",
        "rope hammer curl": "hammer curl",
        "straight bar tricep pushdown": "tricep pushdown",
        "rope tricep pushdown": "tricep pushdown",
        "rope overhead tricep extension": "overhead tricep extension",
        "single leg extension": "leg extension",
        "leg curl seated": "leg curl lying",
        "single leg curl": "leg curl lying",
        "smith machine calf raise": "standing calf raise",
        "leg press calf raise": "standing calf raise"
    ]

    static func variantOfMovementId(for exercise: CatalogExercise) -> String? {
        guard let baseName = variantRankStandardNames[normalized(exercise.name)] else { return nil }
        return "exercise.\(slug(baseName))"
    }

    static func rankStandardMovementId(for exercise: CatalogExercise) -> String {
        variantOfMovementId(for: exercise) ?? "exercise.\(slug(exercise.name))"
    }

    static let exerciseAttributeWeights: [String: [AttributeKey: Double]] = {
        guard let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AttributePayload.self, from: data)
        else { return [:] }

        return payload.exercises.mapValues { dict in
            var out: [AttributeKey: Double] = [:]
            if let value = dict.power, value > 0 { out[.power] = value }
            if let value = dict.vitality ?? dict.legacyAgility, value > 0 { out[.vitality] = value }
            if let value = dict.control, value > 0 { out[.control] = value }
            if let value = dict.endurance, value > 0 { out[.endurance] = value }
            if let value = dict.mobility, value > 0 { out[.mobility] = value }
            if let value = dict.explosiveness, value > 0 { out[.explosiveness] = value }
            return out
        }
    }()

    static func attributeWeights(for exerciseName: String) -> [AttributeKey: Double] {
        exerciseAttributeWeights[exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? [:]
    }

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
            if definition.equipment.contains(.machine) || definition.equipment.contains(.cable) { score += 50 }
        case .machines:
            if definition.equipment.contains(.machine) || definition.equipment.contains(.cable) || definition.equipment.contains(.smithMachine) { score -= 20 }
            if definition.equipment.contains(.barbell) || definition.equipment.contains(.dumbbell) { score += 50 }
        case .hybrid:
            break
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

    static func blockKind(for exercise: CatalogExercise) -> TrainingBlockKind {
        let name = normalized(exercise.name)
        let bodyweightNames: Set<String> = [
            "incline pushup", "pushup", "diamond pushup", "decline pushup",
            "pseudo planche pushup", "archer pushup", "pike pushup", "wall handstand pushup",
            "negative pullup", "assisted pullup band", "assisted pullup machine",
            "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
            "straight bar dip", "dip",
            "banded muscle up", "low bar muscle up transition", "assisted turnover freeze", "muscle up",
            "plank", "high plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever", "dragon flag", "hanging knee raise", "hanging leg raise",
            "captains chair knee raise", "captains chair leg raise", "bodyweight squat",
            "assisted squat", "parallel squat", "split squat", "walking lunge", "step up",
            "deep step up", "cossack squat", "partial pistol squat", "assisted pistol squat",
            "pistol squat", "weighted pistol", "assisted shrimp squat", "beginner shrimp squat",
            "intermediate shrimp squat", "shrimp squat", "two-hand shrimp squat",
            "elevated two-hand shrimp squat", "nordic curl negative", "nordic curl",
            "nordic curl arms overhead", "tuck one-leg nordic curl", "one-leg nordic curl",
            "bodyweight leg extension", "glute bridge", "inverted row", "prone shoulder raise", "ab wheel", "decline situp", "roman chair situp",
            "hollow rock", "jump squat"
        ]
        if bodyweightNames.contains(name) {
            return .bodyweight
        }
        return .strength
    }

    static func rankTemplate(for exercise: CatalogExercise) -> MovementRankTemplate {
        let name = normalized(exercise.name)
        let display = normalized(exercise.displayName)
        if display.contains("weighted") || name.contains("weighted") {
            return .weightedBodyweight
        }
        if name == "hollow rock" {
            return .bodyweightReps
        }
        let bodyweightRepControlNames: Set<String> = [
            "dragon flag", "hanging knee raise", "hanging leg raise",
            "captains chair knee raise", "captains chair leg raise"
        ]
        if bodyweightRepControlNames.contains(name) {
            return .bodyweightReps
        }
        let holdControlNames: Set<String> = [
            "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever"
        ]
        if display.contains("plank") || display.contains("hold") || display.contains("hollow") || holdControlNames.contains(name) || (display.contains("hang") && !bodyweightRepControlNames.contains(name)) {
            return .holdControl
        }
        if blockKind(for: exercise) == .bodyweight {
            return .bodyweightReps
        }
        if equipment(for: exercise).contains(where: { [.machine, .cable, .smithMachine].contains($0) }) {
            return .machineStrength
        }
        return .barbellStrength
    }

    static func equipment(for exercise: CatalogExercise) -> [MovementEquipment] {
        let name = normalized(exercise.displayName + " " + exercise.name)
        var equipment: Set<MovementEquipment> = []
        let isDumbbellVariant = name.contains("dumbbell")
        let isKettlebellVariant = name.contains("kettlebell")
        let isBandVariant = name.contains("band")
        let isMachineVariant = name.contains("machine")
            || name.contains("smith")
            || name.contains("cable")
            || name.contains("belt squat")
            || name.contains("plate loaded")
            || name.contains("hammer strength")
        let isBodyweightLegExtension = name.contains("bodyweight leg extension")
            || name.contains("reverse nordic")

        if name.contains("smith") { equipment.insert(.smithMachine) }
        if !isBandVariant,
           name.contains("barbell") || name.contains("safety bar") || name.contains("back squat") || name.contains("front squat") || name.contains("good morning") || name.contains("landmine") || name.contains("t bar row") || name.contains("meadows") || name.contains("pendlay") {
            equipment.insert(.barbell)
        }
        if !isDumbbellVariant,
           !isKettlebellVariant,
           !isBandVariant,
           !isMachineVariant,
           name.contains("deadlift") || name.contains("bench press") || name.contains("overhead press") || name.contains("hip thrust") {
            equipment.insert(.barbell)
        }
        if name.contains("dumbbell") || name.contains("arnold press") || name.contains("goblet") || name.contains("hammer curl") || name.contains("lateral raise") || name.contains("fly") || name.contains("weighted pistol") { equipment.insert(.dumbbell) }
        if name.contains("weighted pistol") { equipment.insert(.kettlebell) }
        if name.contains("kettlebell") { equipment.insert(.kettlebell) }
        if !isBandVariant,
           name.contains("cable") || name.contains("pulldown") || name.contains("pushdown") || name.contains("face pull") || name.contains("pallof") {
            equipment.insert(.cable)
        }
        if name.contains("machine") || name.contains("belt squat") || name.contains("plate loaded") || name.contains("hammer strength") || name.contains("converging") || name.contains("leg press") || name.contains("hack squat") || name.contains("pendulum") || name.contains("v squat") || name.contains("pec deck") || name.contains("leg curl") || (!isBodyweightLegExtension && name.contains("leg extension")) || name.contains("reverse hyper") || name.contains("glute ham") || name.contains("captain") { equipment.insert(.machine) }
        if name.contains("pullup") || name.contains("chin up") || name.contains("hanging") { equipment.insert(.pullupBar) }
        if name.contains("ab wheel") { equipment.insert(.mobilityTool) }
        if name.contains("dip") { equipment.insert(.dipStation) }
        if name.contains("ring") { equipment.insert(.rings) }
        if name.contains("bench") || name.contains("incline") || name.contains("decline") || name.contains("chest supported") { equipment.insert(.bench) }
        if name.contains("box") || name.contains("step up") { equipment.insert(.box) }
        if name.contains("band") { equipment.insert(.band) }

        if equipment.isEmpty || blockKind(for: exercise) == .bodyweight {
            equipment.insert(.bodyweight)
        }

        return equipment.sorted { $0.rawValue < $1.rawValue }
    }

    static func difficulty(for exercise: CatalogExercise) -> MovementDifficulty {
        let normalizedName = normalized(exercise.name)
        if normalizedName == "l sit tucked" {
            return .beginner
        }
        if normalizedName == "bodyweight leg extension" {
            return .intermediate
        }
        if normalizedName == "jump squat" {
            return .intermediate
        }

        if let tier = exercise.progressionTier {
            switch tier {
            case ..<2: return .beginner
            case 2...4: return .intermediate
            case 5...6: return .advanced
            default: return .elite
            }
        }

        let name = normalized(exercise.displayName + " " + exercise.name)
        if name.contains("one arm") || name.contains("one-leg") || name.contains("planche") || name.contains("nordic") || name.contains("pistol") || name.contains("shrimp") || name.contains("handstand") {
            return .advanced
        }
        if name.contains("deadlift") || name.contains("barbell") || name.contains("front squat") || name.contains("overhead press") || name.contains("dip") || name.contains("pullup") {
            return .intermediate
        }
        return .beginner
    }

    static func bodyRegions(for exercise: CatalogExercise) -> [BodyRegion] {
        let name = normalized(exercise.name)
        var regions = Set(bodyRegions(for: exercise.muscleGroups))

        let isChestIsolation = name.contains("chest fly")
            || name.contains("cable fly")
            || name.contains("dumbbell fly")
            || name.contains("pec dec")
            || name.contains("pec deck")
        let isUpperChestBias = name.contains("incline")
            || name.contains("low to high")
            || name.contains("low high")
        let isChestPress = name.contains("bench")
            || name.contains("chest press")
            || name.contains("pushup")
            || name.contains("dip")
            || isChestIsolation
        if isChestPress {
            regions.insert(isUpperChestBias ? .upperChest : .midLowerChest)
            if !isChestIsolation {
                regions.insert(.triceps)
                regions.insert(.frontSideDelts)
            }
        }

        if name.contains("overhead press") || name.contains("arnold press") || name.contains("handstand") || name.contains("pike") {
            regions.insert(.frontSideDelts)
            regions.insert(.triceps)
        }
        if name.contains("lateral raise") || name.contains("front raise") || name.contains("y raise") {
            regions.insert(.frontSideDelts)
        }
        if name.contains("upright row") {
            regions.insert(.frontSideDelts)
            regions.insert(.traps)
        }

        let isRearDeltIsolation = name.contains("rear delt")
            || name.contains("reverse pec")
            || name.contains("reverse fly")
            || name.contains("band pull apart")
            || name.contains("prone shoulder raise")
        if name.contains("face pull") || isRearDeltIsolation {
            regions.insert(.rearDelts)
            regions.insert(.rhomboids)
            regions.insert(.traps)
        }

        let isBackRow = name.contains("row") && !name.contains("upright row")
        if isBackRow {
            regions.insert(.lats)
            regions.insert(.rhomboids)
            regions.insert(.traps)
            regions.insert(.biceps)
            regions.insert(.forearms)
            if (name.contains("barbell") || name.contains("bent over") || name.contains("pendlay") || name.contains("meadows") || name.contains("landmine") || name.contains("t bar"))
                && !name.contains("chest supported")
                && !name.contains("machine") {
                regions.insert(.lowerBack)
            }
            if name.contains("high row") || name.contains("wide grip row") {
                regions.insert(.rearDelts)
            }
        }
        if name.contains("pullup") || name.contains("chin up") || name.contains("pulldown") || name.contains("pullover") {
            regions.insert(.lats)
            if !name.contains("straight arm") && !name.contains("pullover") {
                regions.insert(.biceps)
                regions.insert(.forearms)
            }
        }
        if name.contains("curl") {
            regions.insert(.biceps)
            if name.contains("hammer") || name.contains("rope") || name.contains("reverse") {
                regions.insert(.forearms)
            }
        }
        if name.contains("tricep") || name.contains("skull") || name.contains("close grip bench") {
            regions.insert(.triceps)
        }

        if name.contains("adductor") || name.contains("adduction") {
            regions.insert(.adductors)
        }
        if name.contains("abductor") || name.contains("abduction") || name.contains("lateral band walk") || name.contains("monster walk") || name.contains("clamshell") || name.contains("side lying leg raise") {
            regions.insert(.abductors)
            regions.insert(.glutes)
        }
        if name.contains("leg extension") {
            regions.insert(.quads)
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("lunge") || name.contains("step up") {
            regions.insert(.quads)
            regions.insert(.glutes)
            if name.contains("sumo") || name.contains("cossack") || name.contains("lateral") {
                regions.insert(.adductors)
            }
        }
        if name.contains("leg curl") || name.contains("nordic") {
            regions.insert(.hamstrings)
        }
        if name.contains("deadlift") || name.contains("rdl") || name.contains("good morning") || name.contains("glute ham") {
            regions.insert(.hamstrings)
            regions.insert(.glutes)
            regions.insert(.lowerBack)
            if name.contains("sumo") {
                regions.insert(.adductors)
            }
        }
        if name.contains("hip thrust") || name.contains("glute bridge") || name.contains("kickback") || name.contains("pull through") || name.contains("kettlebell swing") {
            regions.insert(.glutes)
            regions.insert(.hamstrings)
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("l sit") || name.contains("front lever") || name.contains("dragon flag") || name.contains("crunch") || name.contains("leg raise") || name.contains("knee raise") || name.contains("situp") || name.contains("ab wheel") {
            regions.insert(.abs)
        }
        if name.contains("pallof") || name.contains("rotation") || name.contains("cossack") {
            regions.insert(.obliques)
        }
        if name.contains("calf") || name.contains("tibialis") {
            regions.insert(.calves)
        }

        if isChestIsolation {
            regions = isUpperChestBias ? [.upperChest] : [.midLowerChest]
        } else if isChestPress {
            regions = isUpperChestBias
                ? [.upperChest, .triceps, .frontSideDelts]
                : [.midLowerChest, .triceps, .frontSideDelts]
        } else if name.contains("face pull") || isRearDeltIsolation {
            regions = [.rearDelts, .rhomboids, .traps]
        } else if name.contains("lateral raise") || name.contains("front raise") || name.contains("y raise") {
            regions = [.frontSideDelts]
        } else if name.contains("leg extension") {
            regions = [.quads]
        } else if name.contains("adductor") || name.contains("adduction") {
            regions = [.adductors]
        } else if name.contains("abductor") || name.contains("abduction") || name.contains("lateral band walk") || name.contains("monster walk") || name.contains("clamshell") || name.contains("side lying leg raise") {
            regions = [.abductors, .glutes]
        } else if name.contains("leg curl") || name.contains("nordic") {
            regions = [.hamstrings]
        } else if name.contains("curl") {
            regions = name.contains("hammer") || name.contains("rope") || name.contains("reverse")
                ? [.biceps, .forearms]
                : [.biceps]
        } else if (name.contains("tricep") || name.contains("skull") || name.contains("pushdown"))
                    && !name.contains("close grip bench") {
            regions = [.triceps]
        }

        return regions.sorted { $0.rawValue < $1.rawValue }
    }

    static func bodyRegions(for muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        let regions = muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest:
                return [.upperChest, .midLowerChest]
            case .back:
                return [.lats, .traps]
            case .shoulders:
                return [.frontSideDelts]
            case .arms:
                return [.biceps, .triceps]
            case .forearms:
                return [.forearms]
            case .legs:
                return [.quads, .hamstrings]
            case .glutes:
                return [.glutes]
            case .core:
                return [.abs, .obliques, .lowerBack]
            case .traps:
                return [.traps]
            case .lats:
                return [.lats]
            case .calves:
                return [.calves]
            case .neck:
                return []
            }
        }
        return Array(Set(regions)).sorted { $0.rawValue < $1.rawValue }
    }

    static func substitutionGroup(for exercise: CatalogExercise) -> String {
        let slot = movementSlot(for: exercise).rawValue
        let template = rankTemplate(for: exercise).rawValue
        return "\(slot).\(template)"
    }

    static func skillAssociations(for exercise: CatalogExercise) -> [String] {
        let name = normalized(exercise.name)
        var skills: Set<String> = []
        let verticalPullSkillNames: Set<String> = [
            "negative pullup", "assisted pullup band", "assisted pullup machine",
            "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
            "lat pulldown neutral", "wide grip lat pulldown", "close grip lat pulldown",
            "reverse grip lat pulldown", "lat pulldown", "single arm pulldown"
        ]
        if verticalPullSkillNames.contains(name) {
            skills.formUnion(["pp.pullup", "pp.strict-pullup"])
        }
        if name == "dip" || name == "straight bar dip" {
            skills.insert("pp.muscle-up")
        }
        if name.contains("pike") || name.contains("handstand") || name.contains("overhead press") {
            skills.formUnion(["hs.wall-handstand-30", "cal.handstand-pushup"])
        }
        if name.contains("pushup") || name.contains("bench") || name.contains("chest press") {
            skills.insert("cal.pushup")
        }
        if name == "assisted squat" || name == "parallel squat" || name == "bodyweight squat" || name == "cossack squat" {
            skills.insert("ld.deep-squat")
        }
        if name.contains("step up") {
            skills.insert("ld.step-up")
        }
        if name.contains("bulgarian split squat") {
            skills.formUnion(["ld.bulgarian-split-squat", "ld.pistol-squat"])
        } else if name.contains("split squat") {
            skills.formUnion(["ld.split-squat", "ld.pistol-squat"])
        }
        if name.contains("weighted pistol") {
            skills.insert("ld.weighted-pistol")
        } else if name.contains("pistol") {
            skills.insert("ld.pistol-squat")
        }
        if name.contains("shrimp") {
            skills.insert("ld.shrimp-squat")
        }
        if name.contains("nordic") || name.contains("leg curl") {
            skills.insert("ld.nordic-curl")
        }
        if name == "bodyweight leg extension" {
            skills.insert("ld.leg-extensions")
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("leg raise") || name.contains("knee raise") || name.contains("situp") {
            skills.insert("cl.hollow-body-30")
        }
        return skills.sorted()
    }

    static func contraindicationTags(for exercise: CatalogExercise) -> [String] {
        let name = normalized(exercise.displayName + " " + exercise.name)
        var tags: Set<String> = []
        if name.contains("squat") || name.contains("lunge") || name.contains("leg press") || name.contains("step up") || name.contains("pistol") {
            tags.insert("knee-sensitive")
        }
        if name.contains("deadlift") || name.contains("good morning") || name.contains("row") || name.contains("back extension") {
            tags.insert("low-back-sensitive")
        }
        if name.contains("overhead") || name.contains("dip") || name.contains("handstand") || name.contains("upright row") || name.contains("pullover") {
            tags.insert("shoulder-sensitive")
        }
        if name.contains("wrist") || name.contains("pushup") || name.contains("planche") {
            tags.insert("wrist-sensitive")
        }
        return tags.sorted()
    }

    static func loggerMode(for exercise: CatalogExercise) -> MovementLoggerMode {
        if rankTemplate(for: exercise) == .holdControl {
            return .hold
        }
        return blockKind(for: exercise) == .bodyweight ? .bodyweightSets : .strengthSets
    }

    static func defaultMetric(for exercise: CatalogExercise) -> TrainingMetricKind {
        loggerMode(for: exercise) == .hold ? .holdSeconds : .reps
    }

    static func exerciseAliases(for exercise: CatalogExercise) -> [String] {
        var aliases = [exercise.displayName, exercise.name]
        switch exercise.name {
        case "negative pullup":
            aliases += ["negative pull-up", "tempo negative pull-up", "eccentric pull-up", "pull-up negative"]
        case "assisted pullup (band)":
            aliases += ["band-assisted pull-up", "band assisted pull up", "assisted pull-up band", "assisted pull-up (band)", "banded pull-up"]
        case "assisted pullup machine":
            aliases += ["assisted pull-up machine", "machine assisted pull-up"]
        case "pullup":
            aliases += ["pull-up", "pull up", "strict pull-up", "strict pullup", "tempo pull-up"]
        case "chin up":
            aliases += ["chin-up", "strict chin-up", "weighted chin-up"]
        case "pushup":
            aliases += ["push-up", "push ups", "push-ups", "strict push-up", "tempo push-up"]
        case "pike pushup":
            aliases += ["pike push-up", "pike push ups", "pike hold"]
        case "inverted row":
            aliases += ["australian row", "ring row", "bodyweight row"]
        case "cable row (seated)":
            aliases += ["cable row", "seated row", "seated cable row"]
        case "band row":
            aliases += ["banded row", "light band row", "band row prep"]
        case "band lat pull":
            aliases += ["band lat pulldown", "band pulldown", "banded lat pulldown"]
        case "hanging knee raise":
            aliases += ["captain chair knee raise", "captain's chair knee raise"]
        case "hanging leg raise":
            aliases += ["captain chair leg raise", "captain's chair leg raise"]
        case "bodyweight squat":
            aliases += ["full squat", "air squat", "strict squat"]
        case "assisted squat":
            aliases += ["supported squat"]
        case "parallel squat":
            aliases += ["squat to parallel"]
        case "split squat":
            aliases += ["stationary lunge"]
        case "deep step up":
            aliases += ["high step up", "deep step-up", "high step-up"]
        case "partial pistol squat":
            aliases += ["box pistol", "box pistol squat", "partial pistol"]
        case "assisted pistol squat":
            aliases += ["pistol squat assisted", "supported pistol squat"]
        case "weighted pistol":
            aliases += ["weighted pistol squat", "loaded pistol squat"]
        case "beginner shrimp squat":
            aliases += ["beginner shrimp"]
        case "intermediate shrimp squat":
            aliases += ["int shrimp squat", "intermediate shrimp", "int shrimp"]
        case "two-hand shrimp squat":
            aliases += ["2-hand shrimp squat", "two hand shrimp squat", "2h shrimp squat"]
        case "elevated two-hand shrimp squat":
            aliases += ["elevated 2-hand shrimp squat", "elevated 2h shrimp squat", "deficit two-hand shrimp squat"]
        case "nordic curl negative":
            aliases += ["nordic negative", "negative nordic curl", "eccentric nordic curl"]
        case "nordic curl arms overhead":
            aliases += ["arms-overhead nordic curl", "overhead nordic curl"]
        case "tuck one-leg nordic curl":
            aliases += ["tuck one leg nordic curl", "tuck single-leg nordic curl"]
        case "one-leg nordic curl":
            aliases += ["one leg nordic curl", "single-leg nordic curl", "single leg nordic curl"]
        case "bodyweight leg extension":
            aliases += ["bodyweight leg extensions", "reverse nordic", "reverse-nordic", "reverse nordic curl", "kneeling leg extension"]
        case "plank":
            aliases += ["plank hold", "plank max hold"]
        default:
            break
        }
        return Array(Set(aliases))
    }

}
