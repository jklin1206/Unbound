import SwiftUI

extension ProgramOverviewView {
    @MainActor
    func refreshHistory() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 40)) ?? []
        pastLogs = logs.filter { $0.completedAt != nil }
    }

    @MainActor
    func refreshProgramCompletionState() async {
        await refreshHistory()
        guard let vm = viewModel else { return }
        await vm.loadTrackingData()
        vm.refreshWaveAdjustments(asOf: selectedDayDate)
    }

    @MainActor
    func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    @MainActor
    func applyCheckpointOutcome(_ outcome: CheckpointOutcome) async {
        await viewModel?.completeCheckpoint(outcome)
        if let programId = viewModel?.program?.id {
            dismissedCheckpointPromptProgramId = programId
            UserDefaults.standard.set(true, forKey: checkpointPromptDismissalKey(programId: programId))
        }
        if let program = viewModel?.program {
            await loadBlockRolloverContext(program: program)
        }
    }

    func shouldShowCheckpointPrompt(
        for program: TrainingProgram,
        proposal: BlockRolloverService.ProgramBlockProposal
    ) -> Bool {
        guard proposal.scanDeltaReport != nil else { return false }
        guard dismissedCheckpointPromptProgramId != program.id else { return false }
        return !UserDefaults.standard.bool(forKey: checkpointPromptDismissalKey(programId: program.id))
    }

    func checkpointPromptDismissalKey(programId: String) -> String {
        "unbound.program.checkpointPrompt.dismissed.\(programId)"
    }

    var checkpointNutritionContext: NutritionContext {
        let hardSessionWithin24Hours = pastLogs.contains { log in
            guard let completedAt = log.completedAt else { return false }
            return programNow.timeIntervalSince(completedAt) <= 86_400
        }
        return NutritionTargetCalculator().calculate(
            input: NutritionTargetCalculator.Input(
                bodyweightKilograms: currentProfile?.weightKg,
                hardSessionLoggedWithin24Hours: hardSessionWithin24Hours
            )
        )
    }

    var checkpointMissedSessionSignal: MissedSessionSignal {
        guard let program = viewModel?.program else { return .onTrack }
        let now = programNow
        let sessions = scheduledAttendance(for: program, now: now)
        let result = MissedSessionMetric.evaluate(sessions: sessions, now: now)
        return MissedSessionSignal.fromScheduledSessions(
            scheduled: result.scheduledCount,
            missed: result.missedCount
        )
    }

    func scheduledAttendance(
        for program: TrainingProgram,
        now: Date
    ) -> [ScheduledSessionAttendance] {
        let calendar = Calendar.current
        return program.days.compactMap { day in
            guard !day.isRestDay else { return nil }
            guard let scheduledAt = calendar.date(
                byAdding: .day,
                value: day.dayNumber - 1,
                to: calendar.startOfDay(for: BlockRolloverScheduler.activeStartDate(for: program))
            ) else {
                return nil
            }
            guard scheduledAt <= now else { return nil }
            let completedAt = viewModel?.workoutLogs[day.dayNumber]?.completedAt
                ?? viewModel?.workoutLogs[day.dayNumber]?.startedAt
            return ScheduledSessionAttendance(
                scheduledAt: scheduledAt,
                completedAt: completedAt
            )
        }
    }
}
