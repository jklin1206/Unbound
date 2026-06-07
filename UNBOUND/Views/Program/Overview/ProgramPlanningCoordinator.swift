import Foundation

@MainActor
struct ProgramPlanningCoordinator {
    enum SavedWorkoutApplication {
        case extraSessionDraft(TrainingSessionDraft)
        case scheduledOccurrence(date: Date, occurrence: ProgramScheduleOccurrence)
    }

    let userId: String
    let programId: String?
    let today: Date
    let scheduleStore: ProgramScheduleStore
    let calendar: Calendar

    init(
        userId: String,
        programId: String?,
        today: Date,
        scheduleStore: ProgramScheduleStore,
        calendar: Calendar = .current
    ) {
        self.userId = userId
        self.programId = programId
        self.today = calendar.startOfDay(for: today)
        self.scheduleStore = scheduleStore
        self.calendar = calendar
    }

    func emptyDraft(title: String, date: Date?) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: userId,
            source: .custom,
            title: title,
            date: date ?? today,
            estimatedMinutes: 10,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: "Main Work",
                    prescriptions: []
                )
            ]
        )
    }

    func planningDate(selectedDate: Date, isSelectedDatePast: Bool) -> Date {
        isSelectedDatePast ? today : calendar.startOfDay(for: selectedDate)
    }

    func saveBuiltWorkout(
        _ draft: TrainingSessionDraft,
        date: Date,
        generatedDayNumber: Int?
    ) -> Date {
        let normalizedDate = calendar.startOfDay(for: date)
        let occurrence = builtOccurrence(
            from: draft,
            date: normalizedDate,
            generatedDayNumber: generatedDayNumber
        )
        scheduleStore.replacePrimary(
            on: normalizedDate,
            userId: userId,
            programId: programId,
            with: occurrence
        )
        return normalizedDate
    }

    func savedWorkoutApplication(
        workout: SavedWorkout,
        date: Date,
        allowExtraSession: Bool,
        isToday: Bool,
        isCompletedProgramDay: Bool
    ) -> SavedWorkoutApplication {
        let normalizedDate = calendar.startOfDay(for: date)
        if allowExtraSession, isToday, isCompletedProgramDay {
            var draft = workout.asDraft(
                userId: userId,
                date: today,
                programId: nil,
                dayNumber: nil
            )
            draft.title = workout.title
            return .extraSessionDraft(draft)
        }

        return .scheduledOccurrence(
            date: normalizedDate,
            occurrence: ProgramScheduleOccurrence(
                userId: userId,
                programId: programId,
                date: normalizedDate,
                kind: .saved,
                title: workout.title,
                savedWorkoutId: workout.id,
                attachScheduledSkills: true,
                adaptsWithProgression: true
            )
        )
    }

    func saveSavedWorkoutOccurrence(_ occurrence: ProgramScheduleOccurrence, date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        scheduleStore.replacePrimary(
            on: normalizedDate,
            userId: userId,
            programId: programId,
            with: occurrence
        )
    }

    private func builtOccurrence(
        from draft: TrainingSessionDraft,
        date: Date,
        generatedDayNumber: Int?
    ) -> ProgramScheduleOccurrence {
        var cleanDraft = draft
        let title = cleanDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanDraft.title = title.isEmpty ? "Built Workout" : title
        cleanDraft.date = date
        cleanDraft.programId = programId
        cleanDraft.dayNumber = generatedDayNumber

        return ProgramScheduleOccurrence(
            userId: userId,
            programId: programId,
            date: date,
            kind: .built,
            title: cleanDraft.title,
            draft: cleanDraft,
            attachScheduledSkills: true,
            adaptsWithProgression: true
        )
    }
}
