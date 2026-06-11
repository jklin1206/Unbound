import SwiftUI
import Observation

@Observable
@MainActor
final class ProgramViewModel {
    var program: TrainingProgram?
    var state: LoadingState<TrainingProgram> = .idle
    var selectedDay: ProgramDay?
    var showTrainingDayNutrition = true
    var workoutLogs: [Int: WorkoutLog] = [:]  // dayNumber -> log
    var activeWaveAdjustments: [WaveAdjustment] = []
    var progressionStates: [String: ProgressionState] = [:]

    var currentProfile: UserProfile?

    // Completed-log cache. Still feeds checkpoint/recovery context even
    // though the old calendar tab is no longer surfaced.
    var pastLogs: [WorkoutLog] = []

    // Travel override (user hit the TRAVEL coach action)
    var activeTravelOverride: TravelOverride?

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    // MARK: - Surface load

    /// Full Program-tab surface load: local-first program paint, profile
    /// reconcile (or first-run generation), history + travel concurrently,
    /// and a per-focus session prefetch. Moved verbatim from
    /// `ProgramOverviewView+Loading.swift`.
    func loadSurface(selectedDayDate: Date) async {
        #if DEBUG
        if let override = ProgramSurfaceProofOverride.fromLaunchArguments() {
            state = override.loadingState
            return
        }
        #endif

        guard let userId = services.auth.currentUserId else {
            state = .idle
            return
        }

        // History + travel don't depend on the profile — run concurrently.
        async let historyDone: Void = refreshHistory()
        async let travelDone: Void = refreshTravelOverride()

        // Instant: paint today's program from the local store — zero
        // network before the screen appears.
        let store = ProgramStore.shared
        let cached = store.loadLocal(userId: userId)
        if let cached {
            program = cached
            state = .loaded(cached)
            await loadTrackingData()
            refreshWaveAdjustments(asOf: selectedDayDate)
        }

        // Background: learn the authoritative programId; reconcile only
        // if a new program (rollover) superseded the cache, or load/
        // generate when there was no cache (first run).
        do {
            let profile: UserProfile = try await services.user.fetchProfile(userId: userId)
            currentProfile = profile
            if let programId = profile.currentProgramId {
                if cached == nil {
                    await loadProgram(programId: programId)
                } else {
                    await store.revalidate(userId: userId, expectedProgramId: programId)
                    if let refreshed = store.program, refreshed.id != cached?.id {
                        program = refreshed
                        state = .loaded(refreshed)
                        await loadTrackingData()
                        refreshWaveAdjustments(asOf: selectedDayDate)
                    }
                }
            } else if cached == nil {
                state = .loading
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
                program = generated
                state = .loaded(generated)
                store.adopt(generated, userId: userId)
                refreshWaveAdjustments(asOf: selectedDayDate)
            }
        } catch {
            if cached == nil {
                state = .error(.databaseReadFailed(underlying: error))
            }
        }

        _ = await historyDone
        _ = await travelDone

        // Prefetch today's session for every Program Focus so tapping
        // TRAIN is instant. Each in its own detached task.
        for focusId in SkillProgressService.shared.programFocusIds {
            Task.detached { @MainActor in
                await RPESessionService.shared.prefetch(
                    skillId: focusId,
                    userId: userId
                )
            }
        }
    }

    // MARK: - Refresh

    func refreshHistory() async {
        guard let userId = services.auth.currentUserId else { return }
        let logs = (try? await services.workoutLog.fetchRecentLogs(userId: userId, limit: 40)) ?? []
        pastLogs = logs.filter { $0.completedAt != nil }
    }

    func refreshTravelOverride() async {
        guard let userId = services.auth.currentUserId else { return }
        activeTravelOverride = await TravelOverrideStore.shared.activeOverride(for: userId)
    }

    func refreshCompletionState(asOf date: Date) async {
        await refreshHistory()
        await loadTrackingData()
        refreshWaveAdjustments(asOf: date)
    }

    func loadProgram(programId: String) async {
        let store = ProgramStore.shared
        let userId = services.auth.currentUserId

        // Local-first: paint instantly from the durable copy, then revalidate
        // (cheap id-compare; only a new programId triggers a network fetch).
        if let userId, let cached = store.loadLocal(userId: userId), cached.id == programId {
            self.program = cached
            state = .loaded(cached)
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
            refreshWaveAdjustments()
            await store.revalidate(userId: userId, expectedProgramId: programId)
            if let refreshed = store.program, refreshed.id != cached.id {
                self.program = refreshed
                state = .loaded(refreshed)
                await loadTrackingData()
                refreshWaveAdjustments()
            }
            return
        }

        // No usable local copy (first run / different id) → network, then
        // adopt as the clean local authority.
        state = .loading
        do {
            let fetched: TrainingProgram = try await services.database.read(
                collection: "programs", documentId: programId)
            self.program = fetched
            state = .loaded(fetched)
            if let userId { store.adopt(fetched, userId: userId) }
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
            refreshWaveAdjustments()
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
    }

    func loadTrackingData() async {
        guard let userId = services.auth.currentUserId, let program else { return }
        do {
            async let logsTask = services.workoutLog.fetchLogs(userId: userId, programId: program.id)
            async let progressionTask = ProgressionStateStore.shared.fetchAll(userId: userId)
            let (logs, states) = try await (logsTask, progressionTask)
            workoutLogs = logs.reduce(into: [Int: WorkoutLog]()) { result, log in
                if let existing = result[log.dayNumber], existing.startedAt > log.startedAt {
                    return
                }
                result[log.dayNumber] = log
            }
            progressionStates = Dictionary(
                uniqueKeysWithValues: states.map { (MovementCatalog.normalized($0.exerciseKey), $0) }
            )
        } catch {
            // Non-critical, don't block UI
        }
    }

    func isCompleted(dayNumber: Int) -> Bool {
        workoutLogs[dayNumber] != nil
    }

    func logFor(dayNumber: Int) -> WorkoutLog? {
        workoutLogs[dayNumber]
    }

    func completeRestDay(
        _ day: ProgramDay,
        at date: Date = Date()
    ) async throws -> (performanceLog: PerformanceLog, result: TrainingCompletionResult)? {
        guard day.isRestDay, let program else { return nil }
        guard let userId = services.auth.currentUserId else {
            services.logging.log(
                "completeRestDay: no user id",
                level: .warning,
                context: ["programId": program.id, "dayNumber": day.dayNumber]
            )
            return nil
        }

        let completedAt = Date()
        let durationSeconds = restDayCompletionDurationSeconds(for: day)
        let healthSnapshot = await recoverySnapshot(for: date)
        let vitalityNotes = restDayVitalityNotes(from: healthSnapshot)
        let id = Self.recoveryCompletionId(
            programId: program.id,
            dayNumber: day.dayNumber,
            date: date
        )
        let performanceLog = PerformanceLog(
            id: id,
            userId: userId,
            source: .routine,
            title: "Recovery Day",
            startedAt: completedAt.addingTimeInterval(-TimeInterval(durationSeconds)),
            completedAt: completedAt,
            programId: program.id,
            dayNumber: day.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: .routine,
                    title: "Recovery Summary",
                    exercises: [],
                    durationSeconds: durationSeconds,
                    notes: vitalityNotes
                )
            ],
            notes: vitalityNotes
        )
        let result = try await TrainingCompletionService.shared.complete(
            performanceLog,
            services: services
        )
        return (performanceLog, result)
    }

    private func restDayCompletionDurationSeconds(for day: ProgramDay) -> Int {
        let activeMinutes = day.recoveryActivities.reduce(0) { total, activity in
            let text = "\(activity.name) \(activity.description)".lowercased()
            let isSleepTarget = text.contains("sleep") || text.contains("shutdown")
            return isSleepTarget ? total : total + max(0, activity.durationMinutes)
        }
        return max(300, min(activeMinutes * 60, 90 * 60))
    }

    private func recoverySnapshot(for date: Date) async -> HealthRecoverySnapshot? {
        guard services.health.isHealthDataAvailable else { return nil }
        do {
            return try await services.health.recoverySnapshot(for: date, calendar: .current)
        } catch {
            services.logging.log(
                "HealthKit recovery snapshot unavailable: \(error)",
                level: .info
            )
            return nil
        }
    }

    private func restDayVitalityNotes(from snapshot: HealthRecoverySnapshot?) -> String? {
        guard let snapshot else { return nil }
        let tokens = snapshot.vitalitySignals.map(\.token)
        guard !tokens.isEmpty else { return snapshot.evidenceNote }
        return (tokens + [snapshot.evidenceNote]).joined(separator: " ")
    }

    func selectDay(_ day: ProgramDay) {
        selectedDay = day
        if let program {
            services.analytics.track(.programDayViewed(programId: program.id, dayNumber: day.dayNumber))
        }
    }

    var dailyNutrition: NutritionPlan? {
        program?.nutritionPlan
    }

    var recoveryPlan: RecoveryPlan? {
        program?.recoveryPlan
    }

    // MARK: - Editing
    //
    // Programs are templates. The user can swap exercises and adjust
    // sets/reps inline. All mutations go through these methods so we can
    // route through analytics + persistence in one place.

    /// Swap an exercise in the main block of a given day. Identity (id) is
    /// preserved so workout logs can still link back to the swapped slot.
    func swapExercise(dayNumber: Int, exerciseId: String, replacement: CatalogExercise) {
        mutateMainExercise(dayNumber: dayNumber, exerciseId: exerciseId) { original in
            Exercise(
                id: original.id,
                name: replacement.displayName,
                muscleGroups: replacement.muscleGroups,
                sets: original.sets,
                reps: original.reps,
                restSeconds: original.restSeconds,
                rpe: original.rpe,
                notes: original.notes,
                substitution: original.substitution
            )
        }
        if let originalName = mainExercise(dayNumber: dayNumber, exerciseId: exerciseId)?.name {
            services.analytics.track(.exerciseSwapped(from: originalName, to: replacement.displayName))
        }
    }

    /// Update sets and/or reps on a single exercise. Either parameter can
    /// be nil to leave that field unchanged.
    func updateSetsReps(
        dayNumber: Int,
        exerciseId: String,
        sets: Int? = nil,
        reps: String? = nil
    ) {
        mutateMainExercise(dayNumber: dayNumber, exerciseId: exerciseId) { original in
            var copy = original
            if let sets, sets > 0 { copy.sets = sets }
            if let reps, !reps.trimmingCharacters(in: .whitespaces).isEmpty { copy.reps = reps }
            return copy
        }
    }

    /// Persist the full program. Durable-local-first via ProgramStore (the
    /// edit survives offline / app-kill), then best-effort remote sync.
    func saveProgram() async {
        guard let program else { return }
        guard let userId = services.auth.currentUserId else {
            services.logging.log("saveProgram: no user id", level: .warning,
                                  context: ["programId": program.id])
            return
        }
        await ProgramStore.shared.save(program, userId: userId)
    }

    @discardableResult
    func switchProgramFocus(
        profile: UserProfile,
        trainingStyle: TrainingStyle,
        equipment: Set<Equipment>,
        exerciseStyles: Set<ExerciseStyle>,
        experience: Experience? = nil
    ) async throws -> TrainingProgram {
        guard let userId = services.auth.currentUserId else {
            throw AppError.authNotAuthenticated
        }

        let sortedEquipment = equipment.sorted { $0.rawValue < $1.rawValue }
        let sortedStyles = exerciseStyles.sorted { $0.rawValue < $1.rawValue }
        let resolvedExperience = experience ?? profile.experience
        let generated = try await ProgramGenerationService.shared.generateFromOnboarding(
            userId: userId,
            targetFrequency: profile.targetFrequency,
            equipment: Set(sortedEquipment),
            experience: resolvedExperience,
            sessionLength: profile.sessionLength,
            exerciseStyles: Set(sortedStyles),
            targetAreas: Set(profile.targetAreas ?? []),
            age: profile.age ?? 0,
            gender: profile.gender ?? .unspecified,
            heightCm: profile.heightCm ?? 0,
            weightKg: profile.weightKg ?? 0,
            trainingDays: profile.trainingDays,
            trainingStyleOverride: trainingStyle,
            trainingFeedbackMode: profile.trainingFeedbackMode,
            cutModeActive: profile.cutMode.enabled,
            biologicalSex: profile.biologicalSex
        )
        let protectedGenerated = Self.preservingUserOwnedWorkouts(
            from: program,
            onto: generated,
            userId: userId
        )

        var fields: [String: Any] = [
            "currentProgramId": protectedGenerated.id,
            "equipment": sortedEquipment.map(\.rawValue),
            "exerciseStyles": sortedStyles.map(\.rawValue),
            "trainingStyleOverride": trainingStyle.rawValue
        ]
        if let resolvedExperience {
            fields["experience"] = resolvedExperience.rawValue
        }
        try await services.user.updateProfile(userId: userId, fields: fields)

        program = protectedGenerated
        state = .loaded(protectedGenerated)
        await ProgramStore.shared.save(protectedGenerated, userId: userId)
        await loadTrackingData()
        refreshWaveAdjustments()
        return protectedGenerated
    }

    static func preservingUserOwnedWorkouts(
        from previous: TrainingProgram?,
        onto generated: TrainingProgram,
        userId: String
    ) -> TrainingProgram {
        guard let previous else { return generated }
        let ownedByDay = Dictionary(
            uniqueKeysWithValues: previous.days
                .filter(\.isUserOwnedWorkout)
                .map { ($0.dayNumber, $0) }
        )
        guard !ownedByDay.isEmpty else { return generated }

        var updated = generated
        updated.days = generated.days.map { generatedDay in
            guard let owned = ownedByDay[generatedDay.dayNumber] else { return generatedDay }

            var draft = owned.userWorkoutDraft
            draft?.programId = generated.id
            draft?.dayNumber = generatedDay.dayNumber
            draft?.date = Calendar(identifier: .gregorian).date(
                byAdding: .day,
                value: max(0, generatedDay.dayNumber - 1),
                to: generated.createdAt
            ) ?? generated.createdAt

            return ProgramDay(
                id: generatedDay.id,
                dayNumber: generatedDay.dayNumber,
                label: owned.label,
                isRestDay: owned.isRestDay,
                workout: owned.workout,
                sessionRole: owned.sessionRole,
                savedWorkoutId: owned.savedWorkoutId,
                userWorkoutDraft: draft,
                nutritionOverride: owned.nutritionOverride ?? generatedDay.nutritionOverride,
                recoveryActivities: owned.recoveryActivities
            )
        }
        return updated
    }

    func scheduleSavedWorkout(
        _ savedWorkout: SavedWorkout,
        on dayNumbers: [Int],
        replacingCustomizedDays: Bool = false
    ) async throws {
        guard let current = program else { return }
        guard let userId = services.auth.currentUserId else {
            services.logging.log(
                "scheduleSavedWorkout: no user id",
                level: .warning,
                context: ["programId": current.id, "savedWorkoutId": savedWorkout.id.uuidString]
            )
            return
        }

        let updated = try SavedWorkoutScheduler.schedule(
            savedWorkout,
            on: dayNumbers,
            in: current,
            userId: userId,
            replacingCustomizedDays: replacingCustomizedDays
        )
        program = updated
        if case .loaded = state { state = .loaded(updated) }
        await ProgramStore.shared.save(updated, userId: userId)
        refreshWaveAdjustments()
    }

    func refreshWaveAdjustments(asOf date: Date = Date()) {
        guard let program,
              let userId = services.auth.currentUserId
        else {
            activeWaveAdjustments = []
            return
        }

        let revertedIDs = WaveAdjustmentStore.shared.revertedAdjustmentIDs(
            userId: userId,
            programId: program.id
        )
        activeWaveAdjustments = WaveAdjuster.applyIfNeeded(
            program: program,
            asOf: date,
            appliedAdjustmentIDs: revertedIDs
        ).adjustments
    }

    func revertWaveAdjustment(_ adjustment: WaveAdjustment, asOf date: Date = Date()) {
        guard let program,
              let userId = services.auth.currentUserId
        else { return }

        WaveAdjustmentStore.shared.markReverted(
            adjustment.id,
            userId: userId,
            programId: program.id
        )
        refreshWaveAdjustments(asOf: date)
    }

    func completeCheckpoint(_ outcome: CheckpointOutcome) async {
        guard let current = program else { return }
        guard let userId = services.auth.currentUserId else {
            services.logging.log(
                "completeCheckpoint: no user id",
                level: .warning,
                context: ["programId": current.id]
            )
            return
        }

        let updated = ArcGenerator.generateNextArc(
            from: current,
            checkpoint: outcome,
            startDate: Date()
        )
        program = updated
        if case .loaded = state { state = .loaded(updated) }
        await ProgramStore.shared.save(updated, userId: userId)
        refreshWaveAdjustments()
    }

    // MARK: - Private mutation helpers

    private func mainExercise(dayNumber: Int, exerciseId: String) -> Exercise? {
        guard let program,
              let day = program.days.first(where: { $0.dayNumber == dayNumber }),
              let workout = day.workout
        else { return nil }
        return workout.mainExercises.first(where: { $0.id == exerciseId })
    }

    private func mutateMainExercise(
        dayNumber: Int,
        exerciseId: String,
        _ transform: (Exercise) -> Exercise
    ) {
        guard var program,
              let dayIndex = program.days.firstIndex(where: { $0.dayNumber == dayNumber }),
              var workout = program.days[dayIndex].workout,
              let exIndex = workout.mainExercises.firstIndex(where: { $0.id == exerciseId })
        else { return }

        let updated = transform(workout.mainExercises[exIndex])
        workout.mainExercises[exIndex] = updated
        program.days[dayIndex].workout = workout
        self.program = program
        if case .loaded = state { state = .loaded(program) }
    }

    private static func recoveryCompletionId(
        programId: String,
        dayNumber: Int,
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "recovery-\(programId)-d\(dayNumber)-\(year)-\(month)-\(day)"
    }
}
