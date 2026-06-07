import Foundation

enum MovementRole: String, Codable, CaseIterable, Hashable, Sendable {
    case canonicalExercise
    case alias
    case skillTarget
    case skillDrill
    case cardioModality
    case carrySled
    case mobilityDuration
    case routineContainer
    case routineStep
}

enum MovementLoggerMode: String, Codable, CaseIterable, Hashable, Sendable {
    case strengthSets
    case bodyweightSets
    case skillAttempts
    case hold
    case cardio
    case carry
    case mobility
    case routinePlayer
}

enum MovementVariationTag: String, Codable, CaseIterable, Hashable, Sendable {
    case assisted
    case negative
    case tempo
    case weighted
    case strict
    case explosive
    case wallSupported
    case unilateral
    case elevated
    case interval
}

enum MovementRankTemplate: String, Codable, CaseIterable, Hashable, Sendable {
    case barbellStrength
    case machineStrength
    case bodyweightReps
    case weightedBodyweight
    case holdControl
    case carrySled
    case cardioPerformance
    case mobilityDuration
    case routineCompletion
    case unranked

    var displayName: String {
        switch self {
        case .barbellStrength: return "Barbell Strength"
        case .machineStrength: return "Machine / Cable Strength"
        case .bodyweightReps: return "Bodyweight Reps"
        case .weightedBodyweight: return "Weighted Bodyweight"
        case .holdControl: return "Hold / Control"
        case .carrySled: return "Carry / Sled"
        case .cardioPerformance: return "Cardio Performance"
        case .mobilityDuration: return "Mobility Duration"
        case .routineCompletion: return "Routine Completion"
        case .unranked: return "Unranked"
        }
    }
}

enum MovementEquipment: String, Codable, CaseIterable, Hashable, Sendable {
    case bodyweight
    case barbell
    case dumbbell
    case kettlebell
    case cable
    case machine
    case smithMachine
    case pullupBar
    case dipStation
    case rings
    case bench
    case box
    case band
    case sled
    case cardioMachine
    case mobilityTool
    case openSpace

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight"
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .kettlebell: return "Kettlebell"
        case .cable: return "Cable"
        case .machine: return "Machine"
        case .smithMachine: return "Smith Machine"
        case .pullupBar: return "Pull-Up Bar"
        case .dipStation: return "Dip Station"
        case .rings: return "Rings"
        case .bench: return "Bench"
        case .box: return "Box"
        case .band: return "Band"
        case .sled: return "Sled"
        case .cardioMachine: return "Cardio Machine"
        case .mobilityTool: return "Mobility Tool"
        case .openSpace: return "Open Space"
        }
    }
}

enum MovementDifficulty: String, Codable, CaseIterable, Hashable, Sendable {
    case beginner
    case intermediate
    case advanced
    case elite

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .elite: return "Elite"
        }
    }
}

enum MovementSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case squat
    case hinge
    case horizontalPush
    case verticalPush
    case horizontalPull
    case verticalPull
    case arms
    case core
    case calves
    case carry
    case cardio
    case mobility
    case routine
    case skill

    var displayName: String {
        switch self {
        case .squat: return "Squat / Quad"
        case .hinge: return "Hinge / Posterior"
        case .horizontalPush: return "Horizontal Push"
        case .verticalPush: return "Vertical Push"
        case .horizontalPull: return "Horizontal Pull"
        case .verticalPull: return "Vertical Pull"
        case .arms: return "Arms"
        case .core: return "Core"
        case .calves: return "Calves"
        case .carry: return "Carry"
        case .cardio: return "Cardio"
        case .mobility: return "Mobility"
        case .routine: return "Routine"
        case .skill: return "Skill"
        }
    }
}

struct MovementDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String
    var role: MovementRole
    var rankable: Bool
    var rankTemplate: MovementRankTemplate
    var blockKind: TrainingBlockKind
    var loggerMode: MovementLoggerMode
    var aliases: [String]
    var attributeWeights: [AttributeKey: Double]
    var canonicalExerciseName: String?
    var variantOfMovementId: String?
    var rankStandardMovementId: String
    var skillId: String?
    var cardioType: CardioType?
    var defaultMetric: TrainingMetricKind
    var equipment: [MovementEquipment]
    var difficulty: MovementDifficulty
    var muscleGroups: [MuscleGroup]
    var bodyRegions: [BodyRegion]
    var movementSlot: MovementSlot
    var substitutionGroup: String
    var skillAssociations: [String]
    var progressionFamily: String?
    var progressionTier: Int?
    var contraindicationTags: [String]

    init(
        id: String,
        displayName: String,
        role: MovementRole,
        rankable: Bool = true,
        rankTemplate: MovementRankTemplate = .unranked,
        blockKind: TrainingBlockKind,
        loggerMode: MovementLoggerMode,
        aliases: [String],
        attributeWeights: [AttributeKey: Double],
        canonicalExerciseName: String?,
        variantOfMovementId: String? = nil,
        rankStandardMovementId: String? = nil,
        skillId: String?,
        cardioType: CardioType?,
        defaultMetric: TrainingMetricKind,
        equipment: [MovementEquipment] = [],
        difficulty: MovementDifficulty = .beginner,
        muscleGroups: [MuscleGroup] = [],
        bodyRegions: [BodyRegion] = [],
        movementSlot: MovementSlot = .routine,
        substitutionGroup: String = "",
        skillAssociations: [String] = [],
        progressionFamily: String? = nil,
        progressionTier: Int? = nil,
        contraindicationTags: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.rankable = rankable
        self.rankTemplate = rankTemplate
        self.blockKind = blockKind
        self.loggerMode = loggerMode
        self.aliases = aliases
        self.attributeWeights = attributeWeights
        self.canonicalExerciseName = canonicalExerciseName
        self.variantOfMovementId = variantOfMovementId
        self.rankStandardMovementId = rankStandardMovementId ?? id
        self.skillId = skillId
        self.cardioType = cardioType
        self.defaultMetric = defaultMetric
        self.equipment = equipment
        self.difficulty = difficulty
        self.muscleGroups = muscleGroups
        self.bodyRegions = bodyRegions
        self.movementSlot = movementSlot
        self.substitutionGroup = substitutionGroup
        self.skillAssociations = skillAssociations
        self.progressionFamily = progressionFamily
        self.progressionTier = progressionTier
        self.contraindicationTags = contraindicationTags
    }
}

struct ResolvedMovement: Codable, Hashable, Sendable {
    var rawName: String
    var movementId: String
    var displayName: String
    var role: MovementRole
    var rankable: Bool
    var rankTemplate: MovementRankTemplate
    var blockKind: TrainingBlockKind
    var loggerMode: MovementLoggerMode
    var canonicalExerciseName: String?
    var variantOfMovementId: String?
    var rankStandardMovementId: String
    var skillId: String?
    var cardioType: CardioType?
    var movementSlot: MovementSlot
    var bodyRegions: [BodyRegion]
    var substitutionGroup: String
    var variationTags: Set<MovementVariationTag>

    /// True when the catalog couldn't match this name — it earns zero rank/XP/attributes.
    var isUnmatched: Bool { !rankable && movementId.hasPrefix("unresolved.") }
}

struct ResolvedTrainingMovement: Hashable, Sendable {
    var exact: MovementDefinition
    var standard: MovementDefinition?
}
