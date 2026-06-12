import Foundation

// MARK: - Skill block resolution

extension DailyWorkoutResolver {
    static func skillBlock(skillId: String, userId: String?) -> TrainingBlock? {
        guard let node = SkillGraph.shared.node(id: skillId) else { return nil }
        let isTrainable = SkillProgressService.shared.isNodeTrainable(nodeId: node.id)
        let lastReview = userId.flatMap {
            SkillTrainingReviewStore.shared.cachedLatestReview(skillId: node.id, userId: $0)
        }
        guard let decision = SkillRungResolver.resolve(
            skillId: node.id,
            isTrainable: isTrainable,
            lastReview: lastReview
        ) else {
            return nil
        }
        return TrainingSessionAdapters.skillBlock(decision: decision)
    }

    static func taperedWorkout(_ workout: Workout, for skillBlocks: [TrainingBlock]) -> Workout {
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

    static func attachScheduledSkillBlocks(
        to blocks: [TrainingBlock],
        scheduledSkillIds: [String],
        userId: String
    ) -> [TrainingBlock] {
        guard !scheduledSkillIds.isEmpty else { return blocks }
        let existingSkillIds = Set(blocks.compactMap(\.skillId))
        let skillBlocks = scheduledSkillIds
            .filter { !existingSkillIds.contains($0) }
            .compactMap { skillBlock(skillId: $0, userId: userId) }
        guard !skillBlocks.isEmpty else { return blocks }

        var updated = blocks
        if let routineIndex = updated.firstIndex(where: { $0.kind == .routine }) {
            updated.insert(contentsOf: skillBlocks, at: routineIndex)
        } else {
            updated.append(contentsOf: skillBlocks)
        }
        return updated
    }

    static func overlapSlots(for block: TrainingBlock) -> [MovementSlot] {
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

    static func defaultSlots(for cluster: SkillCluster) -> [MovementSlot] {
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
}
