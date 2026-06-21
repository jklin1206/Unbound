import SwiftUI

extension ProgramOverviewView {
    func launchSessionEditor(for day: ProgramDay, date: Date) {
        switch workoutDestination(for: day, date: date) {
        case .dayDetail:
            selectedDay = day
        case .draft(let draft):
            if isProgramToday(date) {
                sessionEditorDraft = draft
            } else {
                planningTargetDate = Calendar.current.startOfDay(for: date)
                planningWorkoutDraft = draft
            }
        }
    }

    func launchActiveWorkout(for day: ProgramDay, date: Date) {
        switch workoutDestination(for: day, date: date) {
        case .dayDetail:
            selectedDay = day
        case .draft(let draft):
            activeWorkoutDraft = draft
        }
    }

    @MainActor
    func completeRecoveryDay(_ day: ProgramDay) async {
        guard !isCompletingRecoveryDay, recoveryRewardSequence == nil else { return }

        isCompletingRecoveryDay = true
        do {
            if let completion = try await viewModel.completeRestDay(day, at: selectedDayDate) {
                UnboundHaptics.success()
                recoveryRewardSequence = WorkoutRewardSequenceSummary.trainingReceipt(
                    performanceLog: completion.performanceLog,
                    completionResult: completion.result,
                    sourceName: "Recovery"
                )
            } else {
                selectedDay = day
            }
        } catch {
            LoggingService.shared.log(
                "Rest day recovery completion failed: \(error)",
                level: .warning,
                context: ["dayNumber": day.dayNumber]
            )
            selectedDay = day
        }
        isCompletingRecoveryDay = false
    }

    func programDraft(from day: ProgramDay, date: Date) -> TrainingSessionDraft? {
        guard let userId = services.auth.currentUserId else {
            LoggingService.shared.log(
                "Program draft launch skipped without authenticated user",
                level: .warning,
                context: ["dayNumber": day.dayNumber]
            )
            return nil
        }
        let programId = viewModel.program?.id
        let modifierContext = programId.map {
            temporaryModifierContext(userId: userId, programId: $0, date: date)
        } ?? .empty
        return ProgramWorkoutDraftResolver(
            userId: userId,
            programId: programId,
            progressionStates: viewModel.progressionStates ?? [:],
            modifierContext: modifierContext
        )
        .draft(from: day, date: date)
    }

    private func workoutDestination(for day: ProgramDay, date: Date) -> ProgramWorkoutLaunchCoordinator.Destination {
        ProgramWorkoutLaunchCoordinator.destination(
            for: day,
            date: date,
            isCompleted: isCompletedProgramDay(day),
            draft: programDraft(from: day, date: date)
        )
    }

    func temporaryModifierContext(
        userId: String,
        programId: String,
        date: Date
    ) -> DailyWorkoutModifierContext {
        _ = temporaryContextRevision
        let deloadFactor = skillProgress.currentWeekPhase.workoutDeloadFactor
        guard let override = ProgramTrainingContextStore.shared.activeDailyContext(
            userId: userId,
            programId: programId,
            date: date
        ) else {
            return DailyWorkoutModifierContext(deloadFactor: deloadFactor)
        }

        let resolution = ProgramFocusSwitchCoordinator.resolvedContext(
            override: override,
            profile: viewModel.currentProfile
        )
        return DailyWorkoutModifierContext(
            availableEquipment: resolution.dailyModifierEquipment,
            deloadFactor: deloadFactor
        )
    }
}
