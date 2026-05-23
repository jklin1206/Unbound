import SwiftUI

@MainActor
final class WorkoutLoggingViewModel: ObservableObject {
    @Published var exerciseEntries: [LoggableExercise] = []
    @Published var overallNotes = ""
    @Published var overallRPE: Int?
    @Published var isSaving = false
    @Published var startTime = Date()
    @Published var progressionSuggestions: [String: ProgressionSuggestion] = [:]
    @Published private(set) var lastCompletionResult: TrainingCompletionResult?

    let workout: Workout
    let programId: String
    let dayNumber: Int
    private let services: ServiceContainer
    // MIGRATION(Phase 9): this legacy Program logger is receipt-preview first.
    // New AP/LV/attribute/body-map writes must stay in TrainingCompletionService;
    // the WorkoutLog below is kept only as compatible history until this route is removed.
    private var pendingLegacyLog: WorkoutLog?
    private var pendingPerformanceLog: PerformanceLog?

    struct LoggableExercise: Identifiable {
        let id: String
        var exercise: Exercise
        var sets: [LoggableSet]
        var skipped: Bool
        var notes: String
        var lastWeight: String
        var lastReps: String
        var swapped: Bool = false
    }

    struct LoggableSet: Identifiable {
        let id: String
        var weightKg: String
        var reps: String
        var rpe: Int?
        var isWarmup: Bool
    }

    init(workout: Workout, programId: String, dayNumber: Int, services: ServiceContainer) {
        self.workout = workout
        self.programId = programId
        self.dayNumber = dayNumber
        self.services = services

        self.exerciseEntries = workout.mainExercises.map { exercise in
            let sets = (1...exercise.sets).map { _ in
                LoggableSet(id: UUID().uuidString, weightKg: "", reps: "", rpe: exercise.rpe, isWarmup: false)
            }
            return LoggableExercise(
                id: exercise.id,
                exercise: exercise,
                sets: sets,
                skipped: false,
                notes: "",
                lastWeight: "",
                lastReps: ""
            )
        }

        services.analytics.track(.workoutLoggingStarted(programId: programId, dayNumber: dayNumber))
    }

    func loadWorkingWeights() async {
        guard let userId = services.auth.currentUserId else { return }
        for (index, entry) in exerciseEntries.enumerated() {
            let normalized = entry.exercise.name.lowercased().replacingOccurrences(of: " ", with: "_")
            if let ww = try? await services.workingWeight.fetchWeight(userId: userId, exerciseName: normalized) {
                exerciseEntries[index].lastWeight = displayWeightString(fromKilograms: ww.weightKg)
                exerciseEntries[index].lastReps = "\(ww.lastReps)"
                // Pre-fill weight for all sets
                for setIndex in exerciseEntries[index].sets.indices {
                    if exerciseEntries[index].sets[setIndex].weightKg.isEmpty {
                        exerciseEntries[index].sets[setIndex].weightKg = displayWeightString(fromKilograms: ww.weightKg)
                    }
                }
            }
            if let suggestion = try? await services.workingWeight.getProgressionSuggestion(for: normalized, userId: userId) {
                progressionSuggestions[normalized] = suggestion
                if case .increaseWeight(let amount) = suggestion {
                    services.analytics.track(.progressionSuggestionShown(exerciseName: entry.exercise.name, suggestedIncrease: amount))
                }
            }
        }
    }

    func addSet(to exerciseIndex: Int) {
        let newSet = LoggableSet(id: UUID().uuidString, weightKg: "", reps: "", rpe: nil, isWarmup: false)
        exerciseEntries[exerciseIndex].sets.append(newSet)
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        exerciseEntries[exerciseIndex].sets.remove(at: setIndex)
    }

    func toggleSkip(at index: Int) {
        exerciseEntries[index].skipped.toggle()
    }

    func swapExercise(at index: Int, to replacement: CatalogExercise) {
        guard exerciseEntries.indices.contains(index) else { return }
        let original = exerciseEntries[index].exercise
        let swapped = Exercise(
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
        exerciseEntries[index].exercise = swapped
        exerciseEntries[index].swapped = true
        exerciseEntries[index].lastWeight = ""
        exerciseEntries[index].lastReps = ""
        services.analytics.track(.exerciseSwapped(from: original.name, to: replacement.displayName))
    }

    func alternatives(for index: Int, preferences: [ExercisePreference]) -> [CatalogExercise] {
        guard exerciseEntries.indices.contains(index) else { return [] }
        let current = exerciseEntries[index].exercise.name
        let alternatives = MovementCatalog.catalogAlternatives(to: current)
        let prefsByKey = Dictionary(uniqueKeysWithValues: preferences.map { ($0.exerciseName.lowercased(), $0) })
        return alternatives.filter { alt in
            let pref = prefsByKey[alt.name.lowercased()]
            return pref?.status != .avoid
        }
        .sorted { a, b in
            let aAvail = prefsByKey[a.name.lowercased()]?.status == .available
            let bAvail = prefsByKey[b.name.lowercased()]?.status == .available
            if aAvail != bAvail { return aAvail && !bAvail }
            return a.displayName < b.displayName
        }
    }

    var durationMinutes: Int {
        Int(Date().timeIntervalSince(startTime) / 60)
    }

    var totalSets: Int {
        exerciseEntries.filter { !$0.skipped }.flatMap(\.sets).filter { !$0.isWarmup }.count
    }

    var estimatedVolumeKg: Double {
        exerciseEntries
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .reduce(0) { total, set in
                total + ((kilograms(fromDisplayString: set.weightKg) ?? 0) * Double(Int(set.reps) ?? 0))
            }
    }

    func trainingReceiptSummary(for completionResult: TrainingCompletionResult) -> WorkoutRewardSequenceSummary? {
        guard let performanceLog = pendingPerformanceLog else { return nil }
        return WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completionResult,
            sourceName: "Workout"
        )
    }

    func saveLog() async -> TrainingCompletionResult? {
        guard let userId = services.auth.currentUserId else { return nil }
        isSaving = true

        let entries = exerciseEntries.map { entry in
            ExerciseLogEntry(
                id: UUID().uuidString,
                exerciseName: entry.exercise.name,
                plannedSets: entry.exercise.sets,
                plannedReps: entry.exercise.reps,
                sets: entry.sets.map { set in
                    SetLog(
                        id: set.id,
                        setNumber: entry.sets.firstIndex(where: { $0.id == set.id }).map { $0 + 1 } ?? 1,
                        weightKg: kilograms(fromDisplayString: set.weightKg),
                        reps: Int(set.reps) ?? 0,
                        rpe: set.rpe,
                        isWarmup: set.isWarmup
                    )
                },
                skipped: entry.skipped,
                notes: entry.notes.isEmpty ? nil : entry.notes
            )
        }

        let log = WorkoutLog(
            id: UUID().uuidString,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: workout.name,
            startedAt: startTime,
            completedAt: Date(),
            exerciseEntries: entries,
            overallNotes: overallNotes.isEmpty ? nil : overallNotes,
            overallRPE: overallRPE,
            durationMinutes: durationMinutes
        )
        let performanceLog = performanceLog(from: log)

        let previewResult = TrainingCompletionService.shared.previewProgression(
            for: performanceLog,
            services: services
        )
        lastCompletionResult = previewResult

        pendingLegacyLog = log
        pendingPerformanceLog = performanceLog

        HapticManager.notification(.success)
        isSaving = false
        return previewResult
    }

    func flushPendingCompletionEffects() async {
        guard let log = pendingLegacyLog,
              let performanceLog = pendingPerformanceLog else {
            return
        }

        pendingLegacyLog = nil
        pendingPerformanceLog = nil

        // MIGRATION(Phase 9): the unified receipt/progression write is canonical.
        // The legacy save remains quarantined here so history/old readers survive
        // while replacement UI routes finish proving out.
        async let progressionResult = TrainingCompletionService.shared.recordProgressionForLegacyWorkout(
            performanceLog,
            services: services
        )
        async let legacySave: Void = services.workoutLog.saveLog(log)

        _ = await progressionResult
        do {
            try await legacySave
            services.analytics.track(.workoutLoggingCompleted(
                programId: programId,
                dayNumber: dayNumber,
                durationMinutes: durationMinutes,
                totalSets: totalSets
            ))
        } catch {
            services.logging.log(
                "Legacy workout save failed after completion receipt: \(error)",
                level: .error,
                context: ["programId": programId, "dayNumber": dayNumber]
            )
        }
    }

    private func performanceLog(from log: WorkoutLog) -> PerformanceLog {
        PerformanceLog(
            id: log.id,
            userId: log.userId,
            source: .program,
            title: log.plannedWorkoutName,
            startedAt: log.startedAt,
            completedAt: log.completedAt ?? Date(),
            programId: log.programId,
            dayNumber: log.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: log.plannedWorkoutName,
                    exercises: log.exerciseEntries.map { entry in
                        PerformanceExercise(
                            id: entry.id,
                            name: entry.exerciseName,
                            movementId: entry.movementId,
                            rankStandardMovementId: entry.rankStandardMovementId,
                            plannedSets: entry.plannedSets,
                            plannedTarget: entry.plannedReps,
                            sets: entry.sets.map { set in
                                PerformanceSet(
                                    id: set.id,
                                    setNumber: set.setNumber,
                                    reps: set.reps,
                                    weightKg: set.weightKg,
                                    rpe: set.rpe,
                                    isWarmup: set.isWarmup
                                )
                            },
                            skipped: entry.skipped,
                            notes: entry.notes
                        )
                    }
                )
            ],
            overallRPE: log.overallRPE,
            notes: log.overallNotes
        )
    }

    private func displayWeightString(fromKilograms kilograms: Double) -> String {
        WeightPlatePolicy.formatSuggestionWeight(kilograms, unit: WeightPlatePolicy.currentUnit)
    }

    private func kilograms(fromDisplayString string: String) -> Double? {
        guard let value = Double(string.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        return WeightPlatePolicy.kilograms(fromDisplayValue: value, unit: WeightPlatePolicy.currentUnit)
    }
}
