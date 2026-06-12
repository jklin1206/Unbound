import Foundation
import Combine

/// First integer run in a rep prescription string. "8-10"→8, "30s"→30,
/// "12 each side"→12, "AMRAP"→nil, ""→nil.
enum RepRange {
    static func lowerBound(_ s: String) -> Int? {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits)
    }
}

@MainActor
final class ActiveWorkoutSession: ObservableObject, Identifiable {

    let id: String
    let programId: String
    let dayNumber: Int
    let plannedWorkoutName: String
    let startedAt: Date
    let source: TrainingSessionSource

    @Published var exercises: [ActiveExercise]
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0

    init(workout: Workout, programId: String, dayNumber: Int, source: TrainingSessionSource = .program) {
        self.id = UUID().uuidString
        self.programId = programId
        self.dayNumber = dayNumber
        self.plannedWorkoutName = workout.name
        self.startedAt = Date()
        self.source = source
        self.exercises = workout.mainExercises.map { ex in
            let definition = Self.movementDefinition(for: ex.name)
            let metricKind = Self.metricKind(
                for: ex.reps,
                definitionDefault: definition?.defaultMetric
            )
            return ActiveExercise(
                id: ex.id,
                name: ex.name,
                plannedSets: ex.sets,
                plannedReps: ex.reps,
                restSeconds: RestPrescription.restSeconds(for: ex),
                muscleGroups: ex.muscleGroups,
                sets: (0..<max(1, ex.sets)).map { _ in
                    ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                              rpe: nil, isWarmup: false, logged: false,
                              suggestedWeightKg: nil,
                              suggestedReps: metricKind == .reps ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedHoldSeconds: metricKind == .holdSeconds ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedDurationSeconds: metricKind == .durationSeconds ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedDistanceMeters: metricKind == .distanceMeters ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedCalories: metricKind == .calories ? RepRange.lowerBound(ex.reps) : nil,
                              suggestedRPE: ex.rpe,
                              suggestedRestSeconds: RestPrescription.restSeconds(for: ex))
                },
                skipped: false,
                notes: "",
                movementId: definition?.id,
                rankStandardMovementId: definition?.rankStandardMovementId,
                targetRPE: ex.rpe,
                formCues: ex.notes,
                substitution: ex.substitution,
                blockKind: definition?.blockKind ?? .strength,
                skillId: definition?.skillId,
                cardioType: definition?.cardioType,
                tracksHold: definition?.blockKind == .carry || metricKind == .holdSeconds || metricKind == .durationSeconds,
                metricKind: metricKind
            )
        }
        markCurrentExerciseStarted(at: startedAt)
    }

    init(snapshot s: Snapshot) {
        self.id = s.id
        self.programId = s.programId
        self.dayNumber = s.dayNumber
        self.plannedWorkoutName = s.plannedWorkoutName
        self.startedAt = s.startedAt
        self.source = s.source ?? .program
        self.exercises = s.exercises
        self.currentExerciseIndex = min(s.currentExerciseIndex, max(0, s.exercises.count - 1))
        self.currentSetIndex = s.currentSetIndex
        markCurrentExerciseStarted()
    }

    func snapshot() -> Snapshot {
        Snapshot(id: id, programId: programId, dayNumber: dayNumber,
                 plannedWorkoutName: plannedWorkoutName, startedAt: startedAt, source: source,
                 exercises: exercises, currentExerciseIndex: currentExerciseIndex,
                 currentSetIndex: currentSetIndex)
    }

    var currentExercise: ActiveExercise? {
        exercises.indices.contains(currentExerciseIndex) ? exercises[currentExerciseIndex] : nil
    }

    var isLastSetOfWorkout: Bool {
        guard let last = exercises.indices.last else { return true }
        let lastActiveIdx = exercises.lastIndex(where: { !$0.skipped }) ?? last
        guard currentExerciseIndex == lastActiveIdx else { return false }
        return currentSetIndex >= exercises[lastActiveIdx].sets.count - 1
    }

    var hasUnloggedWorkingSets: Bool {
        exercises.contains { exercise in
            !exercise.skipped && exercise.sets.contains { !$0.isWarmup && !$0.logged }
        }
    }

    var progressSummary: ProgressSummary {
        let workSets = exercises
            .filter { !$0.skipped }
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
        let logged = workSets.filter(\.logged).count
        return ProgressSummary(
            loggedWorkingSets: logged,
            totalWorkingSets: workSets.count
        )
    }

    func logCurrentSet(weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        objectWillChange.send()
        markExerciseStarted(exerciseIndex: currentExerciseIndex)
        exercises[currentExerciseIndex].sets[currentSetIndex].weightKg = weightKg
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        exercises[currentExerciseIndex].sets[currentSetIndex].logged = true
        markExerciseCompletedIfReady(exerciseIndex: currentExerciseIndex)
    }

    func toggleCurrentWarmup() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].sets[currentSetIndex].isWarmup.toggle()
    }

    func advance() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        if currentSetIndex < exercises[currentExerciseIndex].sets.count - 1 {
            currentSetIndex += 1
        } else {
            advanceToNextUnskippedExercise(after: currentExerciseIndex)
        }
    }

    private func advanceToNextUnskippedExercise(after idx: Int) {
        var next = idx + 1
        while next < exercises.count && exercises[next].skipped { next += 1 }
        if next < exercises.count {
            currentExerciseIndex = next
            currentSetIndex = 0
            markCurrentExerciseStarted()
        }
    }

    func jumpToExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        currentSetIndex = 0
        markCurrentExerciseStarted()
    }

    func addSetToCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let exercise = exercises[currentExerciseIndex]
        objectWillChange.send()
        exercises[currentExerciseIndex].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false,
                      suggestedReps: exercise.metricKind == .reps ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedHoldSeconds: exercise.metricKind == .holdSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDurationSeconds: exercise.metricKind == .durationSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDistanceMeters: exercise.metricKind == .distanceMeters ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedCalories: exercise.metricKind == .calories ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedRPE: exercise.targetRPE,
                      suggestedRestSeconds: exercise.restSeconds))
    }

    func removeLastSetFromCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.count > 1 else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].sets.removeLast()
        if currentSetIndex >= exercises[currentExerciseIndex].sets.count {
            currentSetIndex = exercises[currentExerciseIndex].sets.count - 1
        }
    }

    func skipCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        objectWillChange.send()
        exercises[currentExerciseIndex].skipped = true
        advanceToNextUnskippedExercise(after: currentExerciseIndex)
    }

    func setNotes(_ text: String, forExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        objectWillChange.send()
        exercises[index].notes = text
    }

    func replaceExercise(at index: Int, with alternative: CatalogExercise) {
        guard exercises.indices.contains(index) else { return }
        let previousName = exercises[index].name
        let definition = Self.movementDefinition(for: alternative.displayName)
            ?? MovementCatalog.canonicalExercise(named: alternative.name)
        let resolved = MovementResolver.resolve(alternative.displayName)
        let metricKind = Self.metricKind(
            for: exercises[index].plannedReps,
            definitionDefault: definition?.defaultMetric
        )

        objectWillChange.send()
        exercises[index].name = alternative.displayName
        exercises[index].movementId = definition?.id ?? resolved.movementId
        exercises[index].rankStandardMovementId = definition?.rankStandardMovementId ?? resolved.rankStandardMovementId
        exercises[index].muscleGroups = alternative.muscleGroups
        exercises[index].blockKind = definition?.blockKind ?? exercises[index].blockKind
        exercises[index].skillId = definition?.skillId
        exercises[index].cardioType = definition?.cardioType
        exercises[index].metricKind = metricKind
        exercises[index].tracksHold = definition?.blockKind == .carry || metricKind == .holdSeconds || metricKind == .durationSeconds
        exercises[index].substitution = "Swapped from \(previousName)"

        for setIndex in exercises[index].sets.indices where !exercises[index].sets[setIndex].logged {
            exercises[index].sets[setIndex].suggestedReps = metricKind == .reps
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedHoldSeconds = metricKind == .holdSeconds
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedDurationSeconds = metricKind == .durationSeconds
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedDistanceMeters = metricKind == .distanceMeters
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
            exercises[index].sets[setIndex].suggestedCalories = metricKind == .calories
                ? RepRange.lowerBound(exercises[index].plannedReps)
                : nil
        }
    }

    func markCurrentExerciseStarted(at date: Date = Date()) {
        markExerciseStarted(exerciseIndex: currentExerciseIndex, at: date)
    }

    func markExerciseStarted(exerciseIndex index: Int, at date: Date = Date()) {
        guard exercises.indices.contains(index), exercises[index].startedAt == nil else { return }
        exercises[index].startedAt = date
    }

    func markExerciseCompletedIfReady(exerciseIndex index: Int, at date: Date = Date()) {
        guard exercises.indices.contains(index) else { return }
        let workingSets = exercises[index].sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty, workingSets.allSatisfy(\.logged) else { return }
        exercises[index].completedAt = date
    }

    private static func movementDefinition(for exerciseName: String) -> MovementDefinition? {
        let resolved = MovementResolver.resolve(exerciseName)
        return MovementCatalog.definition(for: resolved.movementId)
    }

    private static func metricKind(
        for plannedReps: String,
        definitionDefault: TrainingMetricKind?
    ) -> TrainingMetricKind {
        let lowercased = plannedReps.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.contains("cal") {
            return .calories
        }
        if lowercased.contains("meter")
            || lowercased.range(of: #"\d\s*m\b"#, options: .regularExpression) != nil {
            return .distanceMeters
        }
        if lowercased.contains("sec")
            || lowercased.contains("second")
            || lowercased.range(of: #"\d\s*s\b"#, options: .regularExpression) != nil {
            return definitionDefault == .durationSeconds ? .durationSeconds : .holdSeconds
        }
        return definitionDefault ?? .reps
    }
}
