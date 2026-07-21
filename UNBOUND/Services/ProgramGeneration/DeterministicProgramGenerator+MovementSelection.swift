import Foundation

extension DeterministicProgramGenerator {
    static func movementPool(input: ProgramGeneratorInput) -> [MovementDefinition] {
        let prefsByKey = preferenceMap(input.exercisePreferences)
        let avoidedNames = Set(input.exercisePreferences.flatMap { pref -> [String] in
            guard pref.status == .avoid else { return [] }
            return [pref.exerciseName, pref.displayName]
        })

        let definitions = MovementCatalog.programDefinitions(
            style: input.trainingStyle,
            userEquipment: input.equipment
        )
        let resolved = definitions.compactMap {
            applyPreference(
                to: $0,
                prefsByKey: prefsByKey,
                avoidedNames: avoidedNames,
                input: input
            )
        }
        let equipmentFiltered = Equipment.isFloorOnlySelection(Set(input.equipment))
            ? resolved.filter(isFloorOnlyProgramMovement)
            : resolved
        // Gymnastics skill movements only enter general programming once the
        // user engaged them in the skill tree; dedicated skill days and
        // scheduled skill practice keep their own channels.
        let skillGated = equipmentFiltered.filter { definition in
            guard isGatedSkillMovement(definition) else { return true }
            return matchesEngagedSkills(definition, engagedSkillIds: input.engagedSkillIds)
        }
        // Catalog order (programScore) stays authoritative: equipment intent
        // must outrank difficulty shaping, or a full-gym pool leads with floor
        // and band work. The regression filter plus difficulty gating above
        // handle level-appropriateness.
        return uniqueDefinitions(experienceFiltered(skillGated, input: input))
    }

    static func isFloorOnlyProgramMovement(_ definition: MovementDefinition) -> Bool {
        switch definition.movementSlot {
        case .verticalPull, .carry:
            // Vertical pulls need a bar; carries need implements. Horizontal pulls
            // fall through to the name filter below so an equipment-free pull
            // (e.g. Superman Pull) survives while bar/anchor rows (inverted row)
            // are still excluded by setup-required terms.
            return false
        case .horizontalPull, .squat, .hinge, .horizontalPush, .verticalPush, .arms, .core, .calves, .cardio, .mobility, .routine, .skill:
            break
        }

        let name = MovementCatalog.normalized(
            "\(definition.displayName) \(definition.canonicalExerciseName ?? "")"
        )
        let setupRequiredTerms = [
            "ab wheel",
            "chin up",
            "chin-up",
            "dip",
            "hanging",
            "inverted row",
            "pullup",
            "pull-up",
            "ring"
        ]
        return !setupRequiredTerms.contains { name.contains($0) }
    }

    static func experienceFiltered(
        _ definitions: [MovementDefinition],
        input: ProgramGeneratorInput
    ) -> [MovementDefinition] {
        let allowed = definitions.filter { definition in
            difficultyAllowed(definition.difficulty, for: input.experience)
        }
        // Assisted/negative regressions are for building toward a movement;
        // experienced users get the real thing unless nothing else exists.
        switch input.experience {
        case .never, .tried:
            return allowed
        case .used, .current:
            let withoutRegressions = allowed.filter { !isRegressionMovement($0) }
            return withoutRegressions.isEmpty ? allowed : withoutRegressions
        }
    }

    static func isRegressionMovement(_ definition: MovementDefinition) -> Bool {
        let name = MovementCatalog.normalized(
            "\(definition.displayName) \(definition.canonicalExerciseName ?? "")"
        )
        return name.contains("assisted") || name.contains("negative")
    }

    static func difficultyAllowed(
        _ difficulty: MovementDifficulty,
        for experience: Experience
    ) -> Bool {
        switch experience {
        case .never:
            return difficulty == .beginner
        case .tried:
            return difficulty == .beginner || difficulty == .intermediate
        case .used, .current:
            return difficulty != .elite
        }
    }

    static func applyPreference(
        to definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference],
        avoidedNames: Set<String>,
        input: ProgramGeneratorInput
    ) -> MovementDefinition? {
        guard let pref = preference(for: definition, prefsByKey: prefsByKey) else {
            return definition
        }

        switch pref.status {
        case .available:
            return definition
        case .avoid:
            return nil
        case .substitute:
            if let substituteName = pref.substitutePreference,
               let substitute = MovementCatalog.canonicalExercise(named: substituteName),
               substitute.movementSlot == definition.movementSlot,
               MovementCatalog.isProgramCompatible(
                   substitute,
                   style: input.trainingStyle,
                   userEquipment: input.equipment
               ),
               !isAvoided(substitute, prefsByKey: prefsByKey) {
                return substitute
            }

            return MovementCatalog.programAlternatives(
                to: definition.displayName,
                style: input.trainingStyle,
                userEquipment: input.equipment,
                excludedNames: avoidedNames
            ).first { !isAvoided($0, prefsByKey: prefsByKey) }
        }
    }

    static func preferenceMap(_ preferences: [ExercisePreference]) -> [String: ExercisePreference] {
        var map: [String: ExercisePreference] = [:]
        for pref in preferences {
            map[MovementCatalog.normalized(pref.exerciseName)] = pref
            map[MovementCatalog.normalized(pref.displayName)] = pref
        }
        return map
    }

    static func preference(
        for definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference]
    ) -> ExercisePreference? {
        if let canonical = definition.canonicalExerciseName,
           let pref = prefsByKey[MovementCatalog.normalized(canonical)] {
            return pref
        }
        return prefsByKey[MovementCatalog.normalized(definition.displayName)]
    }

    static func isAvoided(
        _ definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference]
    ) -> Bool {
        preference(for: definition, prefsByKey: prefsByKey)?.status == .avoid
    }

    static func isPrimaryMovement(_ definition: MovementDefinition) -> Bool {
        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            return definition.muscleGroups.count > 1 && !isSingleJointAccessory(definition)
        case .arms, .core, .calves, .carry, .cardio, .mobility, .routine, .skill:
            return false
        }
    }

    /// Single-joint work that lives in a compound slot (flys, raises, face
    /// pulls, pullovers) must never anchor a day as its primary movement,
    /// whatever its muscle-group list claims.
    static func isSingleJointAccessory(_ definition: MovementDefinition) -> Bool {
        let name = MovementCatalog.normalized(
            "\(definition.displayName) \(definition.canonicalExerciseName ?? "")"
        )
        let singleJointTerms = [
            "back extension",
            "face pull",
            "fly",
            "kickback",
            "leg curl",
            "leg extension",
            "pull apart",
            "pull over",
            "pullover",
            "pushdown",
            "raise",
            "reverse hyper",
            "shrug",
            "straight arm",
            "superman"
        ]
        return singleJointTerms.contains { name.contains($0) }
    }

    static func eligibleDefinitions(
        from catalog: [MovementDefinition],
        for template: DayTemplate,
        templateGroups: Set<MuscleGroup>
    ) -> [MovementDefinition] {
        if let slots = programSlots(for: template) {
            let slotMatches = catalog.filter { slots.contains($0.movementSlot) }
            if !slotMatches.isEmpty {
                return slotMatches
            }
        }

        return catalog.filter { definition in
            !Set(MuscleGroup.modernized(definition.muscleGroups)).intersection(templateGroups).isEmpty
        }
    }

    static func programSlots(for template: DayTemplate) -> Set<MovementSlot>? {
        switch template {
        case .push:
            return [.horizontalPush, .verticalPush]
        case .pull:
            return [.horizontalPull, .verticalPull]
        case .legs:
            return [.squat, .hinge, .calves]
        case .upper:
            return [.horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .arms]
        case .lower:
            return [.squat, .hinge, .calves, .core]
        case .skill:
            return [.skill, .core, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull]
        case .fullBody, .weakPoint:
            return nil
        case .rest:
            return []
        }
    }

    static func uniqueDefinitions(_ definitions: [MovementDefinition]) -> [MovementDefinition] {
        var seen: Set<String> = []
        return definitions.filter { definition in
            let key = definition.canonicalExerciseName ?? definition.id
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    static func uniqueWorkoutDefinitions(_ definitions: [MovementDefinition]) -> [MovementDefinition] {
        var seen: Set<String> = []
        return definitions.filter { definition in
            let key = workoutEquivalenceKey(for: definition)
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    static func workoutEquivalenceKey(for definition: MovementDefinition) -> String {
        // Same-pattern isolation variants (three kinds of lateral raise) and
        // rank-standard variants (grip variations of one lift) count as ONE
        // movement inside a single workout.
        if let family = workoutVariantFamily(for: definition) {
            return family
        }
        if definition.rankStandardMovementId != definition.id {
            return "standard.\(definition.rankStandardMovementId)"
        }
        if let canonical = definition.canonicalExerciseName {
            return "exercise.\(MovementCatalog.normalized(canonical))"
        }

        if let exercise = canonicalExerciseEquivalent(for: definition),
           let canonical = exercise.canonicalExerciseName {
            return "exercise.\(MovementCatalog.normalized(canonical))"
        }

        return "movement.\(definition.rankStandardMovementId)"
    }

    /// Workout-scoped fold for isolation families whose members keep separate
    /// rank standards but are interchangeable within one session.
    static func workoutVariantFamily(for definition: MovementDefinition) -> String? {
        let name = MovementCatalog.normalized(
            "\(definition.displayName) \(definition.canonicalExerciseName ?? "")"
        )
        if name.contains("rear delt") { return "family.rear-delt" }
        if name.contains("lateral raise") { return "family.lateral-raise" }
        if name.contains("front raise") { return "family.front-raise" }
        if name.contains("calf raise") { return "family.calf-raise" }
        if name.contains("leg curl") { return "family.leg-curl" }
        if name.contains("leg extension") { return "family.leg-extension" }
        if name.contains("fly") || name.contains("pec deck") { return "family.chest-fly" }
        return nil
    }

    static func canonicalExerciseEquivalent(for definition: MovementDefinition) -> MovementDefinition? {
        guard definition.role == .skillTarget || definition.role == .skillDrill else {
            return nil
        }

        let names = [definition.displayName] + definition.aliases
        for name in names {
            let resolved = MovementResolver.resolve(name)
            guard resolved.movementId != definition.id,
                  let resolvedDefinition = MovementCatalog.definition(for: resolved.movementId),
                  resolvedDefinition.role == .canonicalExercise,
                  resolvedDefinition.movementSlot != .routine,
                  resolvedDefinition.movementSlot == resolved.movementSlot
            else {
                continue
            }
            return resolvedDefinition
        }

        return nil
    }

    static func rotateDefinitions(
        _ definitions: [MovementDefinition],
        by offset: Int
    ) -> [MovementDefinition] {
        guard definitions.count > 1 else { return definitions }
        let shift = ((offset % definitions.count) + definitions.count) % definitions.count
        guard shift > 0 else { return definitions }
        return Array(definitions[shift...]) + Array(definitions[..<shift])
    }

    static func containsBiasedGroup(
        _ definition: MovementDefinition,
        bias: [MuscleGroup: Int]
    ) -> Bool {
        guard !bias.isEmpty else { return false }
        let biasedGroups = Set(bias.keys)
        return !Set(MuscleGroup.modernized(definition.muscleGroups)).intersection(biasedGroups).isEmpty
    }

    static func rotationFiltered(
        _ definitions: [MovementDefinition],
        input: ProgramGeneratorInput
    ) -> [MovementDefinition] {
        let staleKeys = rotationKeys(for: input)
        guard !definitions.isEmpty, !staleKeys.isEmpty else { return definitions }
        let fresh = definitions.filter { !matchesRotation($0, staleKeys: staleKeys) }
        return fresh.isEmpty ? definitions : fresh
    }

    static func rotationKeys(for input: ProgramGeneratorInput) -> Set<String> {
        let raw = (input.previousBlock?.exerciseRotationsThisBlock ?? []) + input.exerciseRotationsToApply
        return Set(raw.map(MovementCatalog.normalized).filter { !$0.isEmpty })
    }

    static func matchesRotation(
        _ definition: MovementDefinition,
        staleKeys: Set<String>
    ) -> Bool {
        let rankStandard = MovementCatalog.rankStandard(for: definition)
        let candidates = [
            definition.canonicalExerciseName,
            definition.displayName,
            definition.id,
            rankStandard?.canonicalExerciseName,
            rankStandard?.displayName,
            rankStandard?.id
        ]
        .compactMap { $0 }
        .map(MovementCatalog.normalized)

        return candidates.contains { staleKeys.contains($0) }
    }

}
