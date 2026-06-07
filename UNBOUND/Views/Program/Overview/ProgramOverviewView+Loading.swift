import SwiftUI

extension ProgramOverviewView {
    @MainActor
    func loadProgramSurface() async {
        let vm = ProgramViewModel(services: services)
        self.viewModel = vm

        #if DEBUG
        if let override = ProgramSurfaceProofOverride.fromLaunchArguments() {
            vm.state = override.loadingState
            return
        }
        #endif

        guard let userId = services.auth.currentUserId else { return }

        // History + travel don't depend on the profile — run concurrently.
        async let historyDone: Void = refreshHistory()
        async let travelDone: Void = refreshTravelOverride()

        // Instant: paint today's program from the local store — zero
        // network before the screen appears.
        let store = ProgramStore.shared
        let cached = store.loadLocal(userId: userId)
        if let cached {
            vm.program = cached
            vm.state = .loaded(cached)
            await vm.loadTrackingData()
            vm.refreshWaveAdjustments(asOf: selectedDayDate)
        }

        // Background: learn the authoritative programId; reconcile only
        // if a new program (rollover) superseded the cache, or load/
        // generate when there was no cache (first run).
        do {
            let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
            self.currentProfile = profile
            if let programId = profile.currentProgramId {
                if cached == nil {
                    await vm.loadProgram(programId: programId)
                } else {
                    await store.revalidate(userId: userId, expectedProgramId: programId)
                    if let refreshed = store.program, refreshed.id != cached?.id {
                        vm.program = refreshed
                        vm.state = .loaded(refreshed)
                        await vm.loadTrackingData()
                        vm.refreshWaveAdjustments(asOf: selectedDayDate)
                    }
                }
            } else if cached == nil {
                vm.state = .loading
                let generated = try await ProgramGenerationService.shared.generateFromOnboarding(
                    userId: userId,
                    targetFrequency: profile.targetFrequency,
                    equipment: Set(profile.equipment ?? []),
                    experience: profile.experience,
                    sessionLength: profile.sessionLength,
                    exerciseStyles: Set(profile.exerciseStyles ?? []),
                    targetAreas: Set(profile.targetAreas ?? []),
                    age: profile.age ?? 0,
                    gender: profile.gender ?? .unspecified,
                    heightCm: profile.heightCm ?? 0,
                    weightKg: profile.weightKg ?? 0,
                    trainingDays: profile.trainingDays,
                    trainingStyleOverride: profile.trainingStyleOverride,
                    trainingFeedbackMode: profile.trainingFeedbackMode,
                    cutModeActive: profile.cutMode.enabled,
                    biologicalSex: profile.biologicalSex
                )
                vm.program = generated
                vm.state = .loaded(generated)
                store.adopt(generated, userId: userId)
                vm.refreshWaveAdjustments(asOf: selectedDayDate)
            }
        } catch {
            if cached == nil {
                vm.state = .error(.databaseReadFailed(underlying: error))
            }
        }

        refreshExerciseStarterAlternativesCache(program: vm.program)

        _ = await historyDone
        _ = await travelDone

        // Prefetch today's session for every Program Focus so tapping
        // TRAIN is instant. Each in its own detached task.
        for focusId in skillProgress.programFocusIds {
            Task.detached { @MainActor in
                await RPESessionService.shared.prefetch(
                    skillId: focusId,
                    userId: userId
                )
            }
        }
    }
}
