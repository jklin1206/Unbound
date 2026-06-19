import Foundation

enum ProgramWorkoutLaunchCoordinator {
    enum Destination {
        case dayDetail(ProgramDay)
        case draft(TrainingSessionDraft)
    }

    static func destination(
        for day: ProgramDay,
        date: Date,
        isCompleted: Bool,
        draft: TrainingSessionDraft?
    ) -> Destination {
        guard !isCompleted else { return .dayDetail(day) }
        guard day.canStartWorkoutSession else { return .dayDetail(day) }
        guard let draft else { return .dayDetail(day) }
        return .draft(draft)
    }
}

@MainActor
struct ProgramWorkoutDraftResolver {
    let userId: String
    let programId: String?
    let progressionStates: [String: ProgressionState]
    let modifierContext: DailyWorkoutModifierContext

    func draft(from day: ProgramDay, date: Date) -> TrainingSessionDraft? {
        DailyWorkoutResolver.programDraft(
            from: day,
            userId: userId,
            programId: programId,
            date: date,
            modifierContext: modifierContext,
            progressionStates: progressionStates,
            attachScheduledSkillsToUserWorkouts: true
        )
    }
}
