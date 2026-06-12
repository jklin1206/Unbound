import Foundation

extension MovementCatalog {
    static let cardioDefinitions: [MovementDefinition] = CardioType.allCases.map { type in
        MovementDefinition(
            id: "cardio.\(type.rawValue)",
            displayName: type.displayName,
            role: .cardioModality,
            rankable: true,
            rankTemplate: .cardioPerformance,
            blockKind: .cardio,
            loggerMode: .cardio,
            aliases: cardioAliases(for: type),
            attributeWeights: [.endurance: 0.75, .power: 0.1, .control: 0.15],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: type,
            defaultMetric: .durationSeconds,
            equipment: cardioEquipment(for: type),
            difficulty: .beginner,
            muscleGroups: [.legs],
            bodyRegions: [.quads, .hamstrings, .glutes, .calves],
            movementSlot: .cardio,
            substitutionGroup: "cardio.\(type.rawValue)",
            skillAssociations: [],
            contraindicationTags: cardioContraindications(for: type)
        )
    }

    static func cardioAliases(for type: CardioType) -> [String] {
        switch type {
        case .run:
            return ["run", "running", "sprint", "easy run", "tempo run", "base run", "400m run", "10 km run"]
        case .bike:
            return ["bike", "cycling", "easy bike", "assault bike", "air bike", "easy bike flush"]
        case .row:
            return ["row", "rowing", "rower", "100m row repeat", "400m row", "technique row"]
        case .walk:
            return ["walk", "walking", "zone 2 walk", "sustained walk", "warm-up walk"]
        case .swim:
            return ["swim", "swimming"]
        case .stairs:
            return ["stairs", "stair climber", "stairmaster"]
        case .elliptical:
            return ["elliptical", "cross trainer"]
        }
    }

    static func cardioEquipment(for type: CardioType) -> [MovementEquipment] {
        switch type {
        case .run, .walk: return [.openSpace]
        case .bike, .row, .stairs, .elliptical: return [.cardioMachine]
        case .swim: return [.openSpace]
        }
    }

    static func cardioContraindications(for type: CardioType) -> [String] {
        switch type {
        case .run, .stairs: return ["knee-sensitive", "impact-sensitive"]
        case .row: return ["low-back-sensitive"]
        case .bike, .walk, .swim, .elliptical: return []
        }
    }

    static let carryDefinitions: [MovementDefinition] = [
        carry("farmer-carry", "Farmer Carry", aliases: ["farmer carry", "farmer hold", "bw farmer carry", "bodyweight farmer carry"]),
        carry("suitcase-carry", "Suitcase Carry", aliases: ["suitcase carry"]),
        carry("sled-push", "Sled Push", aliases: ["sled push", "light sled march", "short sled intervals", "wall lean march"]),
        carry("sandbag-carry", "Sandbag Carry", aliases: ["sandbag carry", "backpack carry"]),
        carry("loaded-march", "Loaded March", aliases: ["loaded march", "ruck", "ruck march"])
    ]

    static func carry(_ id: String, _ displayName: String, aliases: [String]) -> MovementDefinition {
        MovementDefinition(
            id: "carry.\(id)",
            displayName: displayName,
            role: .carrySled,
            rankable: true,
            rankTemplate: .carrySled,
            blockKind: .carry,
            loggerMode: .carry,
            aliases: aliases,
            attributeWeights: [.power: 0.4, .control: 0.3, .endurance: 0.3],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: nil,
            defaultMetric: .distanceMeters,
            equipment: displayName == "Sled Push" ? [.sled] : [.dumbbell, .kettlebell, .openSpace],
            difficulty: .intermediate,
            muscleGroups: [.forearms, .traps, .core, .legs],
            bodyRegions: [.forearms, .traps, .abs, .obliques, .lowerBack, .quads, .hamstrings, .glutes, .calves],
            movementSlot: .carry,
            substitutionGroup: "carry.loaded",
            skillAssociations: [],
            contraindicationTags: ["grip-sensitive", "low-back-sensitive"]
        )
    }

    static let mobilityDefinitions: [MovementDefinition] = [
        mobility(
            "hip-flexor-stretch",
            "Hip Flexor Stretch",
            aliases: ["hip flexor stretch", "couch stretch", "deep lunge hold"],
            muscleGroups: [.legs, .glutes],
            bodyRegions: [.quads, .glutes]
        ),
        mobility(
            "hamstring-fold",
            "Hamstring Fold",
            aliases: ["hamstring fold", "seated forward fold", "forward fold"],
            muscleGroups: [.legs, .glutes, .back],
            bodyRegions: [.hamstrings, .calves, .lowerBack]
        ),
        mobility(
            "pigeon-pose",
            "Pigeon Pose",
            aliases: ["pigeon pose", "figure-4", "figure 4"],
            muscleGroups: [.glutes, .legs],
            bodyRegions: [.glutes, .hamstrings, .lowerBack]
        ),
        mobility(
            "thoracic-rotation",
            "Thoracic Rotation",
            aliases: ["thoracic rotation", "thread the needle", "spinal twist"],
            muscleGroups: [.back, .core],
            bodyRegions: [.lats, .traps, .obliques]
        ),
        mobility(
            "cat-cow",
            "Cat-Cow",
            aliases: ["cat-cow", "cat cow"],
            muscleGroups: [.back, .core],
            bodyRegions: [.lowerBack, .abs]
        ),
        mobility(
            "frog-stretch",
            "Frog Stretch",
            aliases: ["frog stretch"],
            muscleGroups: [.legs, .glutes],
            bodyRegions: [.quads, .glutes]
        ),
        mobility(
            "wrist-prep",
            "Wrist Prep Flow",
            aliases: ["wrist prep flow", "wrist prep", "wrist conditioning", "reverse wrist stretch", "finger pressure rocks"],
            muscleGroups: [.forearms],
            bodyRegions: [.forearms]
        ),
        mobility(
            "shoulder-dislocates",
            "Shoulder Dislocates",
            aliases: ["shoulder dislocates", "shoulder opener", "shoulder circles"],
            muscleGroups: [.shoulders, .chest, .back],
            bodyRegions: [.shoulders, .chest, .lats]
        ),
        mobility(
            "deep-squat-hold",
            "Deep Squat Hold",
            aliases: ["deep squat hold", "resting squat", "deep squat"],
            muscleGroups: [.legs, .glutes, .core],
            bodyRegions: [.quads, .glutes, .calves, .lowerBack]
        ),
        mobility(
            "ankle-rocks",
            "Ankle Rocks",
            aliases: ["ankle rocks", "ankle mobility rocks", "knee to wall"],
            muscleGroups: [.calves, .legs],
            bodyRegions: [.calves, .quads]
        ),
        mobility(
            "standing-calf-stretch",
            "Standing Calf Stretch",
            aliases: ["standing calf stretch", "wall calf stretch", "calf stretch"],
            muscleGroups: [.calves],
            bodyRegions: [.calves]
        ),
        mobility(
            "quad-stretch",
            "Quad Stretch",
            aliases: ["quad stretch", "standing quad stretch", "couch quad stretch"],
            muscleGroups: [.legs, .glutes],
            bodyRegions: [.quads, .glutes]
        ),
        mobility(
            "doorway-pec-stretch",
            "Doorway Pec Stretch",
            aliases: ["doorway pec stretch", "doorway chest stretch", "pec stretch", "chest stretch"],
            muscleGroups: [.chest, .shoulders],
            bodyRegions: [.chest, .shoulders]
        ),
        mobility(
            "lat-stretch",
            "Lat Stretch",
            aliases: ["lat stretch", "bench lat stretch", "prayer lat stretch"],
            muscleGroups: [.lats, .back, .shoulders],
            bodyRegions: [.lats, .shoulders, .lowerBack]
        ),
        mobility(
            "childs-pose",
            "Child's Pose",
            aliases: ["child's pose", "childs pose", "kneeling lat stretch"],
            muscleGroups: [.back, .shoulders, .core],
            bodyRegions: [.lats, .shoulders, .lowerBack]
        ),
        mobility(
            "ninety-ninety-hip-switch",
            "90/90 Hip Switch",
            aliases: ["90/90 hip switch", "90 90 hip switch", "shin box switch"],
            muscleGroups: [.glutes, .legs, .core],
            bodyRegions: [.glutes, .hamstrings, .obliques]
        ),
        mobility(
            "cobra-stretch",
            "Cobra Stretch",
            aliases: ["cobra stretch", "upward dog", "press up stretch"],
            muscleGroups: [.core, .back],
            bodyRegions: [.abs, .lowerBack]
        ),
        mobility(
            "worlds-greatest-stretch",
            "World's Greatest Stretch",
            aliases: ["world's greatest stretch", "worlds greatest stretch", "hip opener flow", "lunge mobility", "runner lunge rotation"],
            muscleGroups: [.legs, .glutes, .back, .core],
            bodyRegions: [.quads, .hamstrings, .glutes, .lats, .obliques]
        )
    ]

    static func mobility(
        _ id: String,
        _ displayName: String,
        aliases: [String],
        muscleGroups: [MuscleGroup] = [.core],
        bodyRegions: [BodyRegion] = [.abs, .obliques, .lowerBack]
    ) -> MovementDefinition {
        MovementDefinition(
            id: "mobility.\(id)",
            displayName: displayName,
            role: .mobilityDuration,
            rankable: true,
            rankTemplate: .mobilityDuration,
            blockKind: .routine,
            loggerMode: .mobility,
            aliases: aliases,
            attributeWeights: [.mobility: 0.7, .control: 0.25, .endurance: 0.05],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: nil,
            defaultMetric: .durationSeconds,
            equipment: [.bodyweight, .mobilityTool],
            difficulty: .beginner,
            muscleGroups: muscleGroups,
            bodyRegions: bodyRegions,
            movementSlot: .mobility,
            substitutionGroup: "mobility.general",
            skillAssociations: [],
            contraindicationTags: ["pain-free-range-required"]
        )
    }

    static let skillDrillDefinitions: [MovementDefinition] = [
        skillDrill("wall-handstand", "Wall Handstand", aliases: ["wall handstand", "wall handstand hold", "wall handstand 60s", "wall handstand 30s", "wall handstand chest to wall"], skillId: "hs.wall-handstand-30"),
        skillDrill("freestanding-handstand", "Freestanding Handstand", aliases: ["freestanding handstand", "freestanding handstand attempts", "freestanding hs"], skillId: "hs.freestanding-hs-30"),
        skillDrill("wall-plank", "Wall Plank", aliases: ["wall plank"], skillId: "hs.wall-plank"),
        skillDrill("wall-shoulder-tap", "Wall Shoulder Tap", aliases: ["wall shoulder tap", "handstand shoulder tap"], skillId: "hs.wall-supported-oah"),
        skillDrill("kick-up-practice", "Kick-Up Practice", aliases: ["kick-up practice", "kick up practice", "kick-up practice against wall"], skillId: "hs.freestanding-hs-30"),
        skillDrill("crow-pose", "Crow Pose", aliases: ["crow pose", "one-foot crow float"], skillId: "hs.crow-pose"),
        skillDrill("headstand", "Headstand", aliases: ["headstand", "tripod base hold", "tuck headstand"], skillId: "hs.headstand"),
        skillDrill("planche-lean", "Planche Lean", aliases: ["planche lean", "planche lean hold", "feet-elevated planche lean"], skillId: "pl.tuck-planche"),
        skillDrill("frog-stand", "Frog Stand", aliases: ["frog stand", "frog stand hold"], skillId: "pl.tuck-planche"),
        skillDrill("band-assisted-tuck-planche", "Band-Assisted Tuck Planche", aliases: ["band-assisted tuck planche", "band assisted tuck planche", "banded tuck planche"], skillId: "pl.tuck-planche"),
        skillDrill("advanced-tuck-planche", "Advanced Tuck Planche", aliases: ["advanced tuck planche", "advanced tuck planche hold"], skillId: "pl.straddle-planche"),
        skillDrill("band-assisted-full-planche", "Band-Assisted Full Planche", aliases: ["band-assisted full planche", "band assisted full planche", "banded full planche"], skillId: "pl.full-planche"),
        skillDrill("tuck-l-sit", "Tuck L-Sit", aliases: ["tuck l-sit"], skillId: "cal.l-sit-10"),
        skillDrill("single-leg-l-sit", "Single-Leg L-Sit", aliases: ["single-leg l-sit", "one-leg l-sit", "one leg l-sit"], skillId: "cal.l-sit-10"),
        skillDrill("foot-supported-l-sit", "Foot-Supported L-Sit", aliases: ["foot-supported l-sit", "foot supported l-sit"], skillId: "cal.l-sit-10"),
        skillDrill("one-leg-front-lever", "One-Leg Front Lever", aliases: ["one-leg front lever", "one leg front lever"], skillId: "cl.straddle-front-lever"),
        skillDrill("advanced-tuck-back-lever", "Advanced Tuck Back Lever", aliases: ["advanced tuck back lever", "advanced tuck back lever hold"], skillId: "cl.straddle-back-lever"),
        skillDrill("one-leg-back-lever", "One-Leg Back Lever", aliases: ["one-leg back lever", "one leg back lever"], skillId: "cl.straddle-back-lever"),
        skillDrill("close-hand-straddle-handstand", "Close-Hand Straddle Handstand", aliases: ["close-hand straddle handstand", "close hand straddle handstand"], skillId: "hs.wall-supported-oah"),
        skillDrill("one-arm-handstand-weight-shift", "One-Arm Handstand Weight Shift", aliases: ["one-arm handstand weight shift", "wall one-arm weight shift", "wall oah weight shift"], skillId: "hs.wall-supported-oah"),
        skillDrill("two-finger-tent", "Two-Finger Tent", aliases: ["2-finger tent", "two-finger tent", "two finger tent"], skillId: "oah.one-arm-handstand-5s"),
        skillDrill("one-finger-tent", "One-Finger Tent", aliases: ["1-finger tent", "one-finger tent", "one finger tent"], skillId: "oah.one-arm-handstand-5s"),
        skillDrill("off-hand-float", "Off-Hand Float", aliases: ["off-hand float", "off hand float", "fingertip-lift", "fingertip lift", "one-arm fingertip hover"], skillId: "oah.one-arm-handstand-5s"),
        skillDrill("hollow-body-hold", "Hollow Body Hold", aliases: ["hollow body hold", "banana hold"], skillId: "cl.hollow-body-30")
    ]

    static let skillTreeDefinitions: [MovementDefinition] = SkillGraph.shared.nodes.map { node in
        MovementDefinition(
            id: "skill.\(node.id)",
            displayName: node.title,
            role: .skillTarget,
            rankable: false,
            rankTemplate: .unranked,
            blockKind: .skill,
            loggerMode: .skillAttempts,
            aliases: skillTreeAliases(for: node),
            attributeWeights: skillAttributeWeights(for: node),
            canonicalExerciseName: nil,
            skillId: node.id,
            cardioType: nil,
            defaultMetric: defaultMetric(for: node),
            equipment: movementEquipment(for: node.equipment),
            difficulty: difficulty(for: node),
            muscleGroups: Array(Set(node.primaryMuscles + node.secondaryMuscles)).sorted { $0.rawValue < $1.rawValue },
            bodyRegions: bodyRegions(for: Array(Set(node.primaryMuscles + node.secondaryMuscles))),
            movementSlot: .skill,
            substitutionGroup: "skill.\(node.cluster.rawValue)",
            skillAssociations: [node.id],
            progressionFamily: node.subChapter,
            progressionTier: node.tier,
            contraindicationTags: skillContraindicationTags(for: node)
        )
    }

    static func skillTreeAliases(for node: SkillNode) -> [String] {
        var aliases = Set<String>()
        aliases.insert(node.id)
        aliases.insert(node.title)
        aliases.insert(node.subtitle)
        aliases.insert(node.target.displayName)

        for criterion in node.tierCriteria.values {
            for exercise in exerciseNames(in: criterion) {
                aliases.insert(exercise)
            }
        }

        return aliases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    static func exerciseNames(in criterion: TierCriterion) -> [String] {
        switch criterion {
        case .reps(_, let exerciseName):
            return [exerciseName]
        case .exerciseSeconds(_, let exerciseName):
            return [exerciseName]
        case .exerciseWeightKg(_, let exerciseName):
            return [exerciseName]
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            _ = ratio
            return [exerciseName]
        case .variant(let name):
            return [name]
        case .compound(let criteria):
            return criteria.flatMap(exerciseNames)
        case .seconds, .weightKg, .bodyweightRatio:
            return []
        }
    }

    static func defaultMetric(for node: SkillNode) -> TrainingMetricKind {
        switch node.target {
        case .hold, .carry:
            return .holdSeconds
        case .steps, .reps, .weightMultiplier, .composite:
            return .reps
        }
    }

    static func skillAttributeWeights(for node: SkillNode) -> [AttributeKey: Double] {
        switch node.cluster {
        case .pullingPower:
            return [.power: 0.45, .control: 0.3, .endurance: 0.25]
        case .calisthenicControl, .planche, .handstand, .handstandPushup, .oneArmHandstand:
            return [.control: 0.55, .power: 0.25, .endurance: 0.2]
        case .coreLever:
            return [.control: 0.65, .power: 0.2, .endurance: 0.15]
        case .legDominance:
            return [.power: 0.45, .control: 0.35, .endurance: 0.2]
        case .conditioning:
            return [.endurance: 0.7, .power: 0.15, .control: 0.15]
        }
    }

    static func movementEquipment(for equipment: [SkillEquipment]) -> [MovementEquipment] {
        let mapped = equipment.flatMap { item -> [MovementEquipment] in
            switch item {
            case .bodyweight:
                return [.bodyweight]
            case .pullupBar:
                return [.pullupBar]
            case .gymnasticRings:
                return [.rings]
            case .barbell:
                return [.barbell]
            case .dumbbells:
                return [.dumbbell]
            case .parallettes:
                return [.bodyweight]
            case .kettlebell:
                return [.kettlebell]
            case .sled:
                return [.sled]
            case .rower:
                return [.cardioMachine]
            case .elevatedSurface:
                return [.bench, .box]
            }
        }
        let unique = Set(mapped.isEmpty ? [.bodyweight] : mapped)
        return unique.sorted { $0.rawValue < $1.rawValue }
    }

    static func difficulty(for node: SkillNode) -> MovementDifficulty {
        if node.isMythic || node.placementRank >= .ascendant || node.tier >= 7 {
            return .elite
        }
        switch node.tier {
        case ..<3:
            return .beginner
        case 3...4:
            return .intermediate
        case 5...6:
            return .advanced
        default:
            return .elite
        }
    }

    static func skillContraindicationTags(for node: SkillNode) -> [String] {
        var tags: Set<String> = []
        let muscles = Set(node.primaryMuscles + node.secondaryMuscles)
        if muscles.contains(.shoulders) || node.title.lowercased().contains("handstand") || node.title.lowercased().contains("dip") {
            tags.insert("shoulder-sensitive")
        }
        if node.title.lowercased().contains("handstand") || node.title.lowercased().contains("planche") || node.title.lowercased().contains("pushup") {
            tags.insert("wrist-sensitive")
        }
        if muscles.contains(.legs) || node.title.lowercased().contains("squat") || node.title.lowercased().contains("jump") {
            tags.insert("knee-sensitive")
        }
        if node.title.lowercased().contains("lever") || node.title.lowercased().contains("row") {
            tags.insert("low-back-sensitive")
        }
        return tags.sorted()
    }

    static func skillDrill(_ id: String, _ displayName: String, aliases: [String], skillId: String) -> MovementDefinition {
        MovementDefinition(
            id: "skill-drill.\(id)",
            displayName: displayName,
            role: .skillDrill,
            rankable: true,
            rankTemplate: .holdControl,
            blockKind: .skill,
            loggerMode: .skillAttempts,
            aliases: aliases,
            attributeWeights: [.control: 0.6, .power: 0.2, .endurance: 0.2],
            canonicalExerciseName: nil,
            skillId: skillId,
            cardioType: nil,
            defaultMetric: .holdSeconds,
            equipment: [.bodyweight],
            difficulty: .intermediate,
            muscleGroups: [.shoulders, .forearms, .core],
            bodyRegions: [.shoulders, .frontSideDelts, .forearms, .abs, .obliques, .lowerBack],
            movementSlot: .skill,
            substitutionGroup: "skill.\(skillId)",
            skillAssociations: [skillId],
            contraindicationTags: ["wrist-sensitive", "shoulder-sensitive"]
        )
    }

    static let routineDefinitions: [MovementDefinition] = RoutineLibrary.placeholderRoutines.map { routine in
        MovementDefinition(
            id: "routine.\(slug(routine.title))",
            displayName: routine.title,
            role: .routineContainer,
            rankable: false,
            rankTemplate: .routineCompletion,
            blockKind: .routine,
            loggerMode: .routinePlayer,
            aliases: [routine.id, routine.title],
            attributeWeights: [:],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: nil,
            defaultMetric: .durationSeconds,
            equipment: [.bodyweight],
            difficulty: .beginner,
            muscleGroups: [],
            bodyRegions: [],
            movementSlot: .routine,
            substitutionGroup: "routine.\(routine.category)",
            skillAssociations: []
        )
    }
}
