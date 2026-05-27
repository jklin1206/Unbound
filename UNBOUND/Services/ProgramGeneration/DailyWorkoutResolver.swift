import Foundation

struct DailyWorkoutModifierContext: Equatable, Sendable {
    var availableEquipment: [Equipment]?
    var deloadFactor: Double?
    var trialPrepMovementIds: [String]
    var avoidedMovementIds: Set<String>
    var shortSessionActive: Bool

    static let empty = DailyWorkoutModifierContext()

    init(
        availableEquipment: [Equipment]? = nil,
        deloadFactor: Double? = nil,
        trialPrepMovementIds: [String] = [],
        avoidedMovementIds: Set<String> = [],
        shortSessionActive: Bool = false
    ) {
        self.availableEquipment = availableEquipment
        self.deloadFactor = deloadFactor
        self.trialPrepMovementIds = trialPrepMovementIds
        self.avoidedMovementIds = avoidedMovementIds
        self.shortSessionActive = shortSessionActive
    }

    var hasModifiers: Bool {
        availableEquipment != nil
            || deloadFactor != nil
            || !trialPrepMovementIds.isEmpty
            || !avoidedMovementIds.isEmpty
            || shortSessionActive
    }
}

/// Resolves the user's base program day plus active program modifiers into
/// the concrete draft shown in Workout Ready.
///
/// V1 modifier support is deterministic: active skill goals become scheduled
/// skill blocks, equipment/avoidance modifiers substitute same-slot movements,
/// trial prep can add missing requirement work, and deloads reduce today's
/// volume without regenerating the monthly plan.
@MainActor
enum DailyWorkoutResolver {
    static func programDraft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        date: Date = Date(),
        modifierContext: DailyWorkoutModifierContext = .empty
    ) -> TrainingSessionDraft {
        programDraft(
            from: workout,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            date: date,
            scheduledSkillIds: ProgramScheduler.shared.skillIds(forDate: date),
            modifierContext: modifierContext
        )
    }

    static func programDraft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        date: Date = Date(),
        scheduledSkillIds: [String],
        modifierContext: DailyWorkoutModifierContext = .empty
    ) -> TrainingSessionDraft {
        var effectiveContext = modifierContext
        if isShortSessionActive(on: date) {
            effectiveContext.shortSessionActive = true
        }
        let skillBlocks = scheduledSkillIds.compactMap(skillBlock)
        let adjustedWorkout = adjustedWorkout(
            workout,
            for: skillBlocks,
            modifierContext: effectiveContext
        )
        var draft = TrainingSessionAdapters.draft(
            from: adjustedWorkout,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            scheduledSkillIds: skillBlocks.compactMap(\.skillId)
        )
        draft.date = date
        draft.estimatedMinutes = estimatedMinutes(for: draft.blocks, fallback: adjustedWorkout.estimatedMinutes)
        return draft
    }

    static func resolvedWorkout(
        from workout: Workout,
        date: Date = Date(),
        scheduledSkillIds: [String] = [],
        modifierContext: DailyWorkoutModifierContext = .empty
    ) -> Workout {
        var effectiveContext = modifierContext
        if isShortSessionActive(on: date) {
            effectiveContext.shortSessionActive = true
        }
        let skillBlocks = scheduledSkillIds.compactMap(skillBlock)
        return adjustedWorkout(
            workout,
            for: skillBlocks,
            modifierContext: effectiveContext
        )
    }

    static func skillOnlyDraft(
        skillId: String,
        userId: String,
        date: Date = Date()
    ) -> TrainingSessionDraft? {
        guard let node = SkillGraph.shared.node(id: skillId) else { return nil }
        return skillOnlyDraft(skillIds: [node.id], userId: userId, title: node.title, date: date)
    }

    static func skillOnlyDraft(
        skillIds: [String],
        userId: String,
        title: String = "Skill Training",
        date: Date = Date()
    ) -> TrainingSessionDraft? {
        let blocks = skillIds.compactMap(skillBlock)
        guard !blocks.isEmpty else { return nil }
        return TrainingSessionDraft(
            userId: userId,
            source: .skill,
            title: blocks.count == 1 ? blocks[0].title : title,
            date: date,
            estimatedMinutes: estimatedMinutes(for: blocks, fallback: 20),
            blocks: blocks
        )
    }

    private static func adjustedWorkout(
        _ workout: Workout,
        for skillBlocks: [TrainingBlock],
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        var adjusted = substitutedWorkout(workout, modifierContext: modifierContext)
        adjusted = trialPrepWorkout(adjusted, modifierContext: modifierContext)
        adjusted = taperedWorkout(adjusted, for: skillBlocks)
        adjusted = deloadedWorkout(adjusted, modifierContext: modifierContext)
        adjusted = shortSessionWorkout(adjusted, modifierContext: modifierContext)
        return adjusted
    }

    private static func isShortSessionActive(on date: Date) -> Bool {
        let stored = UserDefaults.standard.double(forKey: "unbound.shortSessionDate")
        guard stored > 0 else { return false }
        let today = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return abs(stored - today) < 60
    }

    private static func substitutedWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard modifierContext.hasModifiers else { return workout }

        var copy = workout
        let originalExclusions = Set(workout.mainExercises.flatMap(exclusionNames))
        var usedNames: Set<String> = []
        copy.mainExercises = workout.mainExercises.map { exercise in
            let excluded = originalExclusions.union(usedNames)
            let uniqueReplacement = replacement(
                for: exercise,
                modifierContext: modifierContext,
                additionalExcludedNames: excluded
            )
            let fallbackReplacement = replacement(
                for: exercise,
                modifierContext: modifierContext,
                additionalExcludedNames: []
            )
            guard let replacement = uniqueReplacement ?? fallbackReplacement else {
                usedNames.formUnion(exclusionNames(for: exercise))
                return exercise
            }
            var adjusted = exercise
            adjusted.name = replacement.displayName
            adjusted.muscleGroups = replacement.muscleGroups
            adjusted.substitution = exercise.name
            adjusted.notes = appendNote("Adjusted for today's modifiers.", to: exercise.notes)
            usedNames.formUnion(exclusionNames(for: replacement))
            return adjusted
        }
        return copy
    }

    private static func replacement(
        for exercise: Exercise,
        modifierContext: DailyWorkoutModifierContext,
        additionalExcludedNames: Set<String>
    ) -> CatalogExercise? {
        guard let current = MovementCatalog.canonicalExercise(named: exercise.name) else { return nil }
        let equipment = modifierContext.availableEquipment ?? [.fullGym]
        let style: TrainingStyle = equipment == [.bodyweight] ? .bodyweight : .hybrid
        let excluded = Set(
            [current.displayName, current.canonicalExerciseName ?? exercise.name]
                + modifierContext.avoidedMovementIds.map { $0 }
                + Array(additionalExcludedNames)
        )
        let unavailable = modifierContext.availableEquipment.map {
            !MovementCatalog.isProgramCompatible(current, style: style, userEquipment: $0)
        } ?? false
        let avoided = isAvoided(current, by: modifierContext.avoidedMovementIds)
        guard unavailable || avoided else { return nil }

        return MovementCatalog.catalogDefaultSubstitute(
            for: exercise.name,
            style: style,
            userEquipment: equipment,
            excludedNames: excluded
        )
    }

    private static func exclusionNames(for exercise: Exercise) -> [String] {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return [
                definition.id,
                definition.displayName,
                definition.canonicalExerciseName ?? exercise.name,
                definition.rankStandardMovementId
            ].map(MovementCatalog.normalized)
        }
        return [MovementCatalog.normalized(exercise.name)]
    }

    private static func exclusionNames(for exercise: CatalogExercise) -> [String] {
        if let definition = MovementCatalog.canonicalExercise(named: exercise.name) {
            return [
                definition.id,
                definition.displayName,
                definition.canonicalExerciseName ?? exercise.name,
                definition.rankStandardMovementId
            ].map(MovementCatalog.normalized)
        }
        return [
            MovementCatalog.normalized(exercise.name),
            MovementCatalog.normalized(exercise.displayName)
        ]
    }

    private static func trialPrepWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard !modifierContext.trialPrepMovementIds.isEmpty else { return workout }

        var copy = workout
        for movementId in modifierContext.trialPrepMovementIds {
            guard let definition = MovementCatalog.definition(for: movementId),
                  !containsMovement(definition, in: copy.mainExercises),
                  isCompatible(definition, modifierContext: modifierContext)
            else {
                continue
            }
            copy.mainExercises.append(trialPrepExercise(for: definition))
        }
        return copy
    }

    private static func deloadedWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard let rawFactor = modifierContext.deloadFactor else { return workout }
        let factor = min(1, max(0.25, rawFactor))

        var copy = workout
        copy.mainExercises = workout.mainExercises.map { exercise in
            var adjusted = exercise
            adjusted.sets = max(1, Int((Double(exercise.sets) * factor).rounded(.down)))
            adjusted.rpe = exercise.rpe.map { max(5, $0 - 1) }
            adjusted.notes = appendNote("Deload modifier applied.", to: exercise.notes)
            return adjusted
        }
        return copy
    }

    private static func shortSessionWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard modifierContext.shortSessionActive,
              workout.mainExercises.count > 3
        else { return workout }

        var copy = workout
        let primary = workout.mainExercises.filter(isPrimaryExercise)
        let accessory = workout.mainExercises.filter { !isPrimaryExercise($0) }
        let kept = Array((primary + accessory).prefix(3))
        copy.mainExercises = kept.map { exercise in
            var adjusted = exercise
            adjusted.notes = appendNote("Short mode kept this exercise; lower-priority work was cut for today.", to: exercise.notes)
            return adjusted
        }
        copy.estimatedMinutes = min(workout.estimatedMinutes, 30)
        copy.notes = appendNote("Short mode active: compounds first, accessories trimmed.", to: workout.notes)
        return copy
    }

    private static func isPrimaryExercise(_ exercise: Exercise) -> Bool {
        guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
            return false
        }
        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            return true
        case .arms, .core, .calves, .carry, .cardio, .mobility, .routine, .skill:
            return false
        }
    }

    private static func skillBlock(skillId: String) -> TrainingBlock? {
        guard let node = SkillGraph.shared.node(id: skillId) else { return nil }
        return TrainingSessionAdapters.skillBlock(skillId: node.id, title: node.title)
    }

    private static func taperedWorkout(_ workout: Workout, for skillBlocks: [TrainingBlock]) -> Workout {
        let overlapSlots = Set(skillBlocks.flatMap(overlapSlots(for:)))
        guard !overlapSlots.isEmpty else { return workout }

        var copy = workout
        var taperedSlots = Set<MovementSlot>()
        copy.mainExercises = workout.mainExercises.map { exercise in
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name),
                  overlapSlots.contains(definition.movementSlot),
                  !taperedSlots.contains(definition.movementSlot),
                  exercise.sets > 1
            else {
                return exercise
            }

            taperedSlots.insert(definition.movementSlot)
            var adjusted = exercise
            adjusted.sets = max(1, exercise.sets - 1)
            adjusted.notes = appendSkillModifierNote(to: exercise.notes)
            return adjusted
        }
        return copy
    }

    private static func isAvoided(_ definition: MovementDefinition, by avoidedMovementIds: Set<String>) -> Bool {
        guard !avoidedMovementIds.isEmpty else { return false }
        let avoided = Set(avoidedMovementIds.map(MovementCatalog.normalized))
        let candidates = [
            definition.id,
            definition.rankStandardMovementId,
            definition.displayName,
            definition.canonicalExerciseName ?? ""
        ].map(MovementCatalog.normalized)
        return candidates.contains { avoided.contains($0) }
    }

    private static func containsMovement(_ definition: MovementDefinition, in exercises: [Exercise]) -> Bool {
        exercises.contains { exercise in
            guard let existing = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return MovementCatalog.normalized(exercise.name) == MovementCatalog.normalized(definition.displayName)
            }
            return existing.id == definition.id
                || existing.rankStandardMovementId == definition.rankStandardMovementId
        }
    }

    private static func isCompatible(
        _ definition: MovementDefinition,
        modifierContext: DailyWorkoutModifierContext
    ) -> Bool {
        guard let equipment = modifierContext.availableEquipment else { return true }
        let style: TrainingStyle = equipment == [.bodyweight] ? .bodyweight : .hybrid
        return MovementCatalog.isProgramCompatible(definition, style: style, userEquipment: equipment)
    }

    private static func trialPrepExercise(for definition: MovementDefinition) -> Exercise {
        Exercise(
            id: "trial-prep-\(definition.id)",
            name: definition.canonicalExerciseName ?? definition.displayName,
            muscleGroups: definition.muscleGroups,
            sets: 2,
            reps: trialPrepTarget(for: definition.defaultMetric),
            restSeconds: 90,
            rpe: 7,
            notes: "Trial prep modifier.",
            substitution: nil
        )
    }

    private static func trialPrepTarget(for metric: TrainingMetricKind) -> String {
        switch metric {
        case .reps: return "8"
        case .holdSeconds: return "30s"
        case .durationSeconds: return "300s"
        case .distanceMeters: return "400m"
        case .calories: return "30 cal"
        }
    }

    private static func overlapSlots(for block: TrainingBlock) -> [MovementSlot] {
        var slots = Set<MovementSlot>()

        for prescription in block.prescriptions {
            let resolved = MovementResolver.resolve(prescription.exerciseName)
            if let definition = MovementCatalog.definition(for: resolved.movementId),
               definition.movementSlot != .skill {
                slots.insert(definition.movementSlot)
            }
        }

        if slots.isEmpty, let skillId = block.skillId, let node = SkillGraph.shared.node(id: skillId) {
            slots.formUnion(defaultSlots(for: node.cluster))
        }

        return Array(slots)
    }

    private static func defaultSlots(for cluster: SkillCluster) -> [MovementSlot] {
        switch cluster {
        case .pullingPower:
            return [.verticalPull]
        case .calisthenicControl:
            return [.horizontalPush]
        case .handstand, .handstandPushup, .oneArmHandstand:
            return [.verticalPush]
        case .planche:
            return [.horizontalPush, .verticalPush]
        case .legDominance:
            return [.squat]
        case .coreLever:
            return [.core]
        case .conditioning:
            return [.cardio, .carry]
        }
    }

    private static func appendSkillModifierNote(to existing: String?) -> String {
        appendNote("Volume tapered for scheduled skill work.", to: existing)
    }

    private static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.contains(note) { return existing }
        return "\(existing) \(note)"
    }

    private static func estimatedMinutes(for blocks: [TrainingBlock], fallback: Int) -> Int {
        guard !blocks.isEmpty else { return fallback }
        let minutes = blocks.reduce(0) { total, block in
            let blockSeconds = block.prescriptions.reduce(0) { subtotal, prescription in
                let workSeconds: Int
                switch prescription.target {
                case .holdSeconds(let seconds), .timedSeconds(let seconds):
                    workSeconds = seconds
                default:
                    workSeconds = 45
                }
                return subtotal + ((workSeconds + prescription.restSeconds) * max(1, prescription.sets))
            }
            return total + max(5, Int(ceil(Double(blockSeconds) / 60.0)))
        }
        return max(fallback, minutes)
    }
}
