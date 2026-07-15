import Foundation

// Session fill: back-fill a built workout toward its time budget and provide
// per-slot fallback chains so unfillable slots degrade to a nearby pattern
// instead of silently shrinking the session.
extension DeterministicProgramGenerator {
    /// Hard ceiling on main-work movements for a session, scaled by budget:
    /// 30m → 4, 60m → 5, 90m → 7.
    static func maxMainExerciseCount(budgetMinutes: Int) -> Int {
        min(8, max(4, budgetMinutes / 12))
    }

    /// Minutes of headroom left unfilled so estimates land just under budget.
    static let sessionFillHeadroomMinutes = 8

    /// Accessory slots a template may borrow from when its own pool runs dry.
    /// Only slots NOT already in `programSlots(for:)` belong here.
    static func secondaryAccessorySlots(for template: DayTemplate) -> Set<MovementSlot> {
        switch template {
        case .push, .pull:
            return [.arms, .core]
        case .legs:
            return [.core]
        case .upper:
            return [.core]
        case .fullBody, .weakPoint, .lower, .skill, .rest:
            return []
        }
    }

    /// Nearby patterns to try when a slot has no compatible movement, so a
    /// bodyweight user without a bar still gets a pull-adjacent or core pick
    /// instead of a silently smaller session.
    static func slotFallbackChain(for slot: MovementSlot) -> [MovementSlot] {
        switch slot {
        case .verticalPull:
            return [.verticalPull, .horizontalPull, .core]
        case .horizontalPull:
            return [.horizontalPull, .verticalPull, .core]
        case .hinge:
            return [.hinge, .squat, .core]
        case .squat:
            return [.squat, .hinge]
        case .verticalPush:
            return [.verticalPush, .horizontalPush]
        case .horizontalPush:
            return [.horizontalPush, .verticalPush]
        default:
            return [slot]
        }
    }

    /// Appends further movements (then extra accessory sets) while the session
    /// estimate sits comfortably under budget. Compression remains the
    /// upper-bound guard, so the pair lands estimates in
    /// [budget - headroom, budget] whenever the pool allows it.
    static func backfilledMainExercises(
        _ exercises: [Exercise],
        alreadyPicked: [MovementDefinition],
        candidates: [MovementDefinition],
        warmup: [Exercise],
        cooldown: [Exercise],
        budgetMinutes: Int,
        allowSetBumps: Bool = true,
        makeExercise: (MovementDefinition) -> Exercise
    ) -> [Exercise] {
        var filled = exercises
        var usedKeys = Set(alreadyPicked.map { workoutEquivalenceKey(for: $0) })
        let target = budgetMinutes - sessionFillHeadroomMinutes
        let exerciseCap = maxMainExerciseCount(budgetMinutes: budgetMinutes)

        for candidate in candidates {
            guard filled.count < exerciseCap else { break }
            guard estimatedWorkoutMinutes(warmup: warmup, main: filled, cooldown: cooldown) < target else { break }
            let key = workoutEquivalenceKey(for: candidate)
            guard !usedKeys.contains(key) else { continue }
            usedKeys.insert(key)
            filled.append(makeExercise(candidate))
        }

        // Round-robin +1 set on accessories once no distinct movement fits,
        // capped so no prescription runs away.
        var bumped = allowSetBumps
        while bumped,
              estimatedWorkoutMinutes(warmup: warmup, main: filled, cooldown: cooldown) < target {
            bumped = false
            for index in filled.indices {
                guard estimatedWorkoutMinutes(warmup: warmup, main: filled, cooldown: cooldown) < target else { break }
                let cap = isPrimaryExercise(filled[index]) ? 5 : 4
                if filled[index].sets < cap {
                    filled[index].sets += 1
                    bumped = true
                }
            }
        }

        return filled
    }

    /// Block-stable rotation offset: the same primary lift anchors every
    /// recurrence of a template within one block, and rollover to a new block
    /// (new start date) rotates the anchor deliberately.
    static func blockRotationOffset(for input: ProgramGeneratorInput) -> Int {
        Int(input.blockStartDate.timeIntervalSince1970 / 86_400)
    }

    /// Weekly rotation offset for accessories: stable inside a training week,
    /// advances week to week so accessory variety comes from planned rotation
    /// rather than per-session churn.
    static func weeklyRotationOffset(for input: ProgramGeneratorInput, sessionIndex: Int) -> Int {
        blockRotationOffset(for: input) + sessionIndex / max(1, input.trainingDays.count)
    }

    /// How many head-of-pool candidates compete for a primary anchor slot.
    static let anchorTierSize = 4

    /// Rotate only within the head "anchor tier" of a priority-ordered pool:
    /// block-to-block anchor variety cycles the few best-fit candidates.
    /// Rotating the FULL pool by a date-derived offset hands the anchor to an
    /// arbitrary pool position (machine presses for a barbell athlete, nordic
    /// variants as squat-slot primaries) and makes anchors hypersensitive to
    /// pool-size changes.
    static func anchorTierRotated(
        _ definitions: [MovementDefinition],
        by offset: Int
    ) -> [MovementDefinition] {
        guard definitions.count > anchorTierSize else {
            return rotateDefinitions(definitions, by: offset)
        }
        let tier = Array(definitions.prefix(anchorTierSize))
        let rest = Array(definitions.dropFirst(anchorTierSize))
        return rotateDefinitions(tier, by: offset) + rest
    }

    /// Names the user explicitly chose as substitutes. An explicit "give me X
    /// instead" outranks every scoring heuristic in X's slot.
    static func preferredSubstituteNames(for input: ProgramGeneratorInput) -> Set<String> {
        Set(input.exercisePreferences.compactMap { pref in
            guard pref.status == .substitute, let name = pref.substitutePreference else { return nil }
            return MovementCatalog.normalized(name)
        })
    }

    static func isPreferredSubstitute(
        _ definition: MovementDefinition,
        in names: Set<String>
    ) -> Bool {
        guard !names.isEmpty else { return false }
        return [definition.canonicalExerciseName, definition.displayName]
            .compactMap { $0 }
            .map(MovementCatalog.normalized)
            .contains { names.contains($0) }
    }

    /// Stable reorder that moves the user's explicit substitute picks to the
    /// front of a candidate list so they win their slot.
    static func pinnedFirst(
        _ definitions: [MovementDefinition],
        input: ProgramGeneratorInput
    ) -> [MovementDefinition] {
        let names = preferredSubstituteNames(for: input)
        guard !names.isEmpty else { return definitions }
        let pinned = definitions.filter { isPreferredSubstitute($0, in: names) }
        guard !pinned.isEmpty else { return definitions }
        return pinned + definitions.filter { !isPreferredSubstitute($0, in: names) }
    }

    /// True when the definition is (or drills toward) a gymnastics skill that
    /// should only appear once the user has engaged it in the skill tree.
    static func isGatedSkillMovement(_ definition: MovementDefinition) -> Bool {
        if definition.role == .skillDrill || definition.role == .skillTarget {
            return false // slot .skill — only surfaces on dedicated skill days
        }
        let name = MovementCatalog.normalized(
            "\(definition.displayName) \(definition.canonicalExerciseName ?? "")"
        )
        let gatedTerms = [
            "back lever",
            "elbow lever",
            "front lever",
            "handstand",
            "human flag",
            "l sit",
            "muscle up",
            "planche",
            "skin the cat",
            "v sit"
        ]
        return gatedTerms.contains { name.contains($0) }
    }

    /// Whether the user's engaged skill-tree nodes cover this movement.
    static func matchesEngagedSkills(
        _ definition: MovementDefinition,
        engagedSkillIds: Set<String>
    ) -> Bool {
        guard !engagedSkillIds.isEmpty else { return false }
        var candidateSkillIds = Set(definition.skillAssociations)
        if let skillId = definition.skillId {
            candidateSkillIds.insert(skillId)
        }
        if let twin = MovementCatalog.exerciseSkillTwins[definition.id] {
            candidateSkillIds.insert(twin)
        }
        return !candidateSkillIds.isDisjoint(with: engagedSkillIds)
    }
}
