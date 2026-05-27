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

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
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
            let logs = try await services.workoutLog.fetchLogs(userId: userId, programId: program.id)
            workoutLogs = logs.reduce(into: [Int: WorkoutLog]()) { result, log in
                if let existing = result[log.dayNumber], existing.startedAt > log.startedAt {
                    return
                }
                result[log.dayNumber] = log
            }
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
