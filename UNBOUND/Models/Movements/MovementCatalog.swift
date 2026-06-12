import Foundation


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

    static let definitionsById: [String: MovementDefinition] = {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }()

    static let aliasIndex: [String: MovementDefinition] = {
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
    }()

    static func definition(for id: String) -> MovementDefinition? {
        definitionsById[id]
    }

    static func resolvedTrainingMovement(
        name rawName: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil
    ) -> ResolvedTrainingMovement? {
        let resolved = MovementResolver.resolve(rawName)
        let explicitStandard = rankStandardDefinition(for: rankStandardMovementId)
        let exact = movementId.flatMap(definition(for:))
            ?? definition(for: resolved.movementId)
            ?? explicitStandard
        guard let exact else { return nil }

        let standard = explicitStandard
            ?? rankStandard(for: exact)
            ?? rankStandardDefinition(for: resolved.rankStandardMovementId)

        return ResolvedTrainingMovement(exact: exact, standard: standard)
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
        progressionDefinitions(family: family)
            .compactMap(catalogExercise(for:))
    }

    static func catalogCalisthenicsPick(family: String, maxTier: Int = 0) -> CatalogExercise? {
        progressionDefinitions(family: family, maxTier: maxTier)
            .compactMap(catalogExercise(for:))
            .last
    }

    static func progressionDefinitions(family: String, maxTier: Int? = nil) -> [MovementDefinition] {
        legacyExercises
            .filter { definition in
                guard definition.progressionFamily == family else { return false }
                guard let maxTier else { return true }
                return (definition.progressionTier ?? 0) <= maxTier
            }
            .sorted { lhs, rhs in
                let lhsTier = lhs.progressionTier ?? 0
                let rhsTier = rhs.progressionTier ?? 0
                if lhsTier != rhsTier { return lhsTier < rhsTier }
                return lhs.displayName < rhs.displayName
            }
    }

    static func catalogAlternatives(to rawName: String) -> [CatalogExercise] {
        guard let current = canonicalExercise(named: rawName) else { return [] }

        return uniqueCatalogExercises(from: alternativeDefinitions(replacing: current))
    }

    static func programDefinitions(
        style: TrainingStyle,
        userEquipment: [Equipment]
    ) -> [MovementDefinition] {
        programCandidateDefinitions(for: style)
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
        guard isProgramEligibleRole(definition.role) else { return false }

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

    static func programCandidateDefinitions(for style: TrainingStyle) -> [MovementDefinition] {
        switch style {
        case .bodyweight:
            return definitions.filter { isProgramEligibleRole($0.role) }
        case .freeWeights, .hybrid, .machines:
            return legacyExercises
        }
    }

    static func isProgramEligibleRole(_ role: MovementRole) -> Bool {
        switch role {
        case .canonicalExercise, .skillDrill, .skillTarget:
            return true
        case .alias, .cardioModality, .carrySled, .mobilityDuration, .routineContainer, .routineStep:
            return false
        }
    }

    static func rankStandard(for definition: MovementDefinition) -> MovementDefinition? {
        definitionsById[definition.rankStandardMovementId]
    }

    static func rankStandardDefinition(for id: String?) -> MovementDefinition? {
        guard let id, let definition = definition(for: id) else { return nil }
        return rankStandard(for: definition) ?? definition
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

}
struct AttributePayload: Decodable {
    let exercises: [String: AttributeWeightDict]
}

struct AttributeWeightDict: Decodable {
    let power: Double?
    let vitality: Double?
    let legacyAgility: Double?
    let control: Double?
    let endurance: Double?
    let mobility: Double?
    let explosiveness: Double?

    enum CodingKeys: String, CodingKey {
        case power, vitality, control, endurance, mobility, explosiveness
        case legacyAgility = "agility"
    }
}
