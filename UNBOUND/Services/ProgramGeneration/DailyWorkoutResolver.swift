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

    /// Boundary helper: layers live app state (today's Short-mode flag) on top
    /// of an injected context. Call this where a REAL session launches — the
    /// resolver itself never reads globals, so unit tests passing an explicit
    /// context stay hermetic regardless of what the app on the device did.
    func applyingAppState(on date: Date) -> DailyWorkoutModifierContext {
        var context = self
        context.shortSessionActive = context.shortSessionActive
            || Self.appShortSessionActive(on: date)
        return context
    }

    /// Short mode is a same-day flag the SHORT coach action writes
    /// (`unbound.shortSessionDate` = start-of-day it was activated for).
    static func appShortSessionActive(on date: Date) -> Bool {
        let stored = UserDefaults.standard.double(forKey: "unbound.shortSessionDate")
        guard stored > 0 else { return false }
        let today = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return abs(stored - today) < 60
    }
}

/// Resolves the user's base program day plus active program modifiers into
/// the concrete draft that launches the active workout.
///
/// V1 modifier support is deterministic: active skill goals become scheduled
/// skill blocks, equipment/avoidance modifiers substitute same-slot movements,
/// trial prep can add missing requirement work, and deloads reduce today's
/// volume without regenerating the monthly plan.
@MainActor
enum DailyWorkoutResolver {
    static func programDraft(
        from day: ProgramDay,
        userId: String,
        programId: String?,
        date: Date = Date(),
        modifierContext: DailyWorkoutModifierContext = .empty,
        progressionStates: [String: ProgressionState] = [:],
        attachScheduledSkillsToUserWorkouts: Bool = true
    ) -> TrainingSessionDraft? {
        if let draft = day.userWorkoutDraft {
            let normalized = TrainingSessionDraft(
                id: draft.id,
                userId: userId,
                source: draft.source,
                title: draft.title,
                date: date,
                estimatedMinutes: draft.estimatedMinutes,
                programId: programId,
                dayNumber: day.dayNumber,
                blocks: draft.blocks
            )
            return composedUserDraft(
                normalized,
                userId: userId,
                date: date,
                scheduledSkillIds: attachScheduledSkillsToUserWorkouts ? ProgramScheduler.shared.skillIds(forDate: date) : [],
                modifierContext: modifierContext,
                progressionStates: progressionStates
            )
        }

        if let savedWorkoutId = day.savedWorkoutId,
           var draft = SavedWorkoutStore.shared.get(id: savedWorkoutId)?.asDraft(
                userId: userId,
                date: date,
                programId: programId,
                dayNumber: day.dayNumber
           ) {
            draft.source = .custom
            return composedUserDraft(
                draft,
                userId: userId,
                date: date,
                scheduledSkillIds: attachScheduledSkillsToUserWorkouts ? ProgramScheduler.shared.skillIds(forDate: date) : [],
                modifierContext: modifierContext,
                progressionStates: progressionStates
            )
        }

        guard let workout = day.workout else { return nil }
        return programDraft(
            from: workout,
            userId: userId,
            programId: programId,
            dayNumber: day.dayNumber,
            date: date,
            modifierContext: modifierContext,
            progressionStates: progressionStates
        )
    }

    static func programDraft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        date: Date = Date(),
        modifierContext: DailyWorkoutModifierContext = .empty,
        progressionStates: [String: ProgressionState] = [:]
    ) -> TrainingSessionDraft {
        programDraft(
            from: workout,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            date: date,
            scheduledSkillIds: ProgramScheduler.shared.skillIds(forDate: date),
            modifierContext: modifierContext,
            progressionStates: progressionStates
        )
    }

    static func programDraft(
        from workout: Workout,
        userId: String,
        programId: String?,
        dayNumber: Int?,
        date: Date = Date(),
        scheduledSkillIds: [String],
        modifierContext: DailyWorkoutModifierContext = .empty,
        progressionStates: [String: ProgressionState] = [:]
    ) -> TrainingSessionDraft {
        let skillBlocks = scheduledSkillIds.compactMap { skillBlock(skillId: $0, userId: userId) }
        let adjustedWorkout = adjustedWorkout(
            workout,
            for: skillBlocks,
            modifierContext: modifierContext
        )
        var draft = TrainingSessionAdapters.draft(
            from: adjustedWorkout,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            scheduledSkillBlocks: skillBlocks
        )
        draft.date = date
        draft.estimatedMinutes = estimatedMinutes(for: draft.blocks, fallback: adjustedWorkout.estimatedMinutes)
        return TrainingPrescriptionResolver.resolve(draft: draft, progressionStates: progressionStates)
    }

    static func composedUserDraft(
        _ draft: TrainingSessionDraft,
        userId: String,
        date: Date = Date(),
        scheduledSkillIds: [String] = [],
        modifierContext: DailyWorkoutModifierContext = .empty,
        progressionStates: [String: ProgressionState] = [:]
    ) -> TrainingSessionDraft {
        var resolved = draft
        resolved.date = date
        resolved.blocks = attachScheduledSkillBlocks(
            to: resolved.blocks,
            scheduledSkillIds: scheduledSkillIds,
            userId: userId
        )
        resolved = adjustedUserDraft(resolved, modifierContext: modifierContext)
        resolved.estimatedMinutes = estimatedMinutes(for: resolved.blocks, fallback: resolved.estimatedMinutes)
        return TrainingPrescriptionResolver.resolve(draft: resolved, progressionStates: progressionStates)
    }

    static func resolvedWorkout(
        from workout: Workout,
        scheduledSkillIds: [String] = [],
        modifierContext: DailyWorkoutModifierContext = .empty
    ) -> Workout {
        let skillBlocks = scheduledSkillIds.compactMap { skillBlock(skillId: $0, userId: nil) }
        return adjustedWorkout(
            workout,
            for: skillBlocks,
            modifierContext: modifierContext
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
        let blocks = skillIds.compactMap { skillBlock(skillId: $0, userId: userId) }
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

    private static func attachScheduledSkillBlocks(
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
        // Skill practice belongs right after the warmup, before the user's
        // main work — precision work degrades fast under fatigue. Skip past
        // any leading warmup-style blocks, then insert.
        let insertIndex = updated.firstIndex { block in
            !block.title.localizedCaseInsensitiveContains("warmup")
        } ?? updated.endIndex
        updated.insert(contentsOf: skillBlocks, at: insertIndex)
        return updated
    }

    private static func skillBlock(skillId: String, userId: String?) -> TrainingBlock? {
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
