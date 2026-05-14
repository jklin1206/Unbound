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

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    func loadProgram(programId: String) async {
        state = .loading
        do {
            let program: TrainingProgram = try await services.database.read(collection: "programs", documentId: programId)
            self.program = program
            state = .loaded(program)
            services.analytics.track(.programViewed(programId: programId))
            await loadTrackingData()
        } catch {
            state = .error(.databaseReadFailed(underlying: error))
        }
    }

    func loadTrackingData() async {
        guard let userId = services.auth.currentUserId, let program else { return }
        do {
            let logs = try await services.workoutLog.fetchLogs(userId: userId, programId: program.id)
            workoutLogs = Dictionary(uniqueKeysWithValues: logs.compactMap { log in
                (log.dayNumber, log)
            })
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

    /// Persist the full program back to the document store. Best-effort —
    /// FS errors are logged but not surfaced (the in-memory mutation has
    /// already happened, so the user sees their edit immediately).
    func saveProgram() async {
        guard let program else { return }
        do {
            try await services.database.create(
                program,
                collection: "programs",
                documentId: program.id
            )
        } catch {
            services.logging.log(
                "saveProgram failed: \(error)",
                level: .warning,
                context: ["programId": program.id]
            )
        }
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
}
