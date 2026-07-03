import Foundation

@MainActor
struct ProgramOverviewDayResolver {
    let userId: String?
    let activeTravelOverride: TravelOverride?
    let scheduleRevision: Int
    let scheduleStore: ProgramScheduleStore
    let calendar: Calendar

    init(
        userId: String?,
        activeTravelOverride: TravelOverride?,
        scheduleRevision: Int,
        scheduleStore: ProgramScheduleStore,
        calendar: Calendar = .current
    ) {
        self.userId = userId
        self.activeTravelOverride = activeTravelOverride
        self.scheduleRevision = scheduleRevision
        self.scheduleStore = scheduleStore
        self.calendar = calendar
    }

    func day(for date: Date, in program: TrainingProgram) -> ProgramDay? {
        _ = scheduleRevision
        guard let generatedDay = generatedDay(on: date, in: program) else { return nil }

        if let occurrence = scheduledOccurrence(on: date, in: program),
           let scheduledDay = programDay(
                from: occurrence,
                fallback: generatedDay,
                date: date,
                program: program
           ) {
            return scheduledDay
        }

        if let override = activeTravelOverride, let travelDay = override.day(for: date) {
            return programDay(from: travelDay, on: date, summary: override.summary)
        }

        return generatedDay
    }

    func generatedDayNumber(for date: Date, in program: TrainingProgram) -> Int? {
        generatedDay(on: date, in: program)?.dayNumber
    }

    func generatedDay(on date: Date, in program: TrainingProgram) -> ProgramDay? {
        guard !program.days.isEmpty else { return nil }
        // Normalize both ends to start-of-day before counting. The program's
        // anchor (`createdAt` / arc start) carries the time-of-day it was
        // generated; counting whole days from an afternoon anchor to a
        // midnight tile date truncates a day and shifts the whole strip by one.
        let anchorDate = calendar.startOfDay(for: BlockRolloverScheduler.activeStartDate(for: program))
        let target = calendar.startOfDay(for: date)
        let daysSinceStart = calendar.dateComponents(
            [.day],
            from: anchorDate,
            to: target
        ).day ?? 0
        let index = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[index]
    }

    private func scheduledOccurrence(on date: Date, in program: TrainingProgram) -> ProgramScheduleOccurrence? {
        guard let userId else { return nil }
        return scheduleStore.primaryOccurrence(
            on: date,
            userId: userId,
            programId: program.id
        )
    }

    private func programDay(
        from occurrence: ProgramScheduleOccurrence,
        fallback: ProgramDay,
        date: Date,
        program: TrainingProgram
    ) -> ProgramDay? {
        if occurrence.kind == .rest {
            return ProgramDay(
                id: "planned-rest-\(occurrence.id.uuidString)",
                dayNumber: fallback.dayNumber,
                label: occurrence.displayTitle,
                isRestDay: true,
                workout: nil,
                sessionRole: .rest,
                nutritionOverride: fallback.nutritionOverride,
                recoveryActivities: fallback.recoveryActivities
            )
        }

        guard let userId,
              let draft = occurrence.resolvedDraft(
                userId: userId,
                programId: program.id,
                dayNumber: fallback.dayNumber,
                date: date
              )
        else {
            return nil
        }

        let savedRole = occurrence.savedWorkoutId
            .flatMap { SavedWorkoutStore.shared.get(id: $0)?.sessionRole }
            .flatMap(SessionRole.fromStorageValue)

        return ProgramDay(
            id: "planned-\(occurrence.id.uuidString)",
            dayNumber: fallback.dayNumber,
            label: occurrence.displayTitle,
            isRestDay: false,
            workout: TrainingSessionAdapters.workout(from: draft),
            sessionRole: savedRole ?? fallback.sessionRole,
            savedWorkoutId: occurrence.savedWorkoutId,
            userWorkoutDraft: draft,
            nutritionOverride: fallback.nutritionOverride,
            recoveryActivities: []
        )
    }

    private func programDay(from travelDay: TravelDay, on date: Date, summary: String) -> ProgramDay {
        ProgramDay(
            id: "travel-\(Int(date.timeIntervalSince1970))",
            dayNumber: 0,
            label: travelDay.isRest ? "TRAVEL · REST" : "TRAVEL · \(travelDay.title)",
            isRestDay: travelDay.isRest,
            workout: travelDay.workout(summary: "Travel plan: \(summary)"),
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }
}
