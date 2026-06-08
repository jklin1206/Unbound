import SwiftUI

extension ProgramOverviewView {
    func programTopBar() -> some View {
        let program = viewModel?.program
        let baseStyle = effectiveTrainingStyle()
        let baseEquipment = program.map(currentEquipmentFallback(program:))
            ?? currentProfile?.equipment
            ?? [Equipment.bodyweight]
        let activeContext = program.map { activeTrainingContextOverride(program: $0, date: selectedDayDate) } ?? nil
        let pendingContext = program.map { pendingNextBlockContext(program: $0) } ?? nil
        let displayedContext = activeContext ?? pendingContext
        let contextResolution = displayedContext.map(resolvedTrainingContext)
        let style = contextResolution?.trainingStyle ?? baseStyle
        let equipment = contextResolution?.sortedEquipment ?? baseEquipment
        let setupTile = ProgramCommandDock.SetupTile.resolve(
            style: style,
            equipment: equipment,
            activeContext: activeContext,
            pendingContext: pendingContext,
            isLoading: isSwitchingProgramFocus
        )

        return ProgramOverviewTopBar(
            setupTitle: setupTile.title,
            setupIcon: setupTile.icon,
            setupTint: setupTile.tint,
            setupBadge: setupTile.badge,
            isSetupLoading: setupTile.isLoading,
            onSetup: {
                presentProgramFocusSwitch(
                    style: style,
                    equipment: equipment,
                    activeContext: activeContext,
                    pendingContext: pendingContext
                )
            }
        )
    }

    func programControlDock(program: TrainingProgram) -> some View {
        let baseStyle = effectiveTrainingStyle()
        let baseEquipment = currentEquipmentFallback(program: program)
        let activeContext = activeTrainingContextOverride(program: program, date: selectedDayDate)
        let pendingContext = pendingNextBlockContext(program: program)
        let displayedContext = activeContext ?? pendingContext
        let contextResolution = displayedContext.map(resolvedTrainingContext)
        let style = contextResolution?.trainingStyle ?? baseStyle
        let equipment = contextResolution?.sortedEquipment ?? baseEquipment

        return ProgramCommandDock(
            setupTile: ProgramCommandDock.SetupTile.resolve(
                style: style,
                equipment: equipment,
                activeContext: activeContext,
                pendingContext: pendingContext,
                isLoading: isSwitchingProgramFocus
            ),
            onPlan: {
                UnboundHaptics.soft()
                showMonthPlanner = true
            },
            onChangeSetup: {
                presentProgramFocusSwitch(
                    style: style,
                    equipment: equipment,
                    activeContext: activeContext,
                    pendingContext: pendingContext
                )
            }
        )
    }

    func presentProgramFocusSwitch(
        style: TrainingStyle,
        equipment: [Equipment],
        activeContext: ProgramTrainingContextOverride? = nil,
        pendingContext: ProgramTrainingContextOverride? = nil
    ) {
        UnboundHaptics.soft()
        focusSwitchErrorMessage = nil
        focusSwitchPresentation = ProgramFocusSwitchPresentation(
            currentStyle: style,
            currentEquipment: equipment,
            currentExperience: currentProfile?.experience,
            activeContext: activeContext,
            pendingContext: pendingContext
        )
    }

    func effectiveTrainingStyle() -> TrainingStyle {
        ProgramFocusSwitchCoordinator.effectiveTrainingStyle(profile: currentProfile)
    }

    func currentEquipmentFallback(program: TrainingProgram) -> [Equipment] {
        ProgramFocusSwitchCoordinator.currentEquipmentFallback(
            profile: currentProfile,
            program: program
        )
    }

    @MainActor
    func clearFocusContext(_ target: ProgramFocusSwitchClearTarget) {
        guard !isSwitchingProgramFocus else { return }

        let didClear: Bool
        switch target {
        case .daily(let context):
            didClear = ProgramTrainingContextStore.shared.clearDailyContext(
                id: context.id,
                userId: context.userId,
                programId: context.programId
            )
        case .pendingNextBlock(let context):
            didClear = ProgramTrainingContextStore.shared.clearPendingNextBlockContext(
                userId: context.userId,
                programId: context.programId
            )
        }

        guard didClear else { return }
        focusSwitchErrorMessage = nil
        focusSwitchPresentation = nil
        temporaryContextRevision += 1
        UnboundHaptics.success()

        if let program = viewModel?.program {
            Task { await loadBlockRolloverContext(program: program) }
        }
    }

    @MainActor
    func applyFocusSwitch(_ selection: ProgramFocusSwitchSelection) async {
        guard !isSwitchingProgramFocus else { return }
        guard let viewModel else {
            focusSwitchErrorMessage = "Program is still loading. Try again in a moment."
            return
        }
        guard let userId = services.auth.currentUserId else {
            focusSwitchErrorMessage = "Sign in again before changing the active block."
            return
        }
        guard let activeProgram = viewModel.program else {
            focusSwitchErrorMessage = "Program is still loading. Try again in a moment."
            return
        }

        isSwitchingProgramFocus = true
        focusSwitchErrorMessage = nil
        do {
            let profile = try await focusSwitchProfile(userId: userId)
            let resolution = ProgramTrainingContextResolver.resolve(
                selection: selection.contextSelection,
                currentStyle: profile.trainingStyleOverride,
                currentEquipment: Set(profile.equipment ?? []),
                currentExerciseStyles: Set(profile.exerciseStyles ?? []),
                currentExperience: profile.experience
            )

            if resolution.requiresManualWorkoutControl {
                focusSwitchPresentation = nil
                isSwitchingProgramFocus = false
                UnboundHaptics.soft()
                openPlanAheadEditor()
                return
            }

            switch resolution.scope {
            case .todayOnly, .thisWeek:
                ProgramTrainingContextStore.shared.saveDailyContext(
                    selection: selection.contextSelection,
                    userId: userId,
                    programId: activeProgram.id,
                    anchorDate: selectedDayDate
                )
                temporaryContextRevision += 1
                focusSwitchPresentation = nil
                isSwitchingProgramFocus = false
                UnboundHaptics.success()
                return

            case .nextBlock:
                ProgramTrainingContextStore.shared.savePendingNextBlockContext(
                    selection: selection.contextSelection,
                    userId: userId,
                    programId: activeProgram.id
                )
                temporaryContextRevision += 1
                focusSwitchPresentation = nil
                isSwitchingProgramFocus = false
                UnboundHaptics.success()
                await loadBlockRolloverContext(program: activeProgram)
                return

            case .ongoing, .freeformManual:
                break
            }

            guard resolution.shouldRegenerateProgram else {
                focusSwitchErrorMessage = "This change is not ready to apply yet."
                isSwitchingProgramFocus = false
                return
            }

            let generated = try await viewModel.switchProgramFocus(
                profile: profile,
                trainingStyle: resolution.trainingStyle,
                equipment: resolution.equipment,
                exerciseStyles: resolution.exerciseStyles,
                experience: resolution.experience
            )

            currentProfile = ProgramFocusSwitchCoordinator.updatedProfile(
                from: profile,
                generatedProgram: generated,
                resolution: resolution
            )
            refreshExerciseStarterAlternativesCache(program: generated)

            selectedDayDate = programToday
            weekOffset = 0
            focusSwitchPresentation = nil
            UnboundHaptics.success()
            await refreshHistory()
        } catch {
            focusSwitchErrorMessage = "Could not rebuild the block. Check your connection and try again."
            LoggingService.shared.log(
                "Program focus switch failed: \(error)",
                level: .error,
                context: [
                    "equipment": selection.sortedEquipment.map(\.rawValue).joined(separator: ","),
                    "ability": selection.abilityLevel.rawValue,
                    "mode": selection.mode.rawValue,
                    "scope": selection.scope.rawValue
                ]
            )
        }
        isSwitchingProgramFocus = false
    }

    @MainActor
    func focusSwitchProfile(userId: String) async throws -> UserProfile {
        if let currentProfile { return currentProfile }
        let profile = try await services.user.fetchProfile(userId: userId)
        currentProfile = profile
        return profile
    }
}
