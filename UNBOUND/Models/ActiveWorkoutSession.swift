import Foundation
import Combine

@MainActor
final class ActiveWorkoutSession: ObservableObject {

    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var effort: Effort?
        var isWarmup: Bool
        var logged: Bool
    }

    struct ActiveExercise: Identifiable, Codable, Sendable {
        let id: String
        var name: String
        var plannedSets: Int
        var plannedReps: String
        var restSeconds: Int
        var muscleGroups: [MuscleGroup]
        var sets: [ActiveSet]
        var skipped: Bool
        var notes: String
    }

    struct Snapshot: Codable, Sendable {
        let id: String
        let programId: String
        let dayNumber: Int
        let plannedWorkoutName: String
        let startedAt: Date
        var exercises: [ActiveExercise]
        var currentExerciseIndex: Int
        var currentSetIndex: Int
    }

    let id: String
    let programId: String
    let dayNumber: Int
    let plannedWorkoutName: String
    let startedAt: Date

    @Published var exercises: [ActiveExercise]
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0

    init(workout: Workout, programId: String, dayNumber: Int) {
        self.id = UUID().uuidString
        self.programId = programId
        self.dayNumber = dayNumber
        self.plannedWorkoutName = workout.name
        self.startedAt = Date()
        self.exercises = workout.mainExercises.map { ex in
            ActiveExercise(
                id: ex.id,
                name: ex.name,
                plannedSets: ex.sets,
                plannedReps: ex.reps,
                restSeconds: RestPrescription.restSeconds(for: ex),
                muscleGroups: ex.muscleGroups,
                sets: (0..<max(1, ex.sets)).map { _ in
                    ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                              effort: nil, isWarmup: false, logged: false)
                },
                skipped: false,
                notes: ""
            )
        }
    }

    init(snapshot s: Snapshot) {
        self.id = s.id
        self.programId = s.programId
        self.dayNumber = s.dayNumber
        self.plannedWorkoutName = s.plannedWorkoutName
        self.startedAt = s.startedAt
        self.exercises = s.exercises
        self.currentExerciseIndex = min(s.currentExerciseIndex, max(0, s.exercises.count - 1))
        self.currentSetIndex = s.currentSetIndex
    }

    func snapshot() -> Snapshot {
        Snapshot(id: id, programId: programId, dayNumber: dayNumber,
                 plannedWorkoutName: plannedWorkoutName, startedAt: startedAt,
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

    func logCurrentSet(weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        exercises[currentExerciseIndex].sets[currentSetIndex].weightKg = weightKg
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        exercises[currentExerciseIndex].sets[currentSetIndex].logged = true
    }

    func setEffort(_ effort: Effort) {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
        exercises[currentExerciseIndex].sets[currentSetIndex].effort = effort
    }

    func toggleCurrentWarmup() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else { return }
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
        }
    }

    func jumpToExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        currentSetIndex = 0
    }

    func addSetToCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        exercises[currentExerciseIndex].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      effort: nil, isWarmup: false, logged: false))
    }

    func removeLastSetFromCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex),
              exercises[currentExerciseIndex].sets.count > 1 else { return }
        exercises[currentExerciseIndex].sets.removeLast()
        if currentSetIndex >= exercises[currentExerciseIndex].sets.count {
            currentSetIndex = exercises[currentExerciseIndex].sets.count - 1
        }
    }

    func skipCurrentExercise() {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        exercises[currentExerciseIndex].skipped = true
        advanceToNextUnskippedExercise(after: currentExerciseIndex)
    }

    func setNotes(_ text: String, forExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].notes = text
    }

    // MARK: Index-addressed mutators (grid logs any set in any order)

    private static let effortCycle: [Effort] = [.easy, .solid, .hard]

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
        if exercises[ei].sets[si].effort == nil {
            exercises[ei].sets[si].effort = .solid
        }
    }

    func setEffort(exerciseIndex ei: Int, setIndex si: Int, _ effort: Effort) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].effort = effort
    }

    func cycleEffort(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        let current = exercises[ei].sets[si].effort ?? .solid
        let idx = Self.effortCycle.firstIndex(of: current) ?? 1
        exercises[ei].sets[si].effort = Self.effortCycle[(idx + 1) % Self.effortCycle.count]
    }

    func addSet(toExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei) else { return }
        exercises[ei].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      effort: nil, isWarmup: false, logged: false))
    }

    func removeLastSet(fromExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.count > 1 else { return }
        exercises[ei].sets.removeLast()
    }

    func assembleWorkoutLog(userId: String) -> WorkoutLog {
        let entries = exercises.map { ex in
            ExerciseLogEntry(
                id: UUID().uuidString,
                exerciseName: ex.name,
                plannedSets: ex.plannedSets,
                plannedReps: ex.plannedReps,
                sets: ex.sets.enumerated().compactMap { (i, set) in
                    guard set.logged else { return nil }
                    return SetLog(
                        id: set.id,
                        setNumber: i + 1,
                        weightKg: set.weightKg,
                        reps: set.reps ?? 0,
                        rpe: set.effort?.rpe,
                        isWarmup: set.isWarmup
                    )
                },
                skipped: ex.skipped,
                notes: ex.notes.isEmpty ? nil : ex.notes
            )
        }
        return WorkoutLog(
            id: id,
            userId: userId,
            programId: programId,
            dayNumber: dayNumber,
            plannedWorkoutName: plannedWorkoutName,
            startedAt: startedAt,
            completedAt: Date(),
            exerciseEntries: entries,
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: max(0, Int(Date().timeIntervalSince(startedAt) / 60))
        )
    }
}
