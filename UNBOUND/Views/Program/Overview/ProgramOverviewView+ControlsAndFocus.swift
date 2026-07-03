import SwiftUI

/// Initial values for the training-schedule editor, resolved from the user's
/// profile (or derived from the program) right before the sheet opens.
struct TrainingScheduleSeed: Identifiable {
    let id = UUID()
    let trainingDays: Set<Weekday>
    let sessionLength: SessionLength
    let workoutMinuteOfDay: Int
}

extension ProgramOverviewView {
    func programTopBar() -> some View {
        ProgramOverviewTopBar()
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
            currentExperience: viewModel.currentProfile?.experience,
            activeContext: activeContext,
            pendingContext: pendingContext
        )
    }

    func effectiveTrainingStyle() -> TrainingStyle {
        ProgramFocusSwitchCoordinator.effectiveTrainingStyle(profile: viewModel.currentProfile)
    }

    func currentEquipmentFallback(program: TrainingProgram) -> [Equipment] {
        ProgramFocusSwitchCoordinator.currentEquipmentFallback(
            profile: viewModel.currentProfile,
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

        if let program = viewModel.program {
            Task { await loadBlockRolloverContext(program: program) }
        }
    }

    @MainActor
    func applyFocusSwitch(_ selection: ProgramFocusSwitchSelection) async {
        guard !isSwitchingProgramFocus else { return }
        guard let userId = services.auth.currentUserId else {
            focusSwitchErrorMessage = "Sign in again before changing the active arc."
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

            viewModel.currentProfile = ProgramFocusSwitchCoordinator.updatedProfile(
                from: profile,
                generatedProgram: generated,
                resolution: resolution
            )
            refreshExerciseStarterAlternativesCache(program: generated)

            selectedDayDate = programToday
            weekOffset = 0
            focusSwitchPresentation = nil
            UnboundHaptics.success()
            await viewModel.refreshHistory()
        } catch {
            focusSwitchErrorMessage = "Could not rebuild the arc. Check your connection and try again."
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
        if let currentProfile = viewModel.currentProfile { return currentProfile }
        let profile = try await services.user.fetchProfile(userId: userId)
        viewModel.currentProfile = profile
        return profile
    }

    // MARK: - Training-schedule editor (which days / length / time of day)

    /// Resolves the user's current schedule, then opens the editor seeded with it.
    /// Fetches the profile if it has not loaded yet so the sheet is never blank.
    @MainActor
    func openScheduleEditor() {
        UnboundHaptics.soft()
        Task {
            guard let userId = services.auth.currentUserId else { return }
            let profile: UserProfile?
            if let cached = viewModel.currentProfile {
                profile = cached
            } else {
                profile = try? await services.user.fetchProfile(userId: userId)
            }
            if let profile { viewModel.currentProfile = profile }
            let days = profile?.trainingDays ?? derivedTrainingDays(from: viewModel.program)
            let minute = profile?.workoutMinuteOfDay
                ?? ((profile?.workoutTime?.notificationHour ?? 18) * 60)
            scheduleEditorSeed = TrainingScheduleSeed(
                trainingDays: days,
                sessionLength: profile?.sessionLength ?? .fortyFive,
                workoutMinuteOfDay: minute
            )
        }
    }

    /// Persists the edited schedule, regenerates the arc from today forward, and
    /// keeps any enabled workout reminders in step. Returns `nil` on success or a
    /// user-facing error string the sheet can display.
    @MainActor
    func applyScheduleChange(
        trainingDays: Set<Weekday>,
        sessionLength: SessionLength,
        workoutMinuteOfDay: Int
    ) async -> String? {
        let frequency = Self.targetFrequency(forDayCount: trainingDays.count)
        do {
            try await viewModel.applyTrainingSchedule(
                trainingDays: trainingDays,
                targetFrequency: frequency,
                sessionLength: sessionLength,
                workoutMinuteOfDay: workoutMinuteOfDay
            )
            // Reminders are opt-in; only follow the new schedule if already on.
            let preferences = NotificationPreferencesStore.shared.load()
            if preferences.workoutReminders.isEnabled {
                await NotificationCoordinator.shared.scheduleWorkoutReminders(
                    workoutTime: WorkoutTime.bucket(forMinuteOfDay: workoutMinuteOfDay),
                    trainingDays: trainingDays,
                    minuteOfDay: workoutMinuteOfDay
                )
            }
            selectedDayDate = programToday
            weekOffset = 0
            await viewModel.refreshHistory()
            UnboundHaptics.success()
            return nil
        } catch {
            LoggingService.shared.log("Training schedule apply failed: \(error)", level: .error)
            return "Could not update your schedule. Check your connection and try again."
        }
    }

    #if DEBUG
    /// Dev harness: `--unbound-open-schedule-editor` opens the editor on launch
    /// for on-sim screenshots (idb taps are unavailable in this environment).
    func openScheduleEditorIfRequested() {
        if ProcessInfo.processInfo.arguments.contains("--unbound-open-schedule-editor") {
            openScheduleEditor()
        }
    }
    #endif

    /// Maps a chosen number of training days to the supported weekly frequency
    /// (3–6). The editor clamps selection to that range, so this never widens it.
    static func targetFrequency(forDayCount count: Int) -> TargetFrequency {
        switch min(max(count, 3), 6) {
        case 3: return .three
        case 4: return .four
        case 5: return .five
        default: return .six
        }
    }

    /// Fallback for profiles missing `trainingDays`: read the train/rest pattern
    /// off the first week of the generated program (days are weekday-aligned to
    /// the program's start date).
    private func derivedTrainingDays(from program: TrainingProgram?) -> Set<Weekday> {
        guard let program, !program.days.isEmpty else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        var result: Set<Weekday> = []
        for day in program.days.prefix(7) where !day.isRestDay {
            let offset = max(0, day.dayNumber - 1)
            if let date = calendar.date(byAdding: .day, value: offset, to: program.createdAt),
               let weekday = Weekday(from: date, calendar: calendar) {
                result.insert(weekday)
            }
        }
        return result
    }
}
