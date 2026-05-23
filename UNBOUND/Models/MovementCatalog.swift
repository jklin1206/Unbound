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

enum MovementStandardMetric: String, Codable, CaseIterable, Hashable, Sendable {
    case reps
    case holdSeconds
    case durationSeconds
    case distanceMeters
    case calories
    case loadBodyweightRatio
    case addedLoadBodyweightRatio
    case completionCount
}

enum MovementStandardComparison: String, Codable, CaseIterable, Hashable, Sendable {
    case atLeast
    case atMost
    case complete
}

struct MovementTierStandard: Codable, Hashable, Sendable {
    var tier: SkillTier
    var primaryMetric: MovementStandardMetric
    var primaryValue: Double
    var comparison: MovementStandardComparison
    var secondaryMetric: MovementStandardMetric?
    var secondaryValue: Double?
    var displayText: String
}

struct MovementStandardLadder: Identifiable, Codable, Hashable, Sendable {
    var id: String { movementId }

    var movementId: String
    var displayName: String
    var rankTemplate: MovementRankTemplate
    var tiers: [MovementTierStandard]
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
}

enum MovementCatalog {
    static let definitions: [MovementDefinition] = {
        var definitions = skillTreeDefinitions

        definitions.append(contentsOf: ExerciseCatalog.allExercises.map { exercise in
            MovementDefinition(
                id: "exercise.\(slug(exercise.name))",
                displayName: exercise.displayName,
                role: .canonicalExercise,
                rankable: true,
                rankTemplate: rankTemplate(for: exercise),
                blockKind: blockKind(for: exercise),
                loggerMode: loggerMode(for: exercise),
                aliases: exerciseAliases(for: exercise),
                attributeWeights: attributeWeights(for: exercise.name),
                canonicalExerciseName: exercise.name,
                variantOfMovementId: variantOfMovementId(for: exercise),
                rankStandardMovementId: rankStandardMovementId(for: exercise),
                skillId: nil,
                cardioType: nil,
                defaultMetric: defaultMetric(for: exercise),
                equipment: equipment(for: exercise),
                difficulty: difficulty(for: exercise),
                muscleGroups: exercise.muscleGroups,
                bodyRegions: bodyRegions(for: exercise),
                movementSlot: movementSlot(for: exercise),
                substitutionGroup: substitutionGroup(for: exercise),
                skillAssociations: skillAssociations(for: exercise),
                progressionFamily: exercise.progressionFamily,
                progressionTier: exercise.progressionTier,
                contraindicationTags: contraindicationTags(for: exercise)
            )
        })

        definitions.append(contentsOf: cardioDefinitions)
        definitions.append(contentsOf: carryDefinitions)
        definitions.append(contentsOf: mobilityDefinitions)
        definitions.append(contentsOf: skillDrillDefinitions)
        definitions.append(contentsOf: routineDefinitions)
        return definitions
    }()

    static var definitionsById: [String: MovementDefinition] {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    static var aliasIndex: [String: MovementDefinition] {
        var index: [String: MovementDefinition] = [:]
        for definition in definitions {
            index[normalized(definition.displayName)] = definition
            if let canonical = definition.canonicalExerciseName {
                index[normalized(canonical)] = definition
            }
            for alias in definition.aliases {
                index[normalized(alias)] = definition
            }
        }
        return index
    }

    static func definition(for id: String) -> MovementDefinition? {
        definitionsById[id]
    }

    static var loggableMovements: [MovementDefinition] {
        definitions.filter { $0.role != .routineStep }
    }

    static var rankStandards: [MovementDefinition] {
        definitions
            .filter { $0.rankable && $0.rankStandardMovementId == $0.id }
            .sorted { $0.displayName < $1.displayName }
    }

    static var loggableVariants: [MovementDefinition] {
        definitions
            .filter { $0.variantOfMovementId != nil }
            .sorted { $0.displayName < $1.displayName }
    }

    static var skillTargets: [MovementDefinition] {
        definitions.filter { $0.role == .skillTarget }
    }

    static var skillDrills: [MovementDefinition] {
        definitions.filter { $0.role == .skillDrill }
    }

    static var cardioMovements: [MovementDefinition] {
        definitions.filter { $0.role == .cardioModality }
    }

    static var carryMovements: [MovementDefinition] {
        definitions.filter { $0.role == .carrySled }
    }

    static var mobilityMovements: [MovementDefinition] {
        definitions.filter { $0.role == .mobilityDuration }
    }

    static var legacyExercises: [MovementDefinition] {
        definitions.filter { $0.role == .canonicalExercise }
    }

    static var catalogExercises: [CatalogExercise] {
        legacyExercises.compactMap(catalogExercise(for:))
    }

    static func canonicalExercise(named rawName: String) -> MovementDefinition? {
        let resolved = MovementResolver.resolve(rawName)
        guard let definition = definition(for: resolved.movementId),
              definition.role == .canonicalExercise
        else { return nil }
        return definition
    }

    static func catalogExercise(named rawName: String) -> CatalogExercise? {
        canonicalExercise(named: rawName).flatMap(catalogExercise(for:))
    }

    static func catalogExercise(for definition: MovementDefinition) -> CatalogExercise? {
        guard definition.role == .canonicalExercise,
              let canonicalName = definition.canonicalExerciseName
        else { return nil }

        if let legacy = ExerciseCatalog.exercise(named: canonicalName) {
            return CatalogExercise(
                name: legacy.name,
                displayName: definition.displayName,
                muscleGroups: definition.muscleGroups,
                defaultSubstitute: legacy.defaultSubstitute,
                progressionFamily: definition.progressionFamily,
                progressionTier: definition.progressionTier
            )
        }

        return CatalogExercise(
            name: canonicalName,
            displayName: definition.displayName,
            muscleGroups: definition.muscleGroups,
            defaultSubstitute: nil,
            progressionFamily: definition.progressionFamily,
            progressionTier: definition.progressionTier
        )
    }

    static func catalogExercises(for pattern: MovementPattern) -> [CatalogExercise] {
        let slot = movementSlot(for: pattern)
        return legacyExercises
            .filter { $0.movementSlot == slot }
            .sorted { exerciseSortKey($0) < exerciseSortKey($1) }
            .compactMap(catalogExercise(for:))
    }

    static func catalogProgressionFamily(_ family: String) -> [CatalogExercise] {
        legacyExercises
            .filter { $0.progressionFamily == family }
            .sorted { ($0.progressionTier ?? 0) < ($1.progressionTier ?? 0) }
            .compactMap(catalogExercise(for:))
    }

    static func catalogCalisthenicsPick(family: String, maxTier: Int = 0) -> CatalogExercise? {
        catalogProgressionFamily(family)
            .filter { ($0.progressionTier ?? 0) <= maxTier }
            .last
    }

    static func catalogAlternatives(to rawName: String) -> [CatalogExercise] {
        guard let current = canonicalExercise(named: rawName) else { return [] }

        return uniqueCatalogExercises(from: alternativeDefinitions(replacing: current))
    }

    static func programDefinitions(
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> [MovementDefinition] {
        legacyExercises
            .filter { isProgramCompatible($0, style: style, userEquipment: userEquipment) }
            .sorted { lhs, rhs in
                let lhsScore = programScore(lhs, style: style)
                let rhsScore = programScore(rhs, style: style)
                if lhsScore != rhsScore { return lhsScore < rhsScore }
                return lhs.displayName < rhs.displayName
            }
    }

    static func programDefinitions(
        for slot: MovementSlot,
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> [MovementDefinition] {
        programDefinitions(style: style, userEquipment: userEquipment)
            .filter { $0.movementSlot == slot }
    }

    static func programAlternatives(
        to rawName: String,
        style: TrainingStyle,
        userEquipment: [Equipment],
        excludedNames: Set<String> = []
    ) -> [MovementDefinition] {
        guard let current = canonicalExercise(named: rawName) else { return [] }
        let excluded = Set(excludedNames.map(normalized))
        return alternativeDefinitions(replacing: current)
            .filter { isProgramCompatible($0, style: style, userEquipment: userEquipment) }
            .filter { definition in
                guard let canonical = definition.canonicalExerciseName else { return false }
                return !excluded.contains(normalized(canonical))
                    && !excluded.contains(normalized(definition.displayName))
            }
    }

    static func catalogAlternatives(
        to rawName: String,
        style: TrainingStyle,
        userEquipment: [Equipment],
        excludedNames: Set<String> = []
    ) -> [CatalogExercise] {
        uniqueCatalogExercises(
            from: programAlternatives(
                to: rawName,
                style: style,
                userEquipment: userEquipment,
                excludedNames: excludedNames
            )
        )
    }

    static func catalogDefaultSubstitute(
        for rawName: String,
        style: TrainingStyle,
        userEquipment: [Equipment],
        excludedNames: Set<String> = []
    ) -> CatalogExercise? {
        catalogAlternatives(
            to: rawName,
            style: style,
            userEquipment: userEquipment,
            excludedNames: excludedNames
        ).first
    }

    static func isProgramCompatible(
        _ definition: MovementDefinition,
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> Bool {
        guard definition.role == .canonicalExercise else { return false }

        let equipment = userEquipment.isEmpty ? [.bodyweight] : userEquipment
        let required = requiredProgramEquipment(for: definition)

        if style == .bodyweight {
            let loadedEquipment: Set<MovementEquipment> = [
                .barbell, .dumbbell, .kettlebell, .cable, .machine,
                .smithMachine, .sled, .cardioMachine
            ]
            if !required.isDisjoint(with: loadedEquipment) {
                return false
            }
            if definition.rankTemplate == .weightedBodyweight && !hasExternalLoadCapability(equipment) {
                return false
            }
        }

        if equipment.contains(.fullGym) {
            return true
        }

        if required.isEmpty {
            return true
        }

        let capabilities = movementCapabilities(for: equipment)
        return required.isSubset(of: capabilities)
    }

    static func rankStandard(for definition: MovementDefinition) -> MovementDefinition? {
        definitionsById[definition.rankStandardMovementId]
    }

    static var movementStandardLadders: [MovementStandardLadder] {
        rankStandards.compactMap { standardLadder(for: $0) }
    }

    static func standardLadder(for definition: MovementDefinition) -> MovementStandardLadder? {
        guard let standard = rankStandard(for: definition),
              standard.rankable,
              standard.rankTemplate != .unranked
        else { return nil }

        let tiers = tierStandards(for: standard)
        guard !tiers.isEmpty else { return nil }
        return MovementStandardLadder(
            movementId: standard.id,
            displayName: standard.displayName,
            rankTemplate: standard.rankTemplate,
            tiers: tiers
        )
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func slug(_ value: String) -> String {
        normalized(value).replacingOccurrences(of: " ", with: "-")
    }

    private static func tierStandards(for definition: MovementDefinition) -> [MovementTierStandard] {
        switch definition.rankTemplate {
        case .barbellStrength:
            return strengthRatioStandards(
                ratios: [0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75, 2.00, 2.25],
                reps: [5, 5, 5, 5, 3, 3, 2, 1, 1]
            )
        case .machineStrength:
            return strengthRatioStandards(
                ratios: [0.30, 0.45, 0.60, 0.80, 1.00, 1.20, 1.45, 1.70, 2.00],
                reps: [10, 10, 8, 8, 6, 6, 5, 3, 3]
            )
        case .bodyweightReps:
            return singleMetricStandards(
                metric: .reps,
                values: [1, 3, 6, 10, 15, 20, 25, 30, 40],
                unit: "clean reps"
            )
        case .weightedBodyweight:
            return addedLoadStandards(
                ratios: [0.05, 0.10, 0.15, 0.25, 0.35, 0.50, 0.75, 1.00, 1.25],
                reps: [5, 5, 5, 5, 3, 3, 2, 1, 1]
            )
        case .holdControl:
            return singleMetricStandards(
                metric: .holdSeconds,
                values: [10, 20, 30, 45, 60, 75, 90, 120, 180],
                unit: "clean seconds"
            )
        case .carrySled:
            return carryStandards()
        case .cardioPerformance:
            return singleMetricStandards(
                metric: .durationSeconds,
                values: [600, 900, 1_200, 1_800, 2_700, 3_600, 5_400, 7_200, 10_800],
                unit: "sustained seconds"
            )
        case .mobilityDuration:
            return singleMetricStandards(
                metric: .durationSeconds,
                values: [30, 45, 60, 75, 90, 120, 150, 180, 240],
                unit: "quality seconds"
            )
        case .routineCompletion:
            return singleMetricStandards(
                metric: .completionCount,
                values: [1, 3, 5, 10, 20, 35, 50, 75, 100],
                unit: "clean completions"
            )
        case .unranked:
            return []
        }
    }

    private static func strengthRatioStandards(ratios: [Double], reps: [Double]) -> [MovementTierStandard] {
        zip(SkillTier.allCases, zip(ratios, reps)).map { tier, target in
            MovementTierStandard(
                tier: tier,
                primaryMetric: .loadBodyweightRatio,
                primaryValue: target.0,
                comparison: .atLeast,
                secondaryMetric: .reps,
                secondaryValue: target.1,
                displayText: "\(formatRatio(target.0))x BW x \(Int(target.1))"
            )
        }
    }

    private static func addedLoadStandards(ratios: [Double], reps: [Double]) -> [MovementTierStandard] {
        zip(SkillTier.allCases, zip(ratios, reps)).map { tier, target in
            MovementTierStandard(
                tier: tier,
                primaryMetric: .addedLoadBodyweightRatio,
                primaryValue: target.0,
                comparison: .atLeast,
                secondaryMetric: .reps,
                secondaryValue: target.1,
                displayText: "+\(formatRatio(target.0))x BW x \(Int(target.1))"
            )
        }
    }

    private static func singleMetricStandards(
        metric: MovementStandardMetric,
        values: [Double],
        unit: String
    ) -> [MovementTierStandard] {
        zip(SkillTier.allCases, values).map { tier, value in
            MovementTierStandard(
                tier: tier,
                primaryMetric: metric,
                primaryValue: value,
                comparison: .atLeast,
                secondaryMetric: nil,
                secondaryValue: nil,
                displayText: "\(formatStandardValue(value)) \(standardUnit(unit, value: value))"
            )
        }
    }

    private static func carryStandards() -> [MovementTierStandard] {
        let targets: [(Double, Double)] = [
            (0.25, 20), (0.50, 30), (0.75, 40),
            (1.00, 40), (1.25, 50), (1.50, 50),
            (1.75, 60), (2.00, 60), (2.25, 80)
        ]
        return zip(SkillTier.allCases, targets).map { tier, target in
            MovementTierStandard(
                tier: tier,
                primaryMetric: .loadBodyweightRatio,
                primaryValue: target.0,
                comparison: .atLeast,
                secondaryMetric: .distanceMeters,
                secondaryValue: target.1,
                displayText: "\(formatRatio(target.0))x BW for \(Int(target.1))m"
            )
        }
    }

    private static func formatRatio(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }

    private static func formatStandardValue(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private static func standardUnit(_ unit: String, value: Double) -> String {
        if value == 1, unit == "clean reps" {
            return "clean rep"
        }
        if value == 1, unit == "clean completions" {
            return "clean completion"
        }
        return unit
    }

    private static let variantRankStandardNames: [String: String] = [
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

    private static func variantOfMovementId(for exercise: CatalogExercise) -> String? {
        guard let baseName = variantRankStandardNames[normalized(exercise.name)] else { return nil }
        return "exercise.\(slug(baseName))"
    }

    private static func rankStandardMovementId(for exercise: CatalogExercise) -> String {
        variantOfMovementId(for: exercise) ?? "exercise.\(slug(exercise.name))"
    }

    private static let exerciseAttributeWeights: [String: [AttributeKey: Double]] = {
        guard let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AttributePayload.self, from: data)
        else { return [:] }

        return payload.exercises.mapValues { dict in
            var out: [AttributeKey: Double] = [:]
            if let value = dict.power, value > 0 { out[.power] = value }
            if let value = dict.agility, value > 0 { out[.agility] = value }
            if let value = dict.control, value > 0 { out[.control] = value }
            if let value = dict.endurance, value > 0 { out[.endurance] = value }
            if let value = dict.mobility, value > 0 { out[.mobility] = value }
            if let value = dict.explosiveness, value > 0 { out[.explosiveness] = value }
            return out
        }
    }()

    private static func attributeWeights(for exerciseName: String) -> [AttributeKey: Double] {
        exerciseAttributeWeights[exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] ?? [:]
    }

    private static func movementSlot(for exercise: CatalogExercise) -> MovementSlot {
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

    private static func movementSlot(for pattern: MovementPattern) -> MovementSlot {
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

    private static func exerciseSortKey(_ definition: MovementDefinition) -> String {
        let tier = definition.progressionTier ?? 999
        return String(format: "%03d-%@", tier, definition.displayName)
    }

    private static func alternativeScore(_ candidate: MovementDefinition, replacing current: MovementDefinition) -> Int {
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

    private static func alternativeDefinitions(replacing current: MovementDefinition) -> [MovementDefinition] {
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

    private static func uniqueCatalogExercises(from definitions: [MovementDefinition]) -> [CatalogExercise] {
        var seen: Set<String> = []
        return definitions.compactMap(catalogExercise(for:)).filter { exercise in
            guard !seen.contains(exercise.name) else { return false }
            seen.insert(exercise.name)
            return true
        }
    }

    private static func programScore(_ definition: MovementDefinition, style: TrainingStyle) -> Int {
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

    private static func difficultyScore(_ difficulty: MovementDifficulty) -> Int {
        switch difficulty {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        case .elite: return 3
        }
    }

    private static func requiredProgramEquipment(for definition: MovementDefinition) -> Set<MovementEquipment> {
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

    private static func movementCapabilities(for equipment: [Equipment]) -> Set<MovementEquipment> {
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
                capabilities.formUnion([.pullupBar, .dipStation, .rings])
            case .bodyweight:
                capabilities.formUnion([.bodyweight, .openSpace])
            case .bands:
                capabilities.insert(.band)
            case .homeWeights:
                capabilities.formUnion([
                    .bodyweight, .openSpace, .barbell, .dumbbell, .kettlebell,
                    .bench, .box, .band, .pullupBar, .dipStation
                ])
            }
        }

        return capabilities
    }

    private static func hasExternalLoadCapability(_ equipment: [Equipment]) -> Bool {
        equipment.contains(.fullGym)
            || equipment.contains(.homeWeights)
            || equipment.contains(.barbell)
            || equipment.contains(.dumbbells)
            || equipment.contains(.machines)
    }

    private static func pattern(for exerciseName: String) -> MovementPattern? {
        let key = exerciseName.lowercased()
        return MovementPattern.allCases.first { pattern in
            (ExerciseCatalog.exercisesByPattern[pattern] ?? []).contains { $0.name == key }
        }
    }

    private static func blockKind(for exercise: CatalogExercise) -> TrainingBlockKind {
        let name = normalized(exercise.name)
        let bodyweightNames: Set<String> = [
            "incline pushup", "pushup", "diamond pushup", "decline pushup",
            "pseudo planche pushup", "archer pushup", "pike pushup", "wall handstand pushup",
            "negative pullup", "assisted pullup band", "assisted pullup machine",
            "chin up", "pullup", "wide grip pullup", "weighted pullup", "chest to bar pullup",
            "straight bar dip", "dip",
            "banded muscle up", "low bar muscle up transition", "assisted turnover freeze", "muscle up",
            "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever", "dragon flag", "hanging knee raise", "hanging leg raise",
            "captains chair knee raise", "captains chair leg raise", "bodyweight squat",
            "walking lunge", "step up", "cossack squat", "pistol squat", "shrimp squat",
            "nordic curl", "inverted row", "ab wheel", "decline situp", "roman chair situp",
            "hollow rock", "jump squat", "assisted pistol squat", "assisted shrimp squat"
        ]
        if bodyweightNames.contains(name) {
            return .bodyweight
        }
        return .strength
    }

    private static func rankTemplate(for exercise: CatalogExercise) -> MovementRankTemplate {
        let name = normalized(exercise.name)
        let display = normalized(exercise.displayName)
        if display.contains("weighted") || name.contains("weighted") {
            return .weightedBodyweight
        }
        if name == "hollow rock" {
            return .bodyweightReps
        }
        let holdControlNames: Set<String> = [
            "plank", "hollow hold", "l sit tucked", "l sit", "tuck front lever",
            "advanced tuck front lever", "dragon flag", "hanging leg raise"
        ]
        if display.contains("plank") || display.contains("hang") || display.contains("hold") || display.contains("hollow") || holdControlNames.contains(name) {
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

    private static func equipment(for exercise: CatalogExercise) -> [MovementEquipment] {
        let name = normalized(exercise.displayName + " " + exercise.name)
        var equipment: Set<MovementEquipment> = []
        let isDumbbellVariant = name.contains("dumbbell")
        let isKettlebellVariant = name.contains("kettlebell")
        let isMachineVariant = name.contains("machine")
            || name.contains("smith")
            || name.contains("cable")
            || name.contains("plate loaded")
            || name.contains("hammer strength")

        if name.contains("smith") { equipment.insert(.smithMachine) }
        if name.contains("barbell") || name.contains("safety bar") || name.contains("back squat") || name.contains("front squat") || name.contains("good morning") || name.contains("landmine") || name.contains("t bar row") {
            equipment.insert(.barbell)
        }
        if !isDumbbellVariant,
           !isKettlebellVariant,
           !isMachineVariant,
           name.contains("deadlift") || name.contains("bench press") || name.contains("overhead press") || name.contains("hip thrust") {
            equipment.insert(.barbell)
        }
        if name.contains("dumbbell") || name.contains("arnold press") || name.contains("goblet") || name.contains("hammer curl") || name.contains("lateral raise") || name.contains("fly") { equipment.insert(.dumbbell) }
        if name.contains("kettlebell") { equipment.insert(.kettlebell) }
        if name.contains("cable") || name.contains("pulldown") || name.contains("pushdown") || name.contains("face pull") || name.contains("pallof") { equipment.insert(.cable) }
        if name.contains("machine") || name.contains("plate loaded") || name.contains("hammer strength") || name.contains("converging") || name.contains("leg press") || name.contains("hack squat") || name.contains("pendulum") || name.contains("v squat") || name.contains("pec deck") || name.contains("leg curl") || name.contains("leg extension") || name.contains("reverse hyper") || name.contains("glute ham") || name.contains("captain") { equipment.insert(.machine) }
        if name.contains("pullup") || name.contains("chin up") || name.contains("hanging") { equipment.insert(.pullupBar) }
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

    private static func difficulty(for exercise: CatalogExercise) -> MovementDifficulty {
        let normalizedName = normalized(exercise.name)
        if normalizedName == "l sit tucked" {
            return .beginner
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
        if name.contains("one arm") || name.contains("planche") || name.contains("nordic") || name.contains("pistol") || name.contains("shrimp") || name.contains("handstand") {
            return .advanced
        }
        if name.contains("deadlift") || name.contains("barbell") || name.contains("front squat") || name.contains("overhead press") || name.contains("dip") || name.contains("pullup") {
            return .intermediate
        }
        return .beginner
    }

    private static func bodyRegions(for exercise: CatalogExercise) -> [BodyRegion] {
        let name = normalized(exercise.name)
        var regions = Set(bodyRegions(for: exercise.muscleGroups))

        if name.contains("bench") || name.contains("chest press") || name.contains("fly") || name.contains("pushup") || name.contains("dip") || name == "pec dec" {
            regions.insert(.chest)
            regions.insert(.triceps)
            regions.insert(.shoulders)
        }
        if name.contains("overhead press") || name.contains("arnold press") || name.contains("lateral raise") || name.contains("front raise") || name.contains("y raise") || name.contains("handstand") || name.contains("pike") {
            regions.insert(.shoulders)
            regions.insert(.triceps)
        }
        if name.contains("row") || name.contains("pullup") || name.contains("chin up") || name.contains("pulldown") || name.contains("pullover") || name.contains("face pull") {
            regions.insert(.lats)
            regions.insert(.traps)
            regions.insert(.biceps)
            regions.insert(.forearms)
        }
        if name.contains("curl") {
            regions.insert(.biceps)
            if name.contains("hammer") || name.contains("rope") {
                regions.insert(.forearms)
            }
        }
        if name.contains("tricep") || name.contains("skull") || name.contains("close grip bench") {
            regions.insert(.triceps)
        }
        if name.contains("squat") || name.contains("leg press") || name.contains("lunge") || name.contains("step up") || name.contains("leg extension") || name.contains("adductor") {
            regions.insert(.quads)
            regions.insert(.glutes)
        }
        if name.contains("deadlift") || name.contains("rdl") || name.contains("leg curl") || name.contains("nordic") || name.contains("good morning") || name.contains("glute ham") {
            regions.insert(.hamstrings)
            regions.insert(.glutes)
            regions.insert(.lowerBack)
        }
        if name.contains("hip thrust") || name.contains("glute") || name.contains("abductor") || name.contains("kickback") || name.contains("pull through") || name.contains("kettlebell swing") {
            regions.insert(.glutes)
            regions.insert(.hamstrings)
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("l sit") || name.contains("front lever") || name.contains("dragon flag") || name.contains("crunch") || name.contains("raise") || name.contains("situp") || name.contains("ab wheel") {
            regions.insert(.abs)
        }
        if name.contains("pallof") || name.contains("rotation") || name.contains("cossack") {
            regions.insert(.obliques)
        }
        if name.contains("calf") || name.contains("tibialis") {
            regions.insert(.calves)
        }

        return regions.sorted { $0.rawValue < $1.rawValue }
    }

    private static func bodyRegions(for muscleGroups: [MuscleGroup]) -> [BodyRegion] {
        let regions = muscleGroups.flatMap { group -> [BodyRegion] in
            switch group {
            case .chest:
                return [.chest]
            case .back:
                return [.lats, .traps, .lowerBack]
            case .shoulders:
                return [.shoulders]
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

    private static func substitutionGroup(for exercise: CatalogExercise) -> String {
        let slot = movementSlot(for: exercise).rawValue
        let template = rankTemplate(for: exercise).rawValue
        return "\(slot).\(template)"
    }

    private static func skillAssociations(for exercise: CatalogExercise) -> [String] {
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
        if name.contains("pistol") || name.contains("shrimp") || name.contains("split squat") || name.contains("step up") {
            skills.insert("ld.pistol-squat")
        }
        if name.contains("nordic") || name.contains("leg curl") {
            skills.insert("ld.nordic-curl")
        }
        if name.contains("plank") || name.contains("hollow") || name.contains("leg raise") || name.contains("knee raise") || name.contains("situp") {
            skills.insert("cl.hollow-body-30")
        }
        return skills.sorted()
    }

    private static func contraindicationTags(for exercise: CatalogExercise) -> [String] {
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

    private static func loggerMode(for exercise: CatalogExercise) -> MovementLoggerMode {
        if rankTemplate(for: exercise) == .holdControl {
            return .hold
        }
        return blockKind(for: exercise) == .bodyweight ? .bodyweightSets : .strengthSets
    }

    private static func defaultMetric(for exercise: CatalogExercise) -> TrainingMetricKind {
        loggerMode(for: exercise) == .hold ? .holdSeconds : .reps
    }

    private static func exerciseAliases(for exercise: CatalogExercise) -> [String] {
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
        case "hanging knee raise":
            aliases += ["captain chair knee raise", "captain's chair knee raise"]
        case "hanging leg raise":
            aliases += ["captain chair leg raise", "captain's chair leg raise"]
        case "plank":
            aliases += ["plank hold", "plank max hold"]
        default:
            break
        }
        return Array(Set(aliases))
    }

    private static let cardioDefinitions: [MovementDefinition] = CardioType.allCases.map { type in
        MovementDefinition(
            id: "cardio.\(type.rawValue)",
            displayName: type.displayName,
            role: .cardioModality,
            rankable: true,
            rankTemplate: .cardioPerformance,
            blockKind: .cardio,
            loggerMode: .cardio,
            aliases: cardioAliases(for: type),
            attributeWeights: [.endurance: 0.7, .agility: 0.15, .power: 0.1, .control: 0.05],
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

    private static func cardioAliases(for type: CardioType) -> [String] {
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

    private static func cardioEquipment(for type: CardioType) -> [MovementEquipment] {
        switch type {
        case .run, .walk: return [.openSpace]
        case .bike, .row, .stairs, .elliptical: return [.cardioMachine]
        case .swim: return [.openSpace]
        }
    }

    private static func cardioContraindications(for type: CardioType) -> [String] {
        switch type {
        case .run, .stairs: return ["knee-sensitive", "impact-sensitive"]
        case .row: return ["low-back-sensitive"]
        case .bike, .walk, .swim, .elliptical: return []
        }
    }

    private static let carryDefinitions: [MovementDefinition] = [
        carry("farmer-carry", "Farmer Carry", aliases: ["farmer carry", "farmer hold", "bw farmer carry", "bodyweight farmer carry"]),
        carry("suitcase-carry", "Suitcase Carry", aliases: ["suitcase carry"]),
        carry("sled-push", "Sled Push", aliases: ["sled push", "light sled march", "short sled intervals", "wall lean march"]),
        carry("sandbag-carry", "Sandbag Carry", aliases: ["sandbag carry", "backpack carry"]),
        carry("loaded-march", "Loaded March", aliases: ["loaded march", "ruck", "ruck march"])
    ]

    private static func carry(_ id: String, _ displayName: String, aliases: [String]) -> MovementDefinition {
        MovementDefinition(
            id: "carry.\(id)",
            displayName: displayName,
            role: .carrySled,
            rankable: true,
            rankTemplate: .carrySled,
            blockKind: .carry,
            loggerMode: .carry,
            aliases: aliases,
            attributeWeights: [.power: 0.4, .control: 0.25, .endurance: 0.25, .mobility: 0.1],
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

    private static let mobilityDefinitions: [MovementDefinition] = [
        mobility("hip-flexor-stretch", "Hip Flexor Stretch", aliases: ["hip flexor stretch", "couch stretch", "deep lunge hold"]),
        mobility("hamstring-fold", "Hamstring Fold", aliases: ["hamstring fold", "seated forward fold", "forward fold"]),
        mobility("pigeon-pose", "Pigeon Pose", aliases: ["pigeon pose", "figure-4", "figure 4"]),
        mobility("thoracic-rotation", "Thoracic Rotation", aliases: ["thoracic rotation", "thread the needle", "spinal twist"]),
        mobility("cat-cow", "Cat-Cow", aliases: ["cat-cow", "cat cow"]),
        mobility("frog-stretch", "Frog Stretch", aliases: ["frog stretch"]),
        mobility("wrist-prep", "Wrist Prep Flow", aliases: ["wrist prep flow", "wrist conditioning", "reverse wrist stretch", "finger pressure rocks"]),
        mobility("shoulder-dislocates", "Shoulder Dislocates", aliases: ["shoulder dislocates", "shoulder circles"])
    ]

    private static func mobility(_ id: String, _ displayName: String, aliases: [String]) -> MovementDefinition {
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
            muscleGroups: [.core],
            bodyRegions: [.abs, .obliques, .lowerBack],
            movementSlot: .mobility,
            substitutionGroup: "mobility.general",
            skillAssociations: [],
            contraindicationTags: ["pain-free-range-required"]
        )
    }

    private static let skillDrillDefinitions: [MovementDefinition] = [
        skillDrill("wall-handstand", "Wall Handstand", aliases: ["wall handstand", "wall handstand hold", "wall handstand 60s", "wall handstand 30s", "wall handstand chest to wall"], skillId: "hs.wall-handstand-30"),
        skillDrill("freestanding-handstand", "Freestanding Handstand", aliases: ["freestanding handstand", "freestanding handstand attempts", "freestanding hs"], skillId: "hs.freestanding-hs-30"),
        skillDrill("wall-plank", "Wall Plank", aliases: ["wall plank"], skillId: "hs.wall-plank"),
        skillDrill("wall-shoulder-tap", "Wall Shoulder Tap", aliases: ["wall shoulder tap", "handstand shoulder tap"], skillId: "hs.wall-supported-oah"),
        skillDrill("kick-up-practice", "Kick-Up Practice", aliases: ["kick-up practice", "kick up practice", "kick-up practice against wall"], skillId: "hs.freestanding-hs-30"),
        skillDrill("crow-pose", "Crow Pose", aliases: ["crow pose", "one-foot crow float"], skillId: "hs.crow-pose"),
        skillDrill("headstand", "Headstand", aliases: ["headstand", "tripod base hold", "tuck headstand"], skillId: "hs.headstand"),
        skillDrill("planche-lean", "Planche Lean", aliases: ["planche lean", "planche lean hold", "feet-elevated planche lean"], skillId: "pl.tuck-planche"),
        skillDrill("hollow-body-hold", "Hollow Body Hold", aliases: ["hollow body hold", "banana hold"], skillId: "cl.hollow-body-30")
    ]

    private static let skillTreeDefinitions: [MovementDefinition] = SkillGraph.shared.nodes.map { node in
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

    private static func skillTreeAliases(for node: SkillNode) -> [String] {
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

    private static func exerciseNames(in criterion: TierCriterion) -> [String] {
        switch criterion {
        case .reps(_, let exerciseName):
            return [exerciseName]
        case .exerciseBodyweightRatio(_, let exerciseName):
            return [exerciseName]
        case .variant(let name):
            return [name]
        case .compound(let criteria):
            return criteria.flatMap(exerciseNames)
        case .seconds, .weightKg, .bodyweightRatio:
            return []
        }
    }

    private static func defaultMetric(for node: SkillNode) -> TrainingMetricKind {
        switch node.target {
        case .hold, .carry:
            return .holdSeconds
        case .steps, .reps, .weightMultiplier, .composite:
            return .reps
        }
    }

    private static func skillAttributeWeights(for node: SkillNode) -> [AttributeKey: Double] {
        switch node.cluster {
        case .pullingPower:
            return [.power: 0.45, .control: 0.25, .endurance: 0.2, .mobility: 0.1]
        case .calisthenicControl, .planche, .handstand, .handstandPushup, .oneArmHandstand:
            return [.control: 0.45, .power: 0.25, .mobility: 0.2, .endurance: 0.1]
        case .coreLever:
            return [.control: 0.55, .mobility: 0.2, .power: 0.15, .endurance: 0.1]
        case .legDominance:
            return [.power: 0.4, .control: 0.25, .mobility: 0.2, .endurance: 0.15]
        case .conditioning:
            return [.endurance: 0.65, .power: 0.15, .control: 0.1, .mobility: 0.1]
        }
    }

    private static func movementEquipment(for equipment: [SkillEquipment]) -> [MovementEquipment] {
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

    private static func difficulty(for node: SkillNode) -> MovementDifficulty {
        if node.isMythic || node.rank == .s || node.tier >= 7 {
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

    private static func skillContraindicationTags(for node: SkillNode) -> [String] {
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

    private static func skillDrill(_ id: String, _ displayName: String, aliases: [String], skillId: String) -> MovementDefinition {
        MovementDefinition(
            id: "skill-drill.\(id)",
            displayName: displayName,
            role: .skillDrill,
            rankable: true,
            rankTemplate: .holdControl,
            blockKind: .skill,
            loggerMode: .skillAttempts,
            aliases: aliases,
            attributeWeights: [.control: 0.55, .mobility: 0.2, .power: 0.15, .endurance: 0.1],
            canonicalExerciseName: nil,
            skillId: skillId,
            cardioType: nil,
            defaultMetric: .holdSeconds,
            equipment: [.bodyweight],
            difficulty: .intermediate,
            muscleGroups: [.shoulders, .core],
            bodyRegions: [.shoulders, .abs, .obliques, .lowerBack],
            movementSlot: .skill,
            substitutionGroup: "skill.\(skillId)",
            skillAssociations: [skillId],
            contraindicationTags: ["wrist-sensitive", "shoulder-sensitive"]
        )
    }

    private static let routineDefinitions: [MovementDefinition] = RoutineLibrary.placeholderRoutines.map { routine in
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

enum MovementCatalogValidation {
    static func issues() -> [String] {
        var issues: [String] = []
        let definitions = MovementCatalog.definitions
        let definitionsById = MovementCatalog.definitionsById
        let skillIds = Set(SkillGraph.shared.nodes.map(\.id))
        let exerciseNames = Set(ExerciseCatalog.allExercises.map(\.name))

        let duplicateIds = duplicateValues(definitions.map(\.id))
        if !duplicateIds.isEmpty {
            issues.append("Duplicate movement ids: \(duplicateIds.joined(separator: ", "))")
        }

        let canonicalExercises = definitions.filter { $0.role == .canonicalExercise }
        if canonicalExercises.count != ExerciseCatalog.allExercises.count {
            issues.append("Canonical exercise count \(canonicalExercises.count) does not match ExerciseCatalog count \(ExerciseCatalog.allExercises.count).")
        }

        for definition in definitions {
            if definition.rankable && definition.rankTemplate != .unranked {
                guard let ladder = MovementCatalog.standardLadder(for: definition) else {
                    issues.append("\(definition.id) is rankable but has no movement standard ladder.")
                    continue
                }
                if ladder.tiers.count != SkillTier.allCases.count {
                    issues.append("\(definition.id) ladder has \(ladder.tiers.count) tiers; expected \(SkillTier.allCases.count).")
                }
                if ladder.tiers.map(\.tier) != SkillTier.allCases {
                    issues.append("\(definition.id) ladder tiers do not match the canonical 9-rank order.")
                }
            }

            if let variantOf = definition.variantOfMovementId {
                guard let base = definitionsById[variantOf] else {
                    issues.append("\(definition.id) variantOfMovementId points at missing \(variantOf).")
                    continue
                }
                if definition.rankStandardMovementId != variantOf {
                    issues.append("\(definition.id) variant and rank standard disagree: \(variantOf) vs \(definition.rankStandardMovementId).")
                }
                if base.rankStandardMovementId != base.id {
                    issues.append("\(definition.id) rolls into another variant instead of direct standard \(base.id).")
                }
                if !base.rankable {
                    issues.append("\(definition.id) rolls into non-rankable base \(base.id).")
                }
            }

            for skillId in definition.skillAssociations where !skillIds.contains(skillId) {
                issues.append("\(definition.id) links missing skill \(skillId).")
            }

            if definition.role == .canonicalExercise {
                if definition.rankTemplate == .unranked {
                    issues.append("\(definition.id) is canonical but unranked.")
                }
                if definition.equipment.isEmpty {
                    issues.append("\(definition.id) has no equipment.")
                }
                if definition.muscleGroups.isEmpty {
                    issues.append("\(definition.id) has no muscle groups.")
                }
                if definition.bodyRegions.isEmpty {
                    issues.append("\(definition.id) has no body regions.")
                }
                if definition.substitutionGroup.isEmpty {
                    issues.append("\(definition.id) has no substitution group.")
                }
                if definition.attributeWeights.isEmpty {
                    issues.append("\(definition.id) has no attribute weights.")
                } else {
                    let sum = definition.attributeWeights.values.reduce(0, +)
                    if abs(sum - 1.0) > 0.02 {
                        issues.append("\(definition.id) attribute weights sum to \(sum), expected 1.0.")
                    }
                }
                issues.append(contentsOf: loggerIssues(for: definition))
            }
        }

        for exercise in ExerciseCatalog.allExercises {
            if let substitute = exercise.defaultSubstitute,
               !exerciseNames.contains(substitute) {
                issues.append("\(exercise.name) default substitute points at missing \(substitute).")
            }
        }

        issues.append(contentsOf: policyIssues(definitions: definitions))
        return issues.sorted()
    }

    private static func loggerIssues(for definition: MovementDefinition) -> [String] {
        if definition.rankTemplate == .holdControl && definition.loggerMode != .hold {
            return ["\(definition.id) is Hold / Control but does not use hold logger."]
        }
        if definition.rankTemplate == .bodyweightReps && definition.loggerMode != .bodyweightSets {
            return ["\(definition.id) is Bodyweight Reps but does not use bodyweight set logger."]
        }
        if [.barbellStrength, .machineStrength, .weightedBodyweight].contains(definition.rankTemplate),
           definition.loggerMode != .strengthSets,
           definition.loggerMode != .bodyweightSets {
            return ["\(definition.id) is strength-ranked but uses \(definition.loggerMode.rawValue)."]
        }
        return []
    }

    private static func policyIssues(definitions: [MovementDefinition]) -> [String] {
        var issues: [String] = []
        let byId = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

        let holdIds = [
            "exercise.l-sit",
            "exercise.l-sit-tucked",
            "exercise.tuck-front-lever",
            "exercise.advanced-tuck-front-lever",
            "exercise.dragon-flag"
        ]
        for id in holdIds {
            guard let definition = byId[id] else { continue }
            if definition.rankTemplate != .holdControl || definition.loggerMode != .hold {
                issues.append("\(id) must be Hold / Control with the hold logger.")
            }
        }

        if let hollowRock = byId["exercise.hollow-rock"],
           hollowRock.rankTemplate != .bodyweightReps || hollowRock.loggerMode != .bodyweightSets {
            issues.append("exercise.hollow-rock must stay Bodyweight Reps with the rep logger.")
        }

        for definition in definitions where definition.movementSlot == .horizontalPull {
            if definition.skillAssociations.contains("pp.pullup") || definition.skillAssociations.contains("pp.strict-pullup") {
                issues.append("\(definition.id) is horizontal pull but credits vertical pull skills.")
            }
        }

        for id in ["exercise.straight-arm-pulldown", "exercise.machine-pullover"] {
            if let definition = byId[id],
               definition.skillAssociations.contains("pp.pullup") || definition.skillAssociations.contains("pp.strict-pullup") {
                issues.append("\(id) is lat isolation but credits pull-up skill.")
            }
        }

        for id in ["exercise.assisted-dip-machine", "exercise.dip-machine"] {
            if byId[id]?.skillAssociations.contains("pp.muscle-up") == true {
                issues.append("\(id) should not credit muscle-up skill progression.")
            }
        }

        for id in ["exercise.dip", "exercise.straight-bar-dip"] {
            if byId[id]?.skillAssociations.contains("pp.muscle-up") != true {
                issues.append("\(id) should credit muscle-up skill context.")
            }
        }

        let expectedEquipment: [(String, MovementEquipment, MovementEquipment)] = [
            ("exercise.safety-bar-squat", .barbell, .bodyweight),
            ("exercise.arnold-press", .dumbbell, .bodyweight),
            ("exercise.straight-bar-tricep-pushdown", .cable, .barbell)
        ]
        for (id, required, forbidden) in expectedEquipment {
            guard let definition = byId[id] else { continue }
            if !definition.equipment.contains(required) {
                issues.append("\(id) missing required equipment \(required.rawValue).")
            }
            if definition.equipment.contains(forbidden) {
                issues.append("\(id) should not include equipment \(forbidden.rawValue).")
            }
        }

        if byId["exercise.hip-adductor-machine"]?.movementSlot != .squat {
            issues.append("exercise.hip-adductor-machine should live in Squat / Quad, not Hinge / Posterior.")
        }

        if byId["exercise.hanging-knee-raise"]?.skillAssociations.contains("cl.hollow-body-30") != true {
            issues.append("exercise.hanging-knee-raise should link to cl.hollow-body-30 if hanging leg raise does.")
        }

        return issues
    }

    private static func duplicateValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for value in values {
            if seen.contains(value) {
                duplicates.insert(value)
            } else {
                seen.insert(value)
            }
        }
        return duplicates.sorted()
    }
}

enum MovementResolver {
    static func resolve(_ rawName: String) -> ResolvedMovement {
        let normalized = MovementCatalog.normalized(rawName)
        let definition = directDefinition(for: normalized) ?? inferredDefinition(for: normalized, rawName: rawName)
        return ResolvedMovement(
            rawName: rawName,
            movementId: definition.id,
            displayName: definition.displayName,
            role: definition.role,
            rankable: definition.rankable,
            rankTemplate: definition.rankTemplate,
            blockKind: definition.blockKind,
            loggerMode: definition.loggerMode,
            canonicalExerciseName: definition.canonicalExerciseName,
            variantOfMovementId: definition.variantOfMovementId,
            rankStandardMovementId: definition.rankStandardMovementId,
            skillId: definition.skillId,
            cardioType: definition.cardioType,
            movementSlot: definition.movementSlot,
            bodyRegions: definition.bodyRegions,
            substitutionGroup: definition.substitutionGroup,
            variationTags: variationTags(for: normalized)
        )
    }

    private static func directDefinition(for normalized: String) -> MovementDefinition? {
        MovementCatalog.aliasIndex[normalized]
    }

    private static func inferredDefinition(for normalized: String, rawName: String) -> MovementDefinition {
        if let cardio = inferCardio(from: normalized) {
            return cardio
        }
        if let carry = inferCarry(from: normalized) {
            return carry
        }
        if let mobility = inferMobility(from: normalized) {
            return mobility
        }
        if let base = inferAliasBase(from: normalized) {
            return base
        }
        return MovementDefinition(
            id: "unresolved.\(MovementCatalog.slug(rawName))",
            displayName: rawName,
            role: .routineStep,
            rankable: false,
            rankTemplate: .unranked,
            blockKind: .routine,
            loggerMode: .routinePlayer,
            aliases: [],
            attributeWeights: [:],
            canonicalExerciseName: nil,
            skillId: nil,
            cardioType: nil,
            defaultMetric: .reps,
            equipment: [],
            difficulty: .beginner,
            muscleGroups: [],
            bodyRegions: [],
            movementSlot: .routine,
            substitutionGroup: "unresolved"
        )
    }

    private static func inferCardio(from normalized: String) -> MovementDefinition? {
        let candidates: [(String, CardioType)] = [
            ("run", .run), ("sprint", .run),
            ("bike", .bike), ("assault bike", .bike),
            ("row", .row), ("rower", .row),
            ("walk", .walk),
            ("swim", .swim),
            ("stairs", .stairs),
            ("elliptical", .elliptical)
        ]
        guard let type = candidates.first(where: { normalized.contains($0.0) })?.1 else { return nil }
        return MovementCatalog.aliasIndex[MovementCatalog.normalized(type.displayName)]
    }

    private static func inferCarry(from normalized: String) -> MovementDefinition? {
        if normalized.contains("sled") { return MovementCatalog.aliasIndex["sled push"] }
        if normalized.contains("suitcase") { return MovementCatalog.aliasIndex["suitcase carry"] }
        if normalized.contains("farmer") { return MovementCatalog.aliasIndex["farmer carry"] }
        if normalized.contains("carry") { return MovementCatalog.aliasIndex["loaded march"] }
        return nil
    }

    private static func inferMobility(from normalized: String) -> MovementDefinition? {
        let mobilityTerms = [
            "stretch", "mobility", "wrist", "thoracic", "hamstring",
            "pigeon", "cat cow", "cat-cow", "frog", "couch", "hip flexor",
            "thread the needle", "spinal twist", "shoulder dislocate"
        ]
        guard mobilityTerms.contains(where: { normalized.contains($0) }) else { return nil }
        if normalized.contains("wrist") { return MovementCatalog.aliasIndex["wrist prep flow"] }
        if normalized.contains("shoulder") { return MovementCatalog.aliasIndex["shoulder dislocates"] }
        if normalized.contains("thoracic") || normalized.contains("thread") || normalized.contains("twist") { return MovementCatalog.aliasIndex["thoracic rotation"] }
        if normalized.contains("hamstring") || normalized.contains("fold") { return MovementCatalog.aliasIndex["hamstring fold"] }
        if normalized.contains("pigeon") || normalized.contains("figure") { return MovementCatalog.aliasIndex["pigeon pose"] }
        if normalized.contains("frog") { return MovementCatalog.aliasIndex["frog stretch"] }
        if normalized.contains("cat") { return MovementCatalog.aliasIndex["cat cow"] }
        return MovementCatalog.aliasIndex["hip flexor stretch"]
    }

    private static func inferAliasBase(from normalized: String) -> MovementDefinition? {
        if (normalized.contains("pull up") || normalized.contains("pullup")) {
            if normalized.contains("machine") && normalized.contains("assisted") {
                return MovementCatalog.aliasIndex["assisted pull up machine"]
            }
            if normalized.contains("assisted") || normalized.contains("band assisted") || normalized.contains("banded") {
                return MovementCatalog.aliasIndex["assisted pull up band"]
            }
            if normalized.contains("negative") || normalized.contains("eccentric") {
                return MovementCatalog.aliasIndex["negative pull up"]
            }
        }

        let stripped = normalized
            .replacingOccurrences(of: "band assisted", with: "")
            .replacingOccurrences(of: "assisted", with: "")
            .replacingOccurrences(of: "negative", with: "")
            .replacingOccurrences(of: "tempo", with: "")
            .replacingOccurrences(of: "strict", with: "")
            .replacingOccurrences(of: "weighted", with: "")
            .replacingOccurrences(of: "wall supported", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return MovementCatalog.aliasIndex[stripped]
    }

    private static func variationTags(for normalized: String) -> Set<MovementVariationTag> {
        var tags: Set<MovementVariationTag> = []
        if normalized.contains("assisted") || normalized.contains("band") { tags.insert(.assisted) }
        if normalized.contains("negative") { tags.insert(.negative) }
        if normalized.contains("tempo") { tags.insert(.tempo) }
        if normalized.contains("weighted") || normalized.contains("loaded") { tags.insert(.weighted) }
        if normalized.contains("strict") { tags.insert(.strict) }
        if normalized.contains("explosive") || normalized.contains("clapping") { tags.insert(.explosive) }
        if normalized.contains("wall") { tags.insert(.wallSupported) }
        if normalized.contains("one arm") || normalized.contains("single leg") || normalized.contains("one leg") || normalized.contains("suitcase") { tags.insert(.unilateral) }
        if normalized.contains("elevated") || normalized.contains("incline") || normalized.contains("box") { tags.insert(.elevated) }
        if normalized.contains("interval") || normalized.contains("repeat") { tags.insert(.interval) }
        return tags
    }
}

private struct AttributePayload: Decodable {
    let exercises: [String: AttributeWeightDict]
}

private struct AttributeWeightDict: Decodable {
    let power: Double?
    let agility: Double?
    let control: Double?
    let endurance: Double?
    let mobility: Double?
    let explosiveness: Double?
}
