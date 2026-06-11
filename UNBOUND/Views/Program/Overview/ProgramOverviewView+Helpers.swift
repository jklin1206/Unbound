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

    func resumableDraft(for day: ProgramDay?) -> ActiveWorkoutSession? {
        guard let day,
              let program = viewModel.program,
              day.workout != nil,
              draftStore.hasDraft
        else { return nil }

        guard let draft = draftStore.load() else { return nil }

        guard draft.programId == program.id,
              draft.dayNumber == day.dayNumber,
              !draft.exercises.isEmpty
        else { return nil }

        return draft
    }

    func isCalibrationDay(_ day: ProgramDay?) -> Bool {
        ProgramSelectedDayPresenter.isCalibrationDay(day)
    }
}
