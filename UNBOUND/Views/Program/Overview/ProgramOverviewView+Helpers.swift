import Foundation

extension ProgramOverviewView {
    // MARK: - Helpers

    func programDay(for date: Date, in program: TrainingProgram) -> ProgramDay? {
        dayResolver.day(for: date, in: program)
    }

    func generatedDayNumber(for date: Date) -> Int? {
        guard let program = viewModel.program else { return nil }
        return dayResolver.generatedDayNumber(for: date, in: program)
    }

    func isCompletedProgramDay(_ day: ProgramDay?) -> Bool {
        guard let day, day.dayNumber > 0 else { return false }
        return viewModel.isCompleted(dayNumber: day.dayNumber) == true
    }

    /// Date-aware completion: workout logs are keyed by cycling dayNumber,
    /// which repeats across arcs — so only dates inside the active arc and
    /// not in the future may read as completed.
    func isCompletedProgramDay(_ day: ProgramDay?, on date: Date) -> Bool {
        guard let program = viewModel.program else { return false }
        let calendar = Calendar.current
        let normalized = calendar.startOfDay(for: date)
        let arcStart = calendar.startOfDay(for: BlockRolloverScheduler.activeStartDate(for: program))
        let today = calendar.startOfDay(for: programToday)
        guard normalized >= arcStart, normalized <= today else { return false }
        return isCompletedProgramDay(day)
    }

    func resumableDraft(for day: ProgramDay?) -> ActiveWorkoutSession? {
        guard let day,
              let program = viewModel.program,
              day.workout != nil,
              draftStore.hasDraft(in: .program)
        else { return nil }

        guard let draft = draftStore.load(.program) else { return nil }

        guard draft.programId == program.id,
              draft.dayNumber == day.dayNumber,
              !draft.exercises.isEmpty
        else { return nil }

        return draft
    }

    /// The stashed Quick-Log / custom draft, offered when the user reopens Quick
    /// Log. Only surfaced when it actually holds logged work, so an untouched
    /// Quick Log never resurrects a stale prompt.
    func resumableCustomDraft() -> ActiveWorkoutSession? {
        guard draftStore.hasDraft(in: .custom),
              let draft = draftStore.load(.custom),
              !draft.exercises.isEmpty
        else { return nil }
        return draft
    }

    func isCalibrationDay(_ day: ProgramDay?) -> Bool {
        ProgramSelectedDayPresenter.isCalibrationDay(day)
    }
}
