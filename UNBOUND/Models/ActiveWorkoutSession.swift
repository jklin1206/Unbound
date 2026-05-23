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
    struct ProgressSummary: Equatable, Sendable {
        let loggedWorkingSets: Int
        let totalWorkingSets: Int

        var remainingWorkingSets: Int {
            max(0, totalWorkingSets - loggedWorkingSets)
        }

        var isComplete: Bool {
            remainingWorkingSets == 0
        }

        var footerText: String {
            guard totalWorkingSets > 0 else { return "No work sets planned" }
            if isComplete { return "Ready to finish" }
            let setWord = remainingWorkingSets == 1 ? "set" : "sets"
            return "\(loggedWorkingSets)/\(totalWorkingSets) work sets logged · \(remainingWorkingSets) \(setWord) left"
        }
    }

    struct ActiveSet: Identifiable, Codable, Sendable {
        let id: String
        var weightKg: Double?
        var reps: Int?
        var rpe: Int?
        var holdSeconds: Int?
        var durationSeconds: Int?
        var distanceMeters: Int?
        var calories: Int?
        var isWarmup: Bool
        var logged: Bool
        var suggestedWeightKg: Double?
        var suggestedReps: Int?
        var suggestedHoldSeconds: Int?
        var suggestedDurationSeconds: Int?
        var suggestedDistanceMeters: Int?
        var suggestedCalories: Int?
        var suggestedRPE: Int?

        init(id: String, weightKg: Double?, reps: Int?, rpe: Int?,
             isWarmup: Bool, logged: Bool,
             suggestedWeightKg: Double? = nil,
             suggestedReps: Int? = nil,
             holdSeconds: Int? = nil,
             suggestedHoldSeconds: Int? = nil,
             durationSeconds: Int? = nil,
             suggestedDurationSeconds: Int? = nil,
             distanceMeters: Int? = nil,
             suggestedDistanceMeters: Int? = nil,
             calories: Int? = nil,
             suggestedCalories: Int? = nil,
             suggestedRPE: Int? = nil) {
            self.id = id; self.weightKg = weightKg; self.reps = reps
            self.rpe = rpe; self.holdSeconds = holdSeconds
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.calories = calories
            self.isWarmup = isWarmup; self.logged = logged
            self.suggestedWeightKg = suggestedWeightKg
            self.suggestedReps = suggestedReps
            self.suggestedHoldSeconds = suggestedHoldSeconds
            self.suggestedDurationSeconds = suggestedDurationSeconds
            self.suggestedDistanceMeters = suggestedDistanceMeters
            self.suggestedCalories = suggestedCalories
            self.suggestedRPE = suggestedRPE
        }

        enum CodingKeys: String, CodingKey {
            case id, weightKg, reps, rpe, isWarmup, logged
            case holdSeconds, durationSeconds, distanceMeters, calories
            case suggestedWeightKg, suggestedReps, suggestedHoldSeconds
            case suggestedDurationSeconds, suggestedDistanceMeters, suggestedCalories, suggestedRPE
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
            reps = try c.decodeIfPresent(Int.self, forKey: .reps)
            rpe = try c.decodeIfPresent(Int.self, forKey: .rpe)
            holdSeconds = try c.decodeIfPresent(Int.self, forKey: .holdSeconds)
            durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
            distanceMeters = try c.decodeIfPresent(Int.self, forKey: .distanceMeters)
            calories = try c.decodeIfPresent(Int.self, forKey: .calories)
            isWarmup = try c.decodeIfPresent(Bool.self, forKey: .isWarmup) ?? false
            logged = try c.decodeIfPresent(Bool.self, forKey: .logged) ?? false
            suggestedWeightKg = try c.decodeIfPresent(Double.self, forKey: .suggestedWeightKg)
            suggestedReps = try c.decodeIfPresent(Int.self, forKey: .suggestedReps)
            suggestedHoldSeconds = try c.decodeIfPresent(Int.self, forKey: .suggestedHoldSeconds)
            suggestedDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .suggestedDurationSeconds)
            suggestedDistanceMeters = try c.decodeIfPresent(Int.self, forKey: .suggestedDistanceMeters)
            suggestedCalories = try c.decodeIfPresent(Int.self, forKey: .suggestedCalories)
            suggestedRPE = try c.decodeIfPresent(Int.self, forKey: .suggestedRPE)
        }
    }

    struct ActiveExercise: Identifiable, Codable, Sendable {
        let id: String
        var name: String
        var movementId: String?
        var rankStandardMovementId: String?
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
        var blockKind: TrainingBlockKind
        var blockId: String?
        var blockTitle: String?
        var skillId: String?
        var routineId: String?
        var cardioType: CardioType?
        var tracksHold: Bool
        var metricKind: TrainingMetricKind

        init(id: String, name: String, plannedSets: Int, plannedReps: String,
             restSeconds: Int, muscleGroups: [MuscleGroup], sets: [ActiveSet],
             skipped: Bool, notes: String,
             movementId: String? = nil,
             rankStandardMovementId: String? = nil,
             targetRPE: Int? = nil, formCues: String? = nil,
             substitution: String? = nil,
             blockKind: TrainingBlockKind = .strength,
             blockId: String? = nil,
             blockTitle: String? = nil,
             skillId: String? = nil,
             routineId: String? = nil,
             cardioType: CardioType? = nil,
             tracksHold: Bool = false,
             metricKind: TrainingMetricKind = .reps) {
            let resolved = MovementResolver.resolve(name)
            self.id = id; self.name = name; self.plannedSets = plannedSets
            self.movementId = movementId ?? resolved.movementId
            self.rankStandardMovementId = rankStandardMovementId ?? resolved.rankStandardMovementId
            self.plannedReps = plannedReps; self.restSeconds = restSeconds
            self.muscleGroups = muscleGroups; self.sets = sets
            self.skipped = skipped; self.notes = notes
            self.targetRPE = targetRPE; self.formCues = formCues
            self.substitution = substitution
            self.blockKind = blockKind
            self.blockId = blockId
            self.blockTitle = blockTitle
            self.skillId = skillId
            self.routineId = routineId
            self.cardioType = cardioType
            self.tracksHold = tracksHold
            self.metricKind = metricKind
        }

        enum CodingKeys: String, CodingKey {
            case id, name, plannedSets, plannedReps, restSeconds
            case muscleGroups, sets, skipped, notes
            case movementId, rankStandardMovementId
            case targetRPE, formCues, substitution
            case blockKind, blockId, blockTitle, skillId, routineId, cardioType, tracksHold, metricKind
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = try c.decode(String.self, forKey: .name)
            let resolved = MovementResolver.resolve(name)
            movementId = try c.decodeIfPresent(String.self, forKey: .movementId) ?? resolved.movementId
            rankStandardMovementId = try c.decodeIfPresent(String.self, forKey: .rankStandardMovementId) ?? resolved.rankStandardMovementId
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
            blockKind = try c.decodeIfPresent(TrainingBlockKind.self, forKey: .blockKind) ?? .strength
            blockId = try c.decodeIfPresent(String.self, forKey: .blockId)
            blockTitle = try c.decodeIfPresent(String.self, forKey: .blockTitle)
            skillId = try c.decodeIfPresent(String.self, forKey: .skillId)
            routineId = try c.decodeIfPresent(String.self, forKey: .routineId)
            cardioType = try c.decodeIfPresent(CardioType.self, forKey: .cardioType)
            tracksHold = try c.decodeIfPresent(Bool.self, forKey: .tracksHold) ?? false
            metricKind = try c.decodeIfPresent(TrainingMetricKind.self, forKey: .metricKind) ?? (tracksHold ? .holdSeconds : .reps)
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
                substitution: ex.substitution,
                blockKind: .strength
            )
        }
    }

    init(snapshot s: Snapshot) {
        self.id = s.id
        self.programId = s.programId
        self.dayNumber = s.dayNumber
        self.plannedWorkoutName = s.plannedWorkoutName
        self.startedAt = s.startedAt
        self.source = .program
        self.exercises = s.exercises
        self.currentExerciseIndex = min(s.currentExerciseIndex, max(0, s.exercises.count - 1))
        self.currentSetIndex = s.currentSetIndex
    }

    convenience init(trainingDraft draft: TrainingSessionDraft) {
        self.init(workout: TrainingSessionAdapters.workout(from: draft),
                  programId: draft.programId ?? draft.source.rawValue,
                  dayNumber: draft.dayNumber ?? 0,
                  source: draft.source)
        self.exercises = Self.activeExercises(from: draft)
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
        exercises[currentExerciseIndex].sets[currentSetIndex].weightKg = weightKg
        exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        exercises[currentExerciseIndex].sets[currentSetIndex].logged = true
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
        }
    }

    private func advanceAfterLogging(exerciseIndex ei: Int, setIndex si: Int) {
        guard currentExerciseIndex == ei, currentSetIndex == si else { return }

        if let nextSet = exercises[ei].sets.indices.first(where: { $0 > si && !exercises[ei].sets[$0].logged }) {
            currentSetIndex = nextSet
            return
        }

        if let nextExercise = exercises.indices.first(where: { idx in
            idx > ei && !exercises[idx].skipped && exercises[idx].sets.contains(where: { !$0.logged })
        }) {
            currentExerciseIndex = nextExercise
            currentSetIndex = exercises[nextExercise].sets.firstIndex(where: { !$0.logged }) ?? 0
        }
    }

    func jumpToExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        currentSetIndex = 0
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
                      suggestedRPE: exercise.targetRPE))
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

    // MARK: Index-addressed mutators (grid logs any set in any order)

    func logSet(exerciseIndex ei: Int, setIndex si: Int, weightKg: Double?, reps: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        exercises[ei].sets[si].weightKg = weightKg
        exercises[ei].sets[si].reps = reps
        exercises[ei].sets[si].logged = true
    }

    func setRPE(exerciseIndex ei: Int, setIndex si: Int, _ rpe: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        objectWillChange.send()
        exercises[ei].sets[si].rpe = rpe
    }

    /// One-tap "did it as planned": copy the program's suggestion into the
    /// actual values and log. No-op if already logged or indices invalid.
    func confirmAsPlanned(exerciseIndex ei: Int, setIndex si: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si),
              !exercises[ei].sets[si].logged else { return }
        objectWillChange.send()
        exercises[ei].sets[si].weightKg = exercises[ei].sets[si].suggestedWeightKg
        exercises[ei].sets[si].reps = exercises[ei].sets[si].suggestedReps
        exercises[ei].sets[si].holdSeconds = exercises[ei].sets[si].suggestedHoldSeconds
        exercises[ei].sets[si].durationSeconds = exercises[ei].sets[si].suggestedDurationSeconds
        exercises[ei].sets[si].distanceMeters = exercises[ei].sets[si].suggestedDistanceMeters
        exercises[ei].sets[si].calories = exercises[ei].sets[si].suggestedCalories
        exercises[ei].sets[si].rpe = exercises[ei].sets[si].suggestedRPE
        exercises[ei].sets[si].logged = true
        advanceAfterLogging(exerciseIndex: ei, setIndex: si)
    }

    /// Implicit logging: a set is logged once weight AND reps are both set.
    /// Never un-logs. Returns true only on the false→true edge so the caller
    /// can fire the haptic + rest exactly once.
    @discardableResult
    func recomputeLogged(exerciseIndex ei: Int, setIndex si: Int) -> Bool {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return false }
        let was = exercises[ei].sets[si].logged
        let complete = exercises[ei].sets[si].hasMetric(exercises[ei].metricKind)
        if complete {
            objectWillChange.send()
            exercises[ei].sets[si].logged = true
            advanceAfterLogging(exerciseIndex: ei, setIndex: si)
        }
        return complete && !was
    }

    func addSet(toExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei) else { return }
        let exercise = exercises[ei]
        objectWillChange.send()
        exercises[ei].sets.append(
            ActiveSet(id: UUID().uuidString, weightKg: nil, reps: nil,
                      rpe: nil, isWarmup: false, logged: false,
                      suggestedReps: exercise.metricKind == .reps ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedHoldSeconds: exercise.metricKind == .holdSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDurationSeconds: exercise.metricKind == .durationSeconds ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedDistanceMeters: exercise.metricKind == .distanceMeters ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedCalories: exercise.metricKind == .calories ? RepRange.lowerBound(exercise.plannedReps) : nil,
                      suggestedRPE: exercise.targetRPE))
    }

    func removeLastSet(fromExerciseIndex ei: Int) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.count > 1 else { return }
        objectWillChange.send()
        exercises[ei].sets.removeLast()
    }

    func assembleWorkoutLog(userId: String) -> WorkoutLog {
        let entries = exercises.map { ex in
            ExerciseLogEntry(
                id: UUID().uuidString,
                exerciseName: ex.name,
                movementId: ex.movementId,
                rankStandardMovementId: ex.rankStandardMovementId,
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

    func assemblePerformanceLog(userId: String) -> PerformanceLog {
        return PerformanceLog(
            id: id,
            userId: userId,
            source: source,
            title: plannedWorkoutName,
            startedAt: startedAt,
            completedAt: Date(),
            programId: programId,
            dayNumber: dayNumber,
            blocks: performanceBlocks()
        )
    }

    private func performanceBlocks() -> [PerformanceBlock] {
        var orderedKeys: [String] = []
        var grouped: [String: [ActiveExercise]] = [:]

        for exercise in exercises {
            let key = exercise.blockId ?? "\(exercise.blockKind.rawValue):\(exercise.skillId ?? "")"
            if grouped[key] == nil { orderedKeys.append(key) }
            grouped[key, default: []].append(exercise)
        }

        return orderedKeys.compactMap { key in
            guard let group = grouped[key], let first = group.first else { return nil }
            let title = first.blockKind == .skill
                ? (SkillGraph.shared.node(id: first.skillId ?? "")?.title ?? first.name)
                : (first.blockTitle ?? plannedWorkoutName)
            return PerformanceBlock(
                kind: first.blockKind,
                title: title,
                skillId: first.skillId,
                routineId: first.routineId,
                cardioType: first.cardioType,
                exercises: group.map { exercise in
                    PerformanceExercise(
                        id: exercise.id,
                        name: exercise.name,
                        movementId: exercise.movementId,
                        rankStandardMovementId: exercise.rankStandardMovementId,
                        plannedSets: exercise.plannedSets,
                        plannedTarget: exercise.plannedReps,
                        sets: exercise.sets.enumerated().compactMap { index, set in
                            guard set.logged else { return nil }
                            return PerformanceSet(
                                id: set.id,
                                setNumber: index + 1,
                                reps: exercise.metricKind == .reps ? set.reps : nil,
                                weightKg: set.weightKg,
                                holdSeconds: exercise.metricKind == .holdSeconds ? set.holdSeconds : nil,
                                durationSeconds: exercise.metricKind == .durationSeconds ? set.durationSeconds : nil,
                                distanceMeters: exercise.metricKind == .distanceMeters ? set.distanceMeters : nil,
                                calories: exercise.metricKind == .calories ? set.calories : nil,
                                rpe: set.rpe,
                                isWarmup: set.isWarmup
                            )
                        },
                        skipped: exercise.skipped,
                        notes: exercise.notes.isEmpty ? nil : exercise.notes
                    )
                }
            )
        }
    }

    private static func activeExercises(from draft: TrainingSessionDraft) -> [ActiveExercise] {
        draft.blocks.flatMap { block in
            block.prescriptions.map { prescription in
                let definition = movementDefinition(for: prescription)
                let metricKind = prescription.target.metricKind(defaultingTo: definition?.defaultMetric)
                return ActiveExercise(
                    id: prescription.id,
                    name: prescription.exerciseName,
                    plannedSets: prescription.sets,
                    plannedReps: prescription.target.displayText,
                    restSeconds: prescription.restSeconds,
                    muscleGroups: prescription.muscleGroups,
                    sets: (0..<max(1, prescription.sets)).map { _ in
                        ActiveSet(
                            id: UUID().uuidString,
                            weightKg: nil,
                            reps: nil,
                            rpe: nil,
                            isWarmup: false,
                            logged: false,
                            suggestedWeightKg: nil,
                            suggestedReps: metricKind == .reps ? prescription.target.metricLowerBound : nil,
                            suggestedHoldSeconds: metricKind == .holdSeconds ? prescription.target.metricLowerBound : nil,
                            suggestedDurationSeconds: metricKind == .durationSeconds ? prescription.target.metricLowerBound : nil,
                            suggestedDistanceMeters: metricKind == .distanceMeters ? prescription.target.metricLowerBound : nil,
                            suggestedCalories: metricKind == .calories ? prescription.target.metricLowerBound : nil,
                            suggestedRPE: prescription.rpe
                        )
                    },
                    skipped: false,
                    notes: "",
                    movementId: prescription.movementId,
                    rankStandardMovementId: prescription.rankStandardMovementId,
                    targetRPE: prescription.rpe,
                    formCues: prescription.notes,
                    substitution: nil,
                    blockKind: block.kind,
                    blockId: block.id,
                    blockTitle: block.title,
                    skillId: block.skillId,
                    routineId: block.routineId,
                    cardioType: block.cardioType,
                    tracksHold: block.kind == .carry || metricKind == .holdSeconds || metricKind == .durationSeconds,
                    metricKind: metricKind
                )
            }
        }
    }

    private static func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        if let movementId = prescription.movementId,
           let definition = MovementCatalog.definition(for: movementId) {
            return definition
        }
        let resolved = MovementResolver.resolve(prescription.exerciseName)
        return MovementCatalog.definition(for: resolved.movementId)
    }
}

private extension ActiveWorkoutSession.ActiveSet {
    func hasMetric(_ metricKind: TrainingMetricKind) -> Bool {
        switch metricKind {
        case .reps: return reps != nil
        case .holdSeconds: return holdSeconds != nil
        case .durationSeconds: return durationSeconds != nil
        case .distanceMeters: return distanceMeters != nil
        case .calories: return calories != nil
        }
    }
}
