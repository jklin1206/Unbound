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
final class ActiveWorkoutSession: ObservableObject {

    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var rpe: Int?
        var isWarmup: Bool
        var logged: Bool
        var suggestedWeightKg: Double?
        var suggestedReps: Int?
        var suggestedRPE: Int?

        init(id: String, weightKg: Double?, reps: Int?, rpe: Int?,
             isWarmup: Bool, logged: Bool,
             suggestedWeightKg: Double? = nil,
             suggestedReps: Int? = nil,
             suggestedRPE: Int? = nil) {
            self.id = id; self.weightKg = weightKg; self.reps = reps
            self.rpe = rpe; self.isWarmup = isWarmup; self.logged = logged
            self.suggestedWeightKg = suggestedWeightKg
            self.suggestedReps = suggestedReps
            self.suggestedRPE = suggestedRPE
        }

        enum CodingKeys: String, CodingKey {
            case id, weightKg, reps, rpe, isWarmup, logged
            case suggestedWeightKg, suggestedReps, suggestedRPE
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
            reps = try c.decodeIfPresent(Int.self, forKey: .reps)
            rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
            isWarmup = try c.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
            logged = try c.decodeIfPresent(Bool.self, forKey: .logged) ?? false
            suggestedWeightKg = try c.decodeIfPresent(Double.self, forKey: .suggestedWeightKg)
            suggestedReps = try c.decodeIfPresent(Int.self, forKey: .suggestedReps)
            suggestedRPE = try c.decodeIfPresent(Int.self, forKey: .suggestedRPE)
        }
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
        var targetRPE: Int?
        var formCues: String?
        var substitution: String?

        init(id: String, name: String, plannedSets: Int, plannedReps: String,
             restSeconds: Int, muscleGroups: [MuscleGroup], sets: [ActiveSet],
             skipped: Bool, notes: String,
             targetRPE: Int? = nil, formCues: String? = nil,
             substitution: String? = nil) {
            self.id = id; self.name = name; self.plannedSets = plannedSets
            self.plannedReps = plannedReps; self.restSeconds = restSeconds
            self.muscleGroups = muscleGroups; self.sets = sets
            self.skipped = skipped; self.notes = notes
            self.targetRPE = targetRPE; self.formCues = formCues
            self.substitution = substitution
        }

        enum CodingKeys: String, CodingKey {
            case id, name, plannedSets, plannedReps, restSeconds
            case muscleGroups, sets, skipped, notes
            case targetRPE, formCues, substitution
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            plannedSets = try c.decodeIfPresent(Int.self, forKey: .plannedSets) ?? 0
            plannedReps = try c.decodeIfPresent(String.self, forKey: .plannedReps) ?? ""
            restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 0
            muscleGroups = try c.decodeIfPresent([MuscleGroup].self, forKey: .muscleGroups) ?? []
            sets = try c.decodeIfPresent([ActiveSet].self, forKey: .sets) ?? []
            skipped = try c.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
            notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
            targetRPE = try c.decodeIfPresent(Int.self, forKey: .targetRPE)
            formCues = try c.decodeIfPresent(String.self, forKey: .formCues)
            substitution = try c.decodeIfPresent(String.self, forKey: .substitution)
        }
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
                              rpe: nil, isWarmup: false, logged: false,
                              suggestedWeightKg: nil,
                              suggestedReps: RepRange.lowerBound(ex.reps),
                              suggestedRPE: ex.rpe)
                },
                skipped: false,
                notes: "",
                targetRPE: ex.rpe,
                formCues: ex.notes,
                substitution: ex.substitution
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
                      rpe: nil, isWarmup: false, logged: false))
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

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
    }

    func setRPE(exerciseIndex ei: Int, setIndex si: Int, _ rpe: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].rpe = rpe
    }

    /// One-tap "did it as planned": copy the program's suggestion into the
    /// actual values and log. No-op if already logged or indices invalid.
    func confirmAsPlanned(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si),
              !exercises[ei].sets[si].logged else { return }
        exercises[ei].sets[si].weightKg = exercises[ei].sets[si].suggestedWeightKg
        exercises[ei].sets[si].reps = exercises[ei].sets[si].suggestedReps
        exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
        exercises[ei].sets[si].logged = true
    }

    /// Implicit logging: a set is logged once weight AND reps are both set.
    /// Never un-logs. Returns true only on the false→true edge so the caller
    /// can fire the haptic + rest exactly once.
    @discardableResult
    func recomputeLogged(exerciseIndex ei: Int, setIndex si: Int) -> Bool {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return false }
        let was = exercises[ei].sets[si].logged
        let complete = exercises[ei].sets[si].weightKg != nil
            && exercises[ei].sets[si].reps != nil
        if complete { exercises[ei].sets[si].logged = true }
        return complete && !was
    }

    func addSet(toExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei) else { return }
        exercises[ei].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false))
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
                        rpe: set.rpe,
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
